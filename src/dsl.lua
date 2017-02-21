require "helpers"

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
                CheckName(name)
                local instance = { type = t, name = name}
                if creator then
                    creator(instance)
                end
                if t.lang and t.lang.new_instance then
                    t.lang.new_instance(instance)
                end
                return instance
            end
        }
    )
    return t
end

function new_metatype(creator)
    if type(creator) ~= "function" then
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
                function blank:finalize_type()
                    local ntype = new_type()
                    for k,v in pairs(self) do
                        ntype[k] = v
                    end
                    ntype:specialize_type(self.lang)
                    if ntype.lang and ntype.lang.new_type then
                        ntype.lang.new_type(ntype)
                    end
                    _G[self.name] = ntype
                end
                creator(blank)
                return blank
            end
        }
    )
    return t
end

local interfaces = {}
class = new_metatype(
    function(self)
        setmetatable(self,
            {
                __call = function(cl, body)
                    cl.functions = {}
                    for k,v in ipairs(body) do
                        if type(v) == "table" and v.type and v.type == func then
                            cl.functions[v.name] = v
                            table.insert(cl.functions, v)
                        end
                    end
                    cl:finalize_type()
                    table.insert(interfaces, _G[cl.name])
                end
            }
        )
    end
)

local structures = {}
struct = new_metatype(
    function(self)
        setmetatable(self,
            {
                __call = function(str, body)
                    str.fields = {}
                    for k,v in ipairs(body) do
                        str.fields[k] = v
                    end
                    str:finalize_type()
                    table.insert(structures, _G[str.name])
                    return i
                end
            }
        )
    end
)

func = new_type(
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
                        self.input = {...}
                        setmetatable(self, {
                                __call = function(f, props)
                                    for k,v in pairs(props) do
                                        f[k] = v
                                    end
                                    return f
                                end
                            })
                        return self
                    end
                end
            }
        )
    end
)

--[[
    Public API
]]
int_t    = new_type()
str_t    = new_type()
none_t   = new_type()
float_t  = new_type()
double_t = new_type()
bool_t   = new_type()

function GetStructures()
    return structures
end

function GetInterfaces()
    return interfaces
end
