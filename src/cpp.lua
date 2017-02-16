require "helpers"
require "dsl"

Int:SpecializeType('int', 0)
String:SpecializeType('std::string', '')
Void:SpecializeType('void', nil)
Float:SpecializeType('float', 0)
Double:SpecializeType('double', 0)
Bool:SpecializeType('bool', false)

local generator =
{
    interfaceName = "__InvalidValue__",
    functions = {},
    structures = {},
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

function generator:AddStructure(name, str)
    table.insert(self.structures, { structureName = name, fields = str})
end

--[[
    Structures
]]

local structureHeaderTemplate = 
[[
#include "LuaBridge.h"
#include "lua.hpp"

struct {*structureName*}
{
{%for _, field  in pairs(fields) do%}
    {*field.paramType*} {*field.paramName*};
{%end%}
    luabridge::LuaRef ToLuaTable(luabridge::lua_State* state) const;
    void FromLuaTable(const luabridge::LuaRef& ref);
};
]]

local structureSourceTemplate = 
[[
#include <stdlib.h>
#include "{{structureName}}.h"

using namespace luabridge;

luabridge::LuaRef {{structureName}}::ToLuaTable(luabridge::lua_State* state) const
{
    LuaRef ret(state);
{%for _, field  in pairs(fields) do%}
    ret[{*field.paramName*}] = {*field.paramName*};
{%end%}
    return ret;
}

void {{structureName}}::FromLuaTable(const luabridge::LuaRef& ref)
{
{%for _, field  in pairs(fields) do%}
    {*field.paramName*} = ref["{*field.paramName*}"].cast<{*field.paramType*}>();
{%end%}
}
]]

function generator:GenerateStructures(moduleName)
    for _, str in pairs(self.structures) do
        local headBody = generate(structureHeaderTemplate, str)
        WriteToFile(str.structureName .. ".h", headBody)
        local srcBody = generate(structureSourceTemplate, str)
        WriteToFile(str.structureName .. ".cpp", srcBody)
    end
end

--[[
    Client
]]
function generator:GenerateClientFiles(moduleName)
    self:GenerateStructures()
    self.functions = CommonPreparation(self.functions)
    self:GenerateClientHeader(moduleName)
    self:GenerateClientSource(moduleName)
end

local clientHeaderTemplate =
[[
#include "LuaBridge.h"
{%for _, str  in pairs(structures) do%}
#include "{*str.structureName*}.h"
{%end%}
#include "lua.hpp"

class {*interface*}
{
public:
    {*interface*}();
{%for _, func  in pairs(functions) do%}
    virtual {*func.output*} {*func.funcName*}({%for i = 1, #func.input do%}{*func.input[i].paramType*} {*func.input[i].paramName*}{%if i ~= #func.input then%}, {%end%} {%end%});
{%end%}

private:
    luabridge::LuaRef GetFunction(const std::string& name);
    luabridge::lua_State* m_luaState;
};
]]

local clientSourceTemplate =
[[
#include <stdlib.h>
#include "{*interface*}.h"

using namespace luabridge;

#define CHECK(x, msg) { \
    if(x) { printf("ERROR at %s:%d\n\t%s ", __FILE__, __LINE__, #x); \
        throw std::runtime_error(msg);} }

{*interface*}::{*interface*}()
    : m_luaState(luaL_newstate())
{
    char* cPath = getenv("LUA_RPC_SDK");
    std::string pathToSdk = cPath == NULL ? "./" : cPath;
    CHECK(luaL_loadfile(m_luaState, (pathToSdk + "/loader.lua").c_str()), lua_tostring(m_luaState, -1));
    luaL_openlibs(m_luaState);
    CHECK(lua_pcall(m_luaState, 0, 0, 0), lua_tostring(m_luaState, -1));
    LuaRef loadFunc = getGlobal(m_luaState, "LoadClientInterface");
    CHECK(loadFunc.isNil(), "Unable to get LoadClientInterface function");
    loadFunc("{*module*}", "{*interface*}", "cpp");
}

LuaRef {*interface*}::GetFunction(const std::string& name)
{
    LuaRef interface = getGlobal(m_luaState, "{*interface*}");
    CHECK(interface.isNil(), "Unable to get Lua interface");
    LuaRef func = interface[name];
    CHECK(func.isNil(), "Unable to get Lua function object");
    return func;
}

{%for _, func  in pairs(functions) do%}
{*func.output*} {*interface*}::{*func.funcName*}({%for i = 1, #func.input do%}{*func.input[i].paramType*} {*func.input[i].paramName*}{%if i ~= #func.input then%}, {%end%} {%end%})
{
{-raw-}    {-raw-}{%if func.has_return then%}{-raw-}return {-raw-}{%end%}GetFunction("{*func.funcName*}")({%for i = 1, #func.input do%}{*func.input[i].paramName*}{%if i ~= #func.input then%}, {%end%} {%end%}){%if func.has_return then%}.cast<{*func.output*}>(){%end%};
}

{%end%}
]]

function generator:GenerateClientHeader(moduleName)
    local body = generate(clientHeaderTemplate, { structures = self.structures, interface = self.interfaceName, functions = self.functions})
    WriteToFile(self.interfaceName .. ".h", body)
end

function generator:GenerateClientSource(moduleName)
    for _, func in pairs(self.functions) do
        if func.output ~= Void.paramType then
            func.has_return = true
        end
    end
    local body = generate(clientSourceTemplate, { module = moduleName, interface = self.interfaceName,
            functions = self.functions, pathToSdk = os.getenv("")})
    WriteToFile(self.interfaceName .. ".cpp", body)
end

--[[
    Server
]]
function generator:GenerateServerFiles(moduleName)
    self:GenerateStructures()
    for _, f in pairs(self.functions) do
        f.defOutput = f.output or Void
        f.defOutput = f.defOutput.default
    end
    self.functions = CommonPreparation(self.functions)
    self:GenerateServerHeader(moduleName)
    self:GenerateServerSource(moduleName)
end

local serverHeaderTemplate =
[[
#include "LuaBridge.h"
#include "lua.hpp"

class {*interface*}
{
public:
    {*interface*}();
{%for _, func  in pairs(functions) do%}
    virtual {*func.output*} {*func.funcName*}({%for i = 1, #func.input do%}{*func.input[i].paramType*} {*func.input[i].paramName*}{%if i ~= #func.input then%}, {%end%} {%end%});
{%end%}

private:
    luabridge::lua_State* m_luaState;
};
]]

local serverSourceTemplate =
[[
#include <stdlib.h>
#include "{*interface*}.h"

using namespace luabridge;

#define CHECK(x, msg) { \
    if(x) { printf("ERROR at %s:%d\n\t%s ", __FILE__, __LINE__, #x); \
        throw std::runtime_error(msg);} }

{{interface}}::{{interface}}()
    : m_luaState(luaL_newstate())
{
    char* cPath = getenv("LUA_RPC_SDK");
    std::string pathToSdk = cPath == NULL ? "./" : cPath;
    CHECK(luaL_loadfile(m_luaState, (pathToSdk + "/loader.lua").c_str()), lua_tostring(m_luaState, -1));
    luaL_openlibs(m_luaState);
    getGlobalNamespace(m_luaState)
        .beginClass<{{interface}}>("{{interface}}")
{%for _, func  in pairs(functions) do%}
            .addFunction("{*func.funcName*}", &{*interface*}::{*func.funcName*})
{%end%}
        .endClass();
    setGlobal(m_luaState, this, "{*interface*}");
    CHECK(lua_pcall(m_luaState, 0, 0, 0), lua_tostring(m_luaState, -1));
    LuaRef loadFunc = getGlobal(m_luaState, "LoadServerInterface");
    CHECK(loadFunc.isNil(), "Unable to get LoadServerInterface function");
    loadFunc("{*module*}", "{*interface*}", "cpp");
}

/*****************************************
 ***** PUT YOUR IMPLEMENTATION BELOW *****
 *****************************************/

{%for _, func  in pairs(functions) do%}
{*func.output*} {*interface*}::{*func.funcName*}({%for i = 1, #func.input do%}{*func.input[i].paramType*} {*func.input[i].paramName*}{%if i ~= #func.input then%}, {%end%} {%end%})
{%if func.has_return then%}
{
    return {*func.output*}();
}
{%else%}
{}
{%end%}

{%end%}
]]

function generator:GenerateServerHeader(moduleName)
    local body = generate(serverHeaderTemplate, { structures = self.structures, interface = self.interfaceName, functions = self.functions})
    WriteToFile(self.interfaceName .. ".h", body)
end

function generator:GenerateServerSource(moduleName)
    for _, func in pairs(self.functions) do
        if func.output ~= Void.paramType then
            func.has_return = true
        end
    end
    local body = generate(serverSourceTemplate, { module = moduleName, interface = self.interfaceName, functions = self.functions})
    WriteToFile(self.interfaceName .. ".cpp", body)
end

return generator