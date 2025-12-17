local Net = require("@lune/net")
export type Client<self> = {
    Token:string;
    Intents:number;
    Shards:number;

    RestSend:(self:self, Method:string, Path:string, Body:any?, Headers:{[string]:any}?) -> self;
    SendSocket:(self:self, Packet:any, Server:(string | number)?) -> self;
    SpawnEvent:(self:self, Event:string, ...any) -> self,
    IsEvent:(self:self, Event:string) -> boolean;
    On:(Self:self, Event:string, Callback:(...any) -> nil) -> self;

    Start:(self:self) -> self;
    Stop:(self:self) -> self
}

export type Private<self> = {
    __StaticThreads:{[thread]:number}; --[[
        These threads will run forever

        many of these can run togethor depending on X gateways
    ]]

    __ProccesorThreads:{[thread]:number}; --[[
        Threads can be safely closed on calling stop
    ]]

    __Gateways:{Net.WebSocket}; --[[
        used to manager spawned gateways
    ]]

    __ShardInfo:{[number]:{SessionID:any, RST:number, HeartCount:number, ResumeGate:string?}};

    __StaticEntries:{[string]:any};

    __Resumable:boolean;

    __ShardRec:number;

    __GetGateway:(self:self, Shard:number, ResumeURL:string?) -> string;

    __GetGuildShard:(self:self, guildId: number, shardCount: number) -> number;

    __Identify:(self:self, Gate:Net.WebSocket, Shard:number) -> self;
    __Resume:(self:self, Gate:Net.WebSocket, Shard:number) -> self
}

export type ThreadMethods<self>  = {
    t_SpawnProccess:(self:self, FN:any) -> self;
    t_KillProccess:(self:self) -> self;

    t_CreateStatic:(self:self, ID:string, FN:any) -> self;
    t_RunStatic:(self:self, ID:string, ...any) -> self;
    t_DestroyThreadStatic:(self:self) -> self;
}

export type Localizer = Client<Localizer> & Private<Localizer> & ThreadMethods<Localizer>

return true