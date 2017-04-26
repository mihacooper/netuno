require "helpers"
require "networking"

local function CheckName(name)
    first, last = string.find(name, '[%a|_][%a|_|%d]+')
    if not(first == 1 and last == #name) then
        error(string.format("Invalid name '%s'", name))
    end
end

function new_type(creator)
    local t = {}

    function t:specialize_type(specific)
        self.lang = specific
        self.specialize_type = nil
    end

    setmetatable(t,
        {
            __call = function(t, name)
                local instance = { type = t }
                if name ~= nil then
                    CheckName(name)
                    instance.name = name
                else
                    if creator then
                        creator(instance)
                    end
                    if t.lang and t.lang.new_instance then
                        t.lang.new_instance(instance)
                    end
                end
                return instance
            end
        }
    )
    function t:new(...)
        local instance = { type = self }
        if creator then
            creator(instance, ...)
        end
        if self.lang and self.lang.new_instance then
            t.lang.new_instance(instance)
        end
        return instance
    end

    return t
end

function new_metatype(type_creator, instance_creator)
    if type(type_creator) ~= "function" or type(instance_creator) ~= "function" then
        error("metatype's creator is not a function: " .. tostring(creator))
    end

    local t = {}

    function t:specialize_type(specific)
        self.lang = specific
        self.specialize_type = nil
    end

    setmetatable(t,
        {
            __call = function(t, name)
                CheckName(name)
                local blank = { name = name, type = t, lang = t.lang}
                function blank:finalize_type(name, public)
                    local ntype = new_type(instance_creator)
                    ntype.name = self.name
                    ntype.type = self.type
                    ntype:specialize_type(self.lang)
                    if ntype.lang and ntype.lang.new_type then
                        ntype.lang.new_type(ntype)
                    end
                    if public == nil or public == true then
                        _G[self.name] = ntype
                    end
                    return ntype
                end
                type_creator(blank)
                return blank
            end
        }
    )
    return t
end

class = new_metatype(
    function(self)
        setmetatable(self,
            {
                __call = function(cl, body)
                    local ret = cl:finalize_type()
                    ret.functions = {}
                    ret.flags = {}
                    for k,v in pairs(body) do
                        if type(k) == "number" and type(v) == "table" and v.type and v.type == func then
                            table.insert(ret.functions, v)
                        else
                            ret.flags[k] = v
                        end
                    end
                    return ret
                end
            }
        )
    end,
    function(self)
        for key, val in pairs(self.type.flags) do
            self[key] = val
        end
        if target == "client" then
            local connector = self.connector or default_connector
            local protocol = self.protocol or default_protocol
            self.connection = connector:create()
            self.protocol = protocol.new_master(self.connection)
            self.protocol:request_new(self.type.name)
            self["%del"] = function()
                self.protocol:request_del()
            end
        else
            self.server = self.type.server()
            if self.server == nil then
                error("Unable to create slave object: target object is nil")
            end
        end
        for _, func in ipairs(self.type.functions) do
            self[func.name] = func()
            self[func.name].parent = self
        end
    end
)

system.structures = {}
struct = new_metatype(
    function(self)
        setmetatable(self,
            {
                __call = function(str, body)
                    local ret = str:finalize_type()
                    ret.fields = {}
                    for k,v in ipairs(body) do
                        ret.fields[k] = v
                    end
                    table.insert(system.structures, ret)
                    return ret
                end
            }
        )
    end,
    function(self, str)
        self.value = {}
        for _, field in pairs(self.type.fields) do
            self.value[field.name] = field.type:new(str[field.name]).value
        end
    end
)

func = new_metatype(
    function(self)
        setmetatable(self,
            {
                __index = function(f, output_name)
                    getmetatable(f).__index = nil
                    f.output = _G[output_name]
                    if f.output == nil then
                        error("Invalid function " .. f.name .. " output: " .. tostring(output_name))
                    end
                    return function(self, ...)
                        local ret = self:finalize_type(false)
                        ret.input = {...}
                        ret.output = self.output
                        ret.with = function(f, props)
                            for k,v in pairs(props) do
                                f[k] = v
                            end
                            return f
                        end
                        return ret
                    end
                end
            }
        )
    end,
    function(self)
        setmetatable(self,
            {
                __call = function(f, ...)
                    local in_args = {...}
                    local use_args = {}
                    for i = 1, #f.type.input do
                        table.insert(use_args, f.type.input[i].type:new(in_args[i]).value)
                    end
                    local return_value = nil
                    if f.type.impl then
                        return_value = f.type.impl(unpack(use_args))
                    else
                        if target == "client" then
                            if self.protocol == nil then
                                if self.type.connector then
                                    self.connection = self.type.connector:create()
                                else
                                    self.connection = self.parent.connection
                                end
                                if self.type.protocol or self.type.connector then
                                    self.protocol = self.type.protocol:new_master(self.connection)
                                else
                                    self.protocol = self.parent.protocol
                                end
                            end
                            return_value = self.protocol:request_call(f, unpack(use_args))
                        else
                            return_value = f.parent.server[f.type.name](f.parent.server, unpack(use_args))
                        end
                    end
                    return f.type.output:new(return_value).value
                end
            }
        )
    end
)

function primitive_type_creator(def)
    return function(self, actual)
        if actual == nil then
            self.value = def
        else
            if type(actual) ~= type(def) then
                error(string.format("Invalid type of %s(%s) - expect type %s",
                    tostring(actual), type(actual), type(def)))
            end
            self.value = actual
        end
    end
end

--[[
    Public API
]]
int_t    = new_type(primitive_type_creator(0))
str_t    = new_type(primitive_type_creator(""))
none_t   = new_type(primitive_type_creator(nil))
float_t  = new_type(primitive_type_creator(0.0))
double_t = new_type(primitive_type_creator(0.0))
bool_t   = new_type(primitive_type_creator(false))

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

function system.register_target(masters, slaves)
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
    for _, master in ipairs(masters) do
        for _, slave in ipairs(slaves) do
            if master == slave then
                error("Unable to use the same interface as both slave and master: " .. master.name)
            end
        end
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
    system.master_interfaces = masters
    system.slave_interfaces = slaves
end

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
        local conn = system.connectors[storage[1]]
        conn:set_context(storage[2], storage[3])
        conn:listen()
    end
end