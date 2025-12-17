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
        elseif self.__StaticEntries["undefined"] then
            self:t_RunStatic("undefined", Event:lower(), ...)
        end
        return self
    end;

    SendSocket = function(self:Types.Localizer, Packet:any, Server:(string | number)?)
        if Server ~= nil then
            if typeof(Server) == "string" then
                Server = tonumber(Server)
            end
            local shard = self:__GetGuildShard(Server::number, self.Shards)

            self.__Gateways[shard]:send(serde.encode("json", Packet))
        else
            for I, item in pairs(self.__Gateways) do
                item:send(serde.encode("json", Packet))
            end
        end

        return self
    end;

    IsEvent = function(self:Types.Localizer, Event:string)
        return self.__StaticEntries[Event:lower()] ~= nil
    end;

    GetShardInfo = function(self:Types.Localizer, Shard:number)
        return self.__ShardInfo[Shard]
    end;

    On = function(self:Types.Localizer, Event:string, Callback:(...any) -> nil)
        self:t_CreateStatic(Event, Callback)
        return self
    end;
    
    Start = function(self:Types.Localizer)
        local GatewayInfo = self:RestSend("GET", "gateway/bot")

        if self.Shards == 0 then
            self.Shards = GatewayInfo.shards
        end

        local Ready = {guilds = {}}

        if self.Shards ~= GatewayInfo.shards then
            print(
                "Shards do not equal the recommended shards: " ..
                `Using: {self.Shards} ` ..
                `Recommends: {GatewayInfo.shards}`
            )
        end

        local MaxConcurrency = GatewayInfo.session_start_limit.max_concurrency or 1
        local IdentifyDelay = 5.5

        self:SpawnEvent("Start")
        PluginBuilder.OnStart(self)

        local ActiveIdentifies = 0

        for I = 1, self.Shards do
            local Shard = I - 1

            while ActiveIdentifies >= MaxConcurrency do
                task.wait(0.1)
            end

            ActiveIdentifies += 1

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
            else
                self:__Resume(Gate, Shard)
            end

            local InitialPacket = serde.decode("json", Gate:next())
            ShardInfo.HeartCount = InitialPacket.d.heartbeat_interval / 1000

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
                        self:t_SpawnProccess(PluginBuilder.OnEvent, self, Packet.t:lower(), Packet.d)

                        if PluginBuilder.IgnoreList[Packet.t:lower()] ~= true and Packet.t ~= "READY" then
                            self:SpawnEvent(Packet.t, Packet.d)
                        end

                        if Packet.t == "READY" then
                            ThreadInfo.SessionID = Packet.d.session_id

                            if Packet.d.resume_gateway_url then
                                ThreadInfo.ResumeGate =
                                Packet.d.resume_gateway_url .. "?v=10&encoding=json"
                            end

                            Ready.user = Ready.user or Packet.d.user

                            Ready.application = Ready.application or Packet.d.application

                            for I, item in ipairs(Packet.d.guilds) do
                                table.insert(ThreadInfo.Guilds, item)
                            end

                            Ready.guilds[CurrentShard] = ThreadInfo.Guilds

                            ActiveIdentifies -= 1
                        end
                    end
                end
            end)

            self:t_SpawnProccess(function()
                local ThreadInfo = self.__ShardInfo[Shard]
                local Gateway = Gate
                local CurrentShard = Shard

                while true do
                    task.wait(ThreadInfo.HeartCount)
                    Gateway:send(serde.encode("json", { op = 1, d = ThreadInfo.RST }))
                    self:SpawnEvent("Heartbeat", CurrentShard)
                end
            end)
            Shard = nil
            ShardInfo = nil
            Gate = nil
            InitialPacket = nil

            if MaxConcurrency == 1 and I ~= self.Shards then
                task.wait(IdentifyDelay)
            end
        end

        while ActiveIdentifies ~= 0 do
            task.wait(0.1)
        end

        self:SpawnEvent("Started")
        self:SpawnEvent("Ready", Ready)
        Ready = nil::any

        return self
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

        return self
    end
}