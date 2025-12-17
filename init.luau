local Module = {}
local Client = require("@self/Client")
local Types = require("@self/Client/Types")

export type Client = Types.Client<Client>

export type PrivatisedClient = Types.Localizer

function Module.new(Token:string, Intents:number, Shards:number?):Client
    return Client(Token, Intents, Shards)::any
end

return Module