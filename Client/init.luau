local PluginBuilder = require("@self/PluginBuilder")
local PrivateBuilder = require("@self/PrivatisedBuilder")
local Threading = require("@self/ThreadManager")
local PublicBuilder = require("@self/PublicBuilders")
local Types = require("@self/Types")

local StandardProperties = {}

local StandardMethods = {}

for I, item in pairs(PrivateBuilder) do
    if typeof(item) == "table" then
        StandardProperties["__" .. I] = table.clone(item)
    elseif typeof(item) == "function" then
        StandardMethods["__" .. I] = item
    else
        StandardProperties["__" .. I] = item
    end
end

for I, item in pairs(Threading) do
    StandardMethods["t_" .. I] = item
end

for I, item in pairs(PublicBuilder) do
    if typeof(item) == "table" then
        StandardProperties[I] = table.clone(item)
    elseif typeof(item) == "function" then
        StandardMethods[I] = item
    else
        StandardProperties[I] = item
    end
end

local Methods = {
    __index = function(self, Key:string)
        if StandardMethods[Key] then
            return StandardMethods[Key]
        end

        if ExposedMethods[Key] then
            return ExposedMethods[Key]
        end

        return rawget(self, Key)
    end;

    __newindex = function(self, Key:string, Value:any)
        if StandardMethods[Key] or ExposedMethods[Key] then
            return 
        end

        return rawset(self, Key, Value)
    end
}

return function(Token:string, Intents:number, Shards:number?)
    local Client:Types.Localizer = setmetatable(table.clone(StandardProperties), Methods)::any

    PluginBuilder.ApplyPlugins(Client)

    Client.Token = Token
    Client.Intents = Intents
    Client.Shards = Shards or 0

    return Client
end
