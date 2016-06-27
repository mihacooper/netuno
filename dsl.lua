require "helpers"
--[[
    Storage
]]
local storage = {}
function storage.Store(type, value)
    if storage[type] == nil then
        storage[type] = {}
    end
    table.insert(storage[type], value)
end

function storage.Check(type, value)
    if storage[type] == nil then
        storage[type] = {}
    end
    for _, val in pairs(storage[type]) do
        if val == value then
            return true
        end
    end
    return false
end

local function IsFunction(func)
    return storage.Check('functions', func)
end

local function IsType(t)
    return storage.Check('types', t)
end

--[[
    Types
]]
local function NewType()
    local t = {}

    function t:SpecializeType(name, def)
        self.paramType = name
        self.default = def
        self.SpecializeType = nil
    end

    setmetatable(t,
        { 
            __call = function(t, name)
                local r = {}
                table.rcopy(r, t)
                r.paramName = name
                storage.Store('types', r)
                return r
            end,
            __concat = function(t, f)
                Expect(IsType(t), "left operand of '..' is not a valid type")
                Expect(IsFunction(f), "right operand of '..' is not a valid function")
                local typeCopy = {}
                table.rcopy(typeCopy, t)
                storage.Store('types', typeCopy)
                f.output = typeCopy
                return f
            end
        }
    )
    storage.Store('types', t)
    return t
end

local function CheckName(name)
    first, last = string.find(name, '[%a|_][%a|_|%d]+')
    if not(first == 1 and last == #name) then
        error(string.format("Invalid name '%s'", name))
    end
end

local function GetFunctionImpl(func)
    return function(...)
        local params = {...}
        local strParams = ''
        for i in ipairs(func.input) do
            local p = func.input[i]
            strParams = strParams .. string.format("%s %s = %s, ", p.paramType, p.paramName, params[i])
        end
        if #strParams > 0 then
            strParams = string.sub(strParams, 0, #strParams - 2)
        end
        local ret = ''
        if func.output ~= nil then
            local def = func.output.default
            if def == '' then
                def = "''"
            end
            ret = string.format(" -> %s(%s)", def, func.output.paramType)
        end
        print(string.format("%s(%s)%s", func.funcName, strParams, ret))
        if func.output ~= nil then
            return func.output.default
        end
    end
end

local interfaces = {}
local function InterfaceImpl(name)
    CheckName(name)
    local mt = {
        __call = function(i, body)
            for _, v in pairs(body) do
                Expect(IsFunction(v), string.format("one of '%s' interface fields is invalid", name))
                v.impl = v.impl or GetFunctionImpl(v)
            end
            table.copy(i, body)
            return i
        end
    }
    local newInterface = {}
    setmetatable(newInterface, mt)
    interfaces[name] = newInterface
    return newInterface
end

local function FunctionImpl(name)
    Expect(IsString(name), "string expected as a function name")
    CheckName(name)
    local mt = {
        __call = function(func, params)
            func.input = params
            for _, v in pairs(params) do
                Expect(IsType(v), string.format("one of '%s' function parameters is invalid", name))
            end
            setmetatable(func,
                {
                    __call = function(f, prop)
                        Expect(IsFunction(f), "left operand of '..' is not a valid function")
                        Expect(type(prop) == "table", "right operand of '..' is not a valid type")
                        if prop[1] and type(prop[1]) == "function" then
                            f.impl = prop[1]
                        end
                        return f
                    end
                } 
            )
            return func
        end
    }
    local f = { funcName = name }
    storage.Store('functions', f)
    setmetatable(f, mt)
    return f
end

--[[
    Public API
]]
Int    = NewType()
String = NewType()
Void   = NewType()
Float  = NewType()
Double = NewType()
Bool   = NewType()

function Interface(name)
    return InterfaceImpl(name)
end

function Function(name)
    return FunctionImpl(name)
end

function GetInterface(name)
    return interfaces[name]
end
