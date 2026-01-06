local Module = {}
local Client = require("@self/Client")
local Types = require("@self/Client/Types")

export type Client = Types.Client<Client>

export type PrivatisedClient = Types.Localizer

Module._Bots = {}

function Module.new(Token:string, Intents:number?, Shards:number?):Client
    if Module._Bots[Token] then return Module._Bots[Token] end
        
    local self:any = Client(Token, Intents, Shards)::any
    Module._Bots[Token] = self
    return self
end

return Module
