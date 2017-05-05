require "string"
require "helpers"
effil = require "effil"

return function(module_path, language, target)
    _G.target = target
    _G.language = language

    if module_path == nil or io.open(module_path, "r") == nil then
        log_err("Invalid module file: " .. module_path)
    end

    local context = {
        component = component,
        target = target,
        require = require,
        print = print,
        ipairs = ipairs,
        next = next,
        pairs = pairs,
        pcall = pcall,
        tonumber = tonumber,
        tostring = tostring,
        type = type,
        unpack = unpack,
        error = error,
        assert = assert,
        io = io,
        string = string,
        table = table,
        setmetatable = setmetatable,
        getmetatable = getmetatable,
        math = math,
        os = os,
    }
    loadfile(LUA_RPC_SDK .. "/src/dsl.lua", "bt", context)()
    local loader = loadfile(module_path, "bt", context)
    local ret, err = pcall(loader)
    if not ret then
        log_err("Error during module loading: %s", err)
    end

    local startups_data = {}
    exports = { slaves = {}, masters = {} }
    for _, iface in ipairs(context.exports.slaves) do
        exports.slaves[iface.name] = iface
        table.insert(startups_data, {iface.flags.connector .. "_slave", iface.flags.host,
            iface.flags.port, iface.flags.protocol, iface.flags.factory})
    end
    for _, iface in ipairs(context.exports.masters) do
        exports.masters[iface.name] = iface
    end

    return {
        exports = exports,
        startups_loader = function(startups_data)
            for _, data in ipairs(startups_data) do
                component:load(unpack(data))
            end
        end,
        startups_data = startups_data
    }
end
