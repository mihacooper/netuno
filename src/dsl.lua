require "helpers"

setmetatable(_G,
    {
        __index = function(self, key)
            local val = rawget(self, key)
            if val == nil then
                return key
            end
            return val
        end
    }
)
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

local structures = {}
local function StructureImpl(name)
    CheckName(name)
    local mt = {
        __call = function(i, body)
            local as_type = NewType()
            _G[name] = as_type
            as_type.paramType = i.name
            as_type.toLua = i.name .. "::ToLuaObject"
            as_type.fromLua = i.name .. "::FromLuaObject"
            for _, v in pairs(body) do
                Expect(IsType(v), string.format("one of '%s' structure fields is invalid", name))
            end
            i.fields = {}
            table.copy(i.fields, body)
            return as_type
        end
    }
    local newStructure = { name = name }
    setmetatable(newStructure, mt)
    table.insert(structures, newStructure)
    storage.Store('types', newStructure)
    return newStructure
end

local function FunctionImpl(param)
    local f = {}
    storage.Store('functions', f)

    local outType = param
    if IsString(param) then
        -- Function name
        CheckName(param)
        outType = void
        f.funcName = param
    end
    Expect(IsType(outType), "type expected as a function output")

    local typeCopy = {}
    table.rcopy(typeCopy, outType)
    storage.Store('types', typeCopy)
    f.output = typeCopy

    local mt = {
        __call = function(func, ...)
            params = {...}
            if func.funcName == nil then
                Expect(IsString(params[1]), "string expected as a function name")
                CheckName(params[1])
                func.funcName = params[1]
            elseif func.input == nil then
                func.input = params
                for _, v in pairs(params) do
                    Expect(IsType(v), string.format("one of '%s' function parameters is invalid", name))
                end
            else
                Expect(IsTable(params[1]), "table of function's properties expected")
                for k, v in pairs(params[1]) do
                    func[k] = v
                end
            end
            return func
        end
    }
    setmetatable(f, mt)
    return f
end

--[[
    Public API
]]
int    = NewType()
str    = NewType()
void   = NewType()
float  = NewType()
double = NewType()
bool   = NewType()

function class(name)
    return InterfaceImpl(name)
end

function func(name)
    return FunctionImpl(name)
end

function struct(name)
    return StructureImpl(name)
end

function GetInterface(name)
    return interfaces[name]
end

function GetStructures()
    return structures
end
