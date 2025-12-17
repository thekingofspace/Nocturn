local Types = require("./Types")
local serde = require("@lune/serde")
local net = require("@lune/net")

local StandardPack = {
    op = 2;
    d = {
        token = "TOKEN HERE";
        intents = 0;
        properties = {
            os = "linux";
            browser = "noctari_prime";
            device = "noctari_prime";
        },
        shard = {0, 1};
    }
}

return {
    StaticThreads = {};
    ProccesorThreads = {};
    Gateways = {};
    StaticEntries = {};
    ShardInfo = {};
    HeartCount = 0;
    ShardRec = 0;
    Resumable = false;

    GetGateway = function(self:Types.Localizer, Shard:number, ResumeURL:string?)
        local Loaders = self:RestSend("GET", "gateway/bot")

        self.__ShardRec = Loaders.Shards
        
        self.__Gateways[Shard] = net.socket(ResumeURL or Loaders.url .. "?v=10&encoding=json")

        self.__ShardInfo[Shard] = self.__ShardInfo[Shard] or {RST = 0, HeartCount = 0, Guilds = {}}
    end;

    Identify = function(self:Types.Localizer, Gate:net.WebSocket, Shard:number)
        local Packet = table.clone(StandardPack)
        Packet.d.token = self.Token
        Packet.d.shard = {Shard, self.Shards}
        Packet.d.intents = self.Intents

        Gate:send(serde.encode("json", Packet))
    end;

    Resume = function(self:Types.Localizer, Gate:net.WebSocket, Shard:number)
        local ShardInfo = self.__ShardInfo[Shard]
        Gate:send(serde.encode("json", {
            op = 6;
            d = {
                token = self.Token;
                session_id = ShardInfo.SessionID;
                seq = ShardInfo.RST
            }
        }))

        self:SpawnEvent("Resume")
    end;

    GetGuildShard = function(self:Types.Localizer, guildId: number, shardCount: number)
        return bit32.rshift(guildId, 22) % shardCount
    end;
}