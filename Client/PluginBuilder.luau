local module = {}
module.IgnoreList = {}
local types = require("./Types")

CreationBoot = CreationBoot or {}
ExposedMethods = ExposedMethods or {}
LoadPlugins = LoadPlugins or {}

plugin = {}

type Plugin = {
    Name: string;
    Version: string;
    LoadOrder: number;

    RegisterMethod:(self:Plugin, Method:string, Callback:(self:types.Localizer, ...any) -> nil) -> Plugin;
    Ignore:(self:Plugin, Event:string) -> Plugin;

    LoadAction: (client: types.Localizer) -> nil;
    StopAction: (client: types.Localizer) -> nil;
    StartAction: (client: types.Localizer) -> nil;
    EventAction: (client: types.Localizer, Event: string, Data: any) -> nil;
}

local PluginMethods = {}
PluginMethods.__index = plugin

function PluginMethods.Ignore(self:Plugin, Method:string)
    module.IgnoreList[Method:lower()] = true
end

function PluginMethods.RegisterMethod(self:Plugin, Method:string, Callback:(self:types.Localizer, ...any) -> nil)
    ExposedMethods[Method] = Callback
end

local function SafeCall(Plugin: Plugin,MethodName: string,Fn: (...any) -> (),...)
    local ok, err = pcall(Fn, ...)
    if not ok then
        print(`[PLUGIN:{Plugin.Name}] {MethodName} failed:\n{err}`)
    end
end

function plugin.new()
    local self = setmetatable({
        Name = "";
        Version = "";
        LoadOrder = 1;
    }, PluginMethods)

    table.insert(LoadPlugins, self)
    return self
end

function module.ApplyPlugins(Client: types.Localizer)
    table.sort(LoadPlugins, function(A, B)
        return A.LoadOrder < B.LoadOrder
    end)

    for _, item: Plugin in ipairs(LoadPlugins) do
        SafeCall(item, "LoadAction", item.LoadAction, Client)
    end
end

function module.OnStart(Client: types.Localizer)
    for _, item: Plugin in ipairs(LoadPlugins) do
        SafeCall(item, "StartAction", item.StartAction, Client)
    end
end

function module.OnStop(Client: types.Localizer)
    for _, item: Plugin in ipairs(LoadPlugins) do
        SafeCall(item, "StopAction", item.StopAction, Client)
    end
end

function module.OnEvent(Client: types.Localizer, Event: string, Data: any)
    for _, item: Plugin in ipairs(LoadPlugins) do
        SafeCall(item, "EventAction", item.EventAction, Client, Event, Data)
    end
end

return module
