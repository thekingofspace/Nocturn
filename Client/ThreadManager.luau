local Module = {}
local Types = require("./Types")

local function StandardThread(self:Types.Localizer, Aray, fn, ...)
    local Thread = coroutine.running()

    if not Thread then Thread = nil; return end

    local suc, err = pcall(function(...)
        fn(...)
    end, ...)

    if not suc then
        print(err)
    end

    suc, err = nil

    Aray[Thread] = nil

    Thread = nil
end

function Module.SpawnProccess(self:Types.Localizer, fn:any, ...)
    local Thread = coroutine.create(StandardThread)

    self.__ProccesorThreads[Thread] = os.time()

    coroutine.resume(Thread, self, self.__ProccesorThreads, fn, ...)

    Thread = nil

    return self
end

function Module.KillProccess(self:Types.Localizer)
    for Thread, _ in pairs(self.__ProccesorThreads) do
        pcall(function()
            coroutine.close(Thread)
        end)
    end

    table.clear(self.__ProccesorThreads)

    return self
end

function Module.CreateStatic(self:Types.Localizer, ID:string, FN:any)
    self.__StaticEntries[ID:lower()] = FN
    return self
end

function Module.RunStatic(self:Types.Localizer, ID:string, ...)
    local Event = self.__StaticEntries[ID:lower()]

    if Event then
        local Thread = coroutine.create(StandardThread)
        self.__StaticThreads[Thread] = os.time()
        coroutine.resume(Thread, self, self.__StaticEntries, self.__StaticEntries[ID:lower()], ...)
        Thread = nil
    end

    Event = nil
    return self
end

function Module.DestroyThreadStatic(self:Types.Localizer)
    for Thread, _ in pairs(self.__StaticThreads) do
        pcall(function()
            coroutine.close(Thread)
        end)
    end

    table.clear(self.__StaticThreads)
    return self
end

return Module