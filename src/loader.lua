require "string"
require "helpers"
effil = require "effil"

return function(module_path, language, target)
    _G.target = target
    _G.language = language

    if module_path == nil or io.open(module_path, "r") == nil then
        log_err("Invalid module file: " .. module_path)
    end

    require "dsl"
    local ret, err = pcall(dofile, module_path)
    if not ret then
        log_err("Error during module loading: %s", err)
    end
end
--[[
system.connectors = {}
system.protocols = {}
system.factories = {}

function system.register_connector(name, connector)
    if system.connectors[name] ~= nil then
        error("Error: unable to register connector, already exists '" .. name .. "'")
    end
    system.connectors[name] = connector
end

function system.register_protocol(name, protocol)
    if system.protocols[name] ~= nil then
        error("Error: unable to register protocol, already exists '" .. name .. "'")
    end
    system.protocols[name] = protocol
end

function system.register_factory(name, factory)
    if system.factories[name] ~= nil then
        error("Error: unable to register factory, already exists '" .. name .. "'")
    end
    system.factories[name] = factory
end

local master_connectors = {}

function system.run_connectors()
    local exchange = system.unique_channel()
    local storage = exchange:pop(0)
    if storage == nil then
        for protocol, connectors in pairs(master_connectors) do
            for _, pair in ipairs(connectors) do
                local conn, factory = unpack(pair)
                exchange:push({conn, protocol, factory})
                run_new_state(function() system.run_connectors() end )
            end
        end
    else
        local conn = system.connectors[storage[1] ]
        conn:set_context(storage[2], storage[3])
        conn:listen()
    end
end

function system.register_slaves(...)
    local slaves = {...}
    local function add_connector(conn, protocol, factory)
        if master_connectors[protocol] == nil then
            master_connectors[protocol] = {}
        end
        local is_new = true
        for _, val in ipairs(master_connectors[protocol]) do
            if val[0] == conn[0] then
                is_new = false
                break
            end
        end
        if is_new then
            table.insert(master_connectors[protocol], {conn, factory})
        end
    end

    if system.connectors["default_connector"] == nil then
        system.register_connector("default_connector", default_connector)
    end
    if system.protocols["default_protocol"] == nil then
        system.register_protocol("default_protocol", default_protocol)
    end
    if system.factories["default_factory"] == nil then
        system.register_factory("default_factory", default_factory)
    end

    for _, slave in ipairs(slaves) do
        local slave_connector = slave.flags.connector or "default_connector"
        local slave_protocol  = slave.flags.protocol  or "default_protocol"
        local slave_factory   = slave.flags.factory   or "default_factory"
        add_connector(slave_connector, slave_protocol, slave_factory)
        for _, func in ipairs(slave.functions) do
            add_connector(
                func.connector or slave_connector,
                func.protocol  or slave_protocol,
                slave_factory)
        end
    end
    system.slave_interfaces = slaves
end
]]
