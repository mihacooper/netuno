require "helpers"
require "dsl"

int:SpecializeType('int', 0)
str:SpecializeType('std::string', '')
void:SpecializeType('void', nil)
float:SpecializeType('float', 0)
double:SpecializeType('double', 0)
bool:SpecializeType('bool', false)

local generator =
{
    interfaceName = "__InvalidValue__",
    functions = {},
    structures = {},
}

function generator:SetInterfaceName(name)
    self.interfaceName = name
end

function generator:AddFunction(func)
    table.insert(self.functions, func)
end

function generator:AddStructure(str)
    table.insert(self.structures, str)
end

--[[
    Structures
]]

local structureHeaderTemplate = 
[[
#pragma once
#include "lua.hpp"
#include "lang-cpp/sol2/single/sol/sol.hpp"

struct {*name*}
{
{%for _, field  in pairs(fields) do%}
    {*field.paramType*} {*field.paramName*};
{%end%}

    static sol::object ToLuaObject(sol::state_view state, {*name*} str);
    static {*name*} FromLuaObject(const sol::stack_table& obj);
};
]]

local structureSourceTemplate = 
[[
#include <stdlib.h>
#include "{*name*}.h"

sol::object {*name*}::ToLuaObject(sol::state_view state, {*name*} str)
{
    return state.create_table_with(
{%for i = 1, #fields do%}
        "{*fields[i].paramName*}", str.{*fields[i].paramName*}{%if i ~= #fields then%},{%end%} 
{%end%}
    );
}

{*name*} {*name*}::FromLuaObject(const sol::stack_table& obj)
{
    {*name*} str;
{%for _, field  in pairs(fields) do%}
    str.{*field.paramName*} = obj["{*field.paramName*}"];
{%end%}
    return str;
}
]]

function generator:GenerateStructures(moduleName)
    for _, str in pairs(self.structures) do
        local headBody = generate(structureHeaderTemplate, str)
        WriteToFile(str.name .. ".h", headBody)
        local srcBody = generate(structureSourceTemplate, str)
        WriteToFile(str.name .. ".cpp", srcBody)
    end
end

--[[
    Client
]]
function generator:GenerateClientFiles(moduleName)
    self:GenerateStructures()
    self:GenerateClientHeader(moduleName)
    self:GenerateClientSource(moduleName)
end

local clientHeaderTemplate =
[[
#pragma once
#include "lang-cpp/sol2/single/sol/sol.hpp"
{%for _, str  in pairs(structures) do%}
#include "{*str.name*}.h"
{%end%}
#include "lua.hpp"

class {*interface*}
{
public:
    {*interface*}();
    virtual ~{*interface*}();
{%for _, func  in pairs(functions) do%}
    virtual {*func.output.paramType*} {*func.funcName*}({%for i = 1, #func.input do%}{*func.input[i].paramType*} {*func.input[i].paramName*}{%if i ~= #func.input then%}, {%end%} {%end%});
{%end%}

private:
    sol::state m_luaState;
    sol::table m_interface;
};
]]

local clientSourceTemplate =
[[
#include "{*interface*}.h"

#define CHECK(x, msg) { \
    if(!x) { printf("ERROR at %s:%d\n\t%s ", __FILE__, __LINE__, #x); \
        throw std::runtime_error(msg);} }

{*interface*}::{*interface*}()
{
    m_luaState.open_libraries();
    char* cPath = getenv("LUA_RPC_SDK");
    const std::string pathToLoader = (cPath == NULL ? "." : cPath) + std::string("/loader.lua");
    CHECK(m_luaState.do_file(pathToLoader).valid(), "Unable to load loader");
    sol::function loadInterfaceFunc = m_luaState["LoadClientInterface"];
    CHECK(loadInterfaceFunc.valid(), "Unable to get LoadClientInterface function");
    loadInterfaceFunc("{*module*}", "{*interface*}", "cpp");
    m_interface = m_luaState["{*interface*}"];
    CHECK(m_interface.valid(), "Unable to get Lua interface");
}

{*interface*}::~{*interface*}()
{}

{%for _, func  in pairs(functions) do%}
{*func.output.paramType*} {*interface*}::{*func.funcName*}({%for i = 1, #func.input do%}{*func.input[i].paramType*} {*func.input[i].paramName*}{%if i ~= #func.input then%}, {%end%} {%end%})
{
    sol::function func = m_interface["{*func.funcName*}"];
    CHECK(func.valid(), "Unable to get Lua function object");
{-raw-}    {-raw-}{%if func.has_return then%}{-raw-}return {-raw-}{%if func.output.fromLua then%}{*func.output.fromLua*}{%end%}{%end%}(func(m_interface{%for i = 1, #func.input do%}, {%if func.input[i].toLua then%}{*func.input[i].toLua*}(m_luaState,{%else%}({%end%}{*func.input[i].paramName*}){%end%}));
}

{%end%}
]]

function generator:GenerateClientHeader(moduleName)
    local body = generate(clientHeaderTemplate, { structures = self.structures, interface = self.interfaceName, functions = self.functions})
    WriteToFile(self.interfaceName .. ".h", body)
end

function generator:GenerateClientSource(moduleName)
    for _, func in pairs(self.functions) do
        if func.output and func.output.paramType ~= void.paramType then
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
        f.defOutput = f.output or void
        f.defOutput = f.defOutput.default
    end
    self:GenerateServerHeader(moduleName)
    self:GenerateServerSource(moduleName)
end

local serverHeaderTemplate =
[[
#include "lang-cpp/sol2/single/sol/sol.hpp"

class {*interface*}
{
public:
    {*interface*}();
    virtual ~{*interface*}();
{%for _, func  in pairs(functions) do%}
    virtual {*func.output.paramType*} {*func.funcName*}({%for i = 1, #func.input do%}{*func.input[i].paramType*} {*func.input[i].paramName*}{%if i ~= #func.input then%}, {%end%} {%end%});
{%end%}

private:
    sol::state m_luaState;
};
]]

local serverSourceTemplate =
[[
#include "{*interface*}.h"

#define CHECK(x, msg) { \
    if(!x) { printf("ERROR at %s:%d\n\t%s ", __FILE__, __LINE__, #x); \
        throw std::runtime_error(msg);} }

{*interface*}::{*interface*}()
{
    m_luaState.open_libraries();
    char* cPath = getenv("LUA_RPC_SDK");
    const std::string pathToLoader = (cPath == NULL ? "." : cPath) + std::string("/loader.lua");

    sol::usertype<{*interface*}> type("new", sol::no_constructor,
{%for i = 1, #functions do%}
        "{*functions[i].funcName*}", &{*interface*}::{*functions[i].funcName*}{%if i ~= #functions then%},{%end%} 
{%end%}
    );
    sol::stack::push(m_luaState, type);
    sol::stack::pop<sol::object>(m_luaState);
    m_luaState["{*interface*}"] = this;

    CHECK(m_luaState.do_file(pathToLoader).valid(), "Unable to load loader");
    sol::function loadInterfaceFunc = m_luaState["LoadServerInterface"];
    CHECK(loadInterfaceFunc.valid(), "Unable to get LoadServerInterface function");
    loadInterfaceFunc("{*module*}", "{*interface*}", "cpp");
}

{*interface*}::~{*interface*}()
{}

/*****************************************
 ***** PUT YOUR IMPLEMENTATION BELOW *****
 *****************************************/

{%for _, func  in pairs(functions) do%}
{*func.output.paramType*} {*interface*}::{*func.funcName*}({%for i = 1, #func.input do%}{*func.input[i].paramType*} {*func.input[i].paramName*}{%if i ~= #func.input then%}, {%end%} {%end%})
{%if func.has_return then%}
{
    return {*func.output.paramType*}();
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
        if func.output ~= void.paramType then
            func.has_return = true
        end
    end
    local body = generate(serverSourceTemplate, { module = moduleName, interface = self.interfaceName, functions = self.functions})
    WriteToFile(self.interfaceName .. ".cpp", body)
end

return generator