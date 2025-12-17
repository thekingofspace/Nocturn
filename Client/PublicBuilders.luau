local Types = require("./Types")
local EndPoint = "https://discord.com/api/v10"
local serde = require("@lune/serde")
local net = require("@lune/net")
local task = require("@lune/task")
local PluginBuilder = require("./PluginBuilder")

return {
    RestSend = function(self:Types.Localizer, Method:string, Path:string, Body:any?, Headers:{[string]:any}?)
            local Packet = {
            url = `{EndPoint}/{Path}`;
            method = Method:upper();
            headers = {
                ["Authorization"] = `Bot {self.Token}`;
                ["Content-Type"] = "application/json";
            }
        }

        if Headers then
            for k, v in pairs(Headers) do
                Packet.headers[k] = v
            end
        end

        if Body then
            Packet.body = typeof(Body) == "table"
                and serde.encode("json", Body)
                or Body
        end

        local ReturnPack = net.request(Packet)
        if ReturnPack.statusCode > 400 then
            error(`[ERROR CODE {ReturnPack.statusCode}]: {ReturnPack.statusMessage}, \n\n {ReturnPack.body}`)
        end

        if not ReturnPack.body then return nil end

        local ok, decoded = pcall(function()
            return serde.decode("json", ReturnPack.body)
        end)

        return ok and decoded or ReturnPack.body
    end;

    SpawnEvent = function(self:Types.Localizer, Event:string, ...)
        if self.__StaticEntries[Event:lower()] then
            self:t_RunStatic(Event:lower(), ...)
        end
    end;

    SendSocket = function(self:Types.Localizer, Packet:any, Server:(string | number)?)
        if Server then
            if typeof(Server) == "string" then
                Server = tonumber(Server)
            end
            local shard = self:__GetGuildShard(Server::number, self.Shards)

            self.__Gateways[shard]:send(serde.encode("json", Packet))
        else
            for I, item in pairs(self.__Gateways) do
                item:send(serde.encode("json"), Packet)
            end
        end
    end;

    IsEvent = function(self:Types.Localizer, Event:string)
        return self.__StaticEntries[Event:lower()] ~= nil
    end;

    On = function(self:Types.Localizer, Event:string, Callback:(...any) -> nil)
        self:t_CreateStatic(Event, Callback)
    end;

    --[[
    {
        session_start_limit = {
            max_concurrency = 1,
            remaining = 1000,
            reset_after = 0,
            total = 1000,
        },
        shards = 1,
        url = "wss://gateway.discord.gg",
    }
    ]]

    Start = function(self:Types.Localizer)
        local GatewayInfo = self:RestSend("GET", "gateway/bot")
        if self.Shards == 0 then
            self.Shards = GatewayInfo.shards
        end
        if self.Shards ~= GatewayInfo.shards then
            print("Shards do not equal the recommended shards: " .. `Using: {self.Shards} ` .. `Recommends: {GatewayInfo.shards}`)
        end

        self:t_RunStatic("Start")
        PluginBuilder.OnStart(self)

        for I = 1, self.Shards do
            local Shard = I-1

            local ShardInfo = self.__ShardInfo[Shard]

            if ShardInfo then
                self:__GetGateway(Shard, ShardInfo.ResumeGate)
            else
                self:__GetGateway(Shard)
            end

            ShardInfo = self.__ShardInfo[Shard]

            local Gate = self.__Gateways[Shard]
            
            if self.__Resumable == false then
                self:__Identify(Gate, Shard)

                local InitialPacket = serde.decode("json", Gate:next())
                ShardInfo.HeartCount = InitialPacket.d.heartbeat_interval / 1000
            else
                self:__Resume(Gate, Shard)

                local InitialPacket = serde.decode("json", Gate:next())
                ShardInfo.HeartCount = InitialPacket.d.heartbeat_interval / 1000
            end

            self:t_SpawnProccess(function()
                local ThreadInfo = self.__ShardInfo[Shard]
                local CurrentShard = Shard
                local Gateway = Gate

                while true do
                    local Packet = serde.decode("json", Gateway:next())

                    if Packet.s then
                        ThreadInfo.RST = Packet.s
                    end
                    
                    if Packet.close == 4010 then
                        local GateInfo = self:RestSend("GET", "gateway/bot")

                        self.__ShardRec = GateInfo.Shards
                        self:__Identify(Gateway, CurrentShard)
                        continue
                    end

                    if Packet.op == 7 then
                        self:__Resume(Gateway, CurrentShard)
                        continue
                    end

                    if Packet.op == 9 then
                        if Packet.d == true then
                            self:__Resume(Gateway, CurrentShard)
                        else
                            self:__Identify(Gateway, CurrentShard)
                        end
                        continue
                    end
                    
                    if Packet.op == 0 then
                        PluginBuilder.OnEvent(self, Packet.t:lower(), Packet.d)
                        if PluginBuilder.IgnoreList[Packet.t:lower()] == true then
                            continue
                        end
                        
                        if self.__StaticEntries[Packet.t:lower()] ~= nil then
                            self:t_RunStatic(Packet.t, Packet.d)
                        else
                            self:t_RunStatic("undefined", Packet.d, Packet.t:lower())
                        end

                        if Packet.t:lower() == "ready" then
                            ThreadInfo.SessionID = Packet.d.session_id
                            if Packet.d.resume_gateway_url then
                                ThreadInfo.ResumeGate = Packet.d.resume_gateway_url .. "?v=10&encoding=json"
                            end
                        end

                        continue
                    end
                end
            end)

            self:t_SpawnProccess(function()
                local ThreadInfo = self.__ShardInfo[Shard]
                local Gateway = Gate
                while true do
                    task.wait(ThreadInfo.HeartCount)

                    Gateway:send(serde.encode("json", {op = 1, d = ThreadInfo.RST}))

                    self:SpawnEvent("Heartbeat")
                end
            end)
            Gate = nil
            ShardInfo = nil
            Shard = nil

            if I ~= self.Shards then
                task.wait(math.max(GatewayInfo.session_start_limit.reset_after / 1000, 0))
            end
        end

        self:t_RunStatic("Started")
    end;

    Stop = function(self:Types.Localizer)
        PluginBuilder.OnStop(self)

        for I, item in pairs(self.__Gateways) do
            item:close(4000)
        end

        table.clear(self.__Gateways)

        self.__Resumable = true

        self:t_DestroyThreadStatic()
        self:t_KillProccess()
    end
}