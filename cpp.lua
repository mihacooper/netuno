require "helpers"
require "dsl"

Int:SpecializeType('int', 0)
String:SpecializeType('std::string', '')
Void:SpecializeType('void', nil)

local generator =
{
    interfaceName = "__InvalidValue__",
    functions = {},
}

local function CommonPreparation(funcs)
    for _, f in pairs(funcs) do
        -- add separators
        local paramsCopy = {}
        for _, param in pairs(f.input) do
            table.insert(paramsCopy,
                { paramType = param.paramType, paramName = param.paramName, comma = {{}}})
        end
        if #paramsCopy > 0 then
            paramsCopy[#paramsCopy].comma = {}
        end
        f.input = paramsCopy
        -- add separators
        f.output = f.output or Void
        f.output = f.output.paramType
    end
    return funcs
end

function generator:SetInterfaceName(name)
    self.interfaceName = name
end

function generator:AddFunction(func)
    table.insert(self.functions, func)
end

--[[
    Client
]]
function generator:GenerateClientFiles(moduleName)
    self.functions = CommonPreparation(self.functions)
    self:GenerateClientHeader(moduleName)
    self:GenerateClientSource(moduleName)
end

local clientHeaderTemplate =
[[
#include "LuaBridge.h"
extern "C"
{
    #include "lua.h"
    #include "lauxlib.h"
    #include "lualib.h"
}

class {{interface}}
{
public:
    {{interface}}();
<|functions|>    {{output}} {{funcName}}(<|input|>{{paramType}} {{paramName}}<|comma|>, <|comma|><|input|>);
<|functions|>
private:
    luabridge::LuaRef GetFunction(const std::string& name);
    luabridge::lua_State* m_luaState;
};
]]

local clientSourceTemplate =
[[
#include "{{module}}.h"

using namespace luabridge;

#define CHECK(x, msg) { \
    if(x) { printf("ERROR at %s:%d\n\t%s ", __FILE__, __LINE__, #x); \
        throw std::runtime_error(msg);} }

{{interface}}::{{interface}}()
    : m_luaState(luaL_newstate())
{
    CHECK(luaL_loadfile(m_luaState, "loader.lua"), lua_tostring(m_luaState, -1));
    luaL_openlibs(m_luaState);
    CHECK(lua_pcall(m_luaState, 0, 0, 0), lua_tostring(m_luaState, -1));
}

LuaRef {{interface}}::GetFunction(const std::string& name)
{
    LuaRef interface = getGlobal(m_luaState, "{{interface}}");
    CHECK(interface.isNil(), "Unable to get Lua interface");
    LuaRef func = interface[name];
    CHECK(func.isNil(), "Unable to get Lua function object");
    return func;
}

<|functions|>
{{output}} {{interface}}::{{funcName}}(<|input|>{{paramType}} {{paramName}}<|comma|>, <|comma|><|input|>)
{
    <|doReturn|>return <|doReturn|>GetFunction("{{funcName}}")(<|input|>{{paramName}}<|comma|>, <|comma|><|input|>)<|doCast|>.cast<{{output}}>()<|doCast|>;
}
<|functions|>
]]

function generator:GenerateClientHeader(moduleName)
    local body = StrRepeat(clientHeaderTemplate, { interface = self.interfaceName, functions = self.functions})
    WriteToFile(moduleName .. ".h", body)
end

function generator:GenerateClientSource(moduleName)
    for _, func in pairs(self.functions) do
        if func.output == Void.paramType then
            func.doReturn = {}
            func.doCast = {}
        else
            func.doReturn = {{}}
            func.doCast = {{}}
        end
    end
    local body = StrRepeat(clientSourceTemplate, { module = moduleName, interface = self.interfaceName, functions = self.functions})
    WriteToFile(moduleName .. ".cpp", body)
end

--[[
    Server
]]
function generator:GenerateServerFiles(moduleName)
    self.functions = CommonPreparation(self.functions)
    self:GenerateServerHeader(moduleName)
    self:GenerateServerSource(moduleName)
end

local serverHeaderTemplate =
[[
#include "LuaBridge.h"
extern "C"
{
    #include "lua.h"
    #include "lauxlib.h"
    #include "lualib.h"
}

class {{interface}}
{
public:
    {{interface}}();
<|functions|>    virtual {{output}} {{funcName}}(<|input|>{{paramType}} {{paramName}}<|comma|>, <|comma|><|input|>) = 0;
<|functions|>
private:
    luabridge::lua_State* m_luaState;
};
]]

local serverSourceTemplate =
[[
#include "{{module}}.h"

using namespace luabridge;

#define CHECK(x, msg) { \
    if(x) { printf("ERROR at %s:%d\n\t%s ", __FILE__, __LINE__, #x); \
        throw std::runtime_error(msg);} }

{{interface}}::{{interface}}()
    : m_luaState(luaL_newstate())
{
    getGlobalNamespace(m_luaState)
    .beginClass<{{interface}}>("{{interface}}")
<|functions|>        .addFunction("{{interface}}", &{{interface}}::{{funcName}})<|functions|>
    .endClass();
    CHECK(luaL_loadfile(m_luaState, "loader.lua"), lua_tostring(m_luaState, -1));
    luaL_openlibs(m_luaState);
    CHECK(lua_pcall(m_luaState, 0, 0, 0), lua_tostring(m_luaState, -1));
}
]]

function generator:GenerateServerHeader(moduleName)
    local body = StrRepeat(clientHeaderTemplate, { interface = self.interfaceName, functions = self.functions})
    WriteToFile(moduleName .. ".h", body)
end

function generator:GenerateServerSource(moduleName)
    for _, func in pairs(self.functions) do
        if func.output == Void.paramType then
            func.doReturn = {}
            func.doCast = {}
        else
            func.doReturn = {{}}
            func.doCast = {{}}
        end
    end
    local body = StrRepeat(clientSourceTemplate, { module = moduleName, interface = self.interfaceName, functions = self.functions})
    WriteToFile(moduleName .. ".cpp", body)
end

return generator