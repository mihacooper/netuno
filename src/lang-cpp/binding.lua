require "helpers"
require "dsl"

int_t:specialize_type({ name = 'int'})
str_t:specialize_type({ name = 'std::string'})
none_t:specialize_type({ name = 'void'})
float_t:specialize_type({ name = 'float'})
double_t:specialize_type({ name = 'double'})
bool_t:specialize_type({ name = 'bool'})
struct:specialize_type(
    {
        new_type = function(ntype)
            ntype.lang.name = ntype.name
            ntype.lang.to_lua = ntype.name .. "ToLuaObject"
            ntype.lang.from_lua = ntype.name .. "FromLuaObject"
        end,
    }
)

local client_header_base =
[[
#pragma once
#include "lua.hpp"
#include "lang-cpp/sol2/single/sol/sol.hpp"

]]

local client_source_base =
[[
#include <stdlib.h>
#include "{*module_name*}.hpp"

#define CHECK(x, msg) { \
    if(!x) { printf("ERROR at %s:%d\n\t%s ", __FILE__, __LINE__, #x); \
        throw std::runtime_error(msg);} }
]]

local server_header_base, server_source_base = client_header_base, client_source_base

local structure_header_template =
[[
struct {*name*}
{
{%for _, field  in pairs(fields) do%}
    {*field.type.lang.name*} {*field.name*};
{%end%}
};

]]

local structure_source_template =
[[

static sol::object {*name*}ToLuaObject(sol::state_view state, {*name*} str)
{
    return state.create_table_with(
{%for i = 1, #fields do%}
        "{*fields[i].name*}", str.{*fields[i].name*}{%if i ~= #fields then%},{%end%} 
{%end%}
    );
}

static {*name*} {*name*}FromLuaObject(const sol::stack_table& obj)
{
    {*name*} str;
{%for _, field  in pairs(fields) do%}
    str.{*field.name*} = obj["{*field.name*}"];
{%end%}
    return str;
}

]]

local client_header_template =
[[
class {*interface*}
{
public:
    {*interface*}();
    virtual ~{*interface*}();
{%for _, func  in ipairs(functions) do%}
    virtual {*func.output.lang.name*} {*func.name*}({%for i = 1, #func.input do%}{*func.input[i].type.lang.name*} {*func.input[i].name*}{%if i ~= #func.input then%}, {%end%} {%end%});
{%end%}

private:
    sol::state m_luaState;
    sol::table m_interface;
};

]]

local client_source_template =
[[
{*interface*}::{*interface*}()
{
    m_luaState.open_libraries();
    const char* cPath = getenv("LUA_RPC_SDK");
    const std::string sdkPath = cPath ? cPath : ".";
    const std::string pathToLoader = sdkPath + std::string("/loader.lua");
    m_luaState.script("package.path = package.path .. ';' .. '" + sdkPath + "' .. '/?.lua'");
    sol::function loadInterfaceFunc = m_luaState.script_file(pathToLoader);
    CHECK(loadInterfaceFunc.valid(), "Unable to load loader");
    loadInterfaceFunc("{*module_path*}", "{*interface*}", "cpp", "client");
    m_interface = m_luaState["{*interface*}"];
    CHECK(m_interface.valid(), "Unable to get Lua interface");
}

{*interface*}::~{*interface*}()
{}

{%for _, func  in ipairs(functions) do%}
{*func.output.lang.name*} {*interface*}::{*func.name*}({%for i = 1, #func.input do%}{*func.input[i].type.lang.name*} {*func.input[i].name*}{%if i ~= #func.input then%}, {%end%} {%end%})
{
    sol::function func = m_interface["functions"]["{*func.name*}"]["impl"];
    CHECK(func.valid(), "Unable to get Lua function object");
{-raw-}    {-raw-}{%if func.output ~= none_t then%}{-raw-}return {-raw-}{%if func.output.lang.from_lua then%}{*func.output.lang.from_lua*}{%end%}{%end%}(func(m_interface{%for i = 1, #func.input do%}, {%if func.input[i].type.lang.to_lua then%}{*func.input[i].type.lang.to_lua*}(m_luaState,{%else%}({%end%}{*func.input[i].name*}){%end%}));
}

{%end%}
]]

local serverHeaderTemplate =
[[
class {*interface*}
{
public:
    {*interface*}();
    virtual ~{*interface*}();
{%for _, func  in ipairs(functions) do%}
    virtual {*func.output.lang.name*} {*func.name*}({%for i = 1, #func.input do%}{*func.input[i].type.lang.name*} {*func.input[i].name*}{%if i ~= #func.input then%}, {%end%} {%end%});
{%end%}

private:
    sol::state m_luaState;
};

]]

local serverSourceTemplate =
[[
{*interface*}::{*interface*}()
{
    m_luaState.open_libraries();
    const char* cPath = getenv("LUA_RPC_SDK");
    const std::string sdkPath = cPath ? cPath : ".";
    const std::string pathToLoader = sdkPath + std::string("/loader.lua");
    m_luaState.script("package.path = package.path .. ';' .. '" + sdkPath + "' .. '/?.lua'");

    sol::function loadInterfaceFunc = m_luaState.script_file(pathToLoader);
    CHECK(loadInterfaceFunc.valid(), "Unable to load loader");
    loadInterfaceFunc("{*module_path*}", "{*interface*}", "cpp", "client");

    sol::usertype<{*interface*}> type("new", sol::no_constructor,
{%for i = 1, #functions do%}
        "{*functions[i].name*}", &{*interface*}::{*functions[i].name*}{%if i ~= #functions then%},{%end%} 
{%end%}
    );
    sol::stack::push(m_luaState, type);
    sol::stack::pop<sol::object>(m_luaState);
    m_luaState["{*interface*}"]["server"] = this;
}

{*interface*}::~{*interface*}()
{}

/*****************************************
 ***** PUT YOUR IMPLEMENTATION BELOW *****
 *****************************************/

{%for _, func  in ipairs(functions) do%}
{*func.output.lang.name*} {*interface*}::{*func.name*}({%for i = 1, #func.input do%}{*func.input[i].type.lang.name*} {*func.input[i].name*}{%if i ~= #func.input then%}, {%end%} {%end%})
{%if func.output ~= none_t then%}
{
    return {*func.output.lang.name*}();
}
{%else%}
{}
{%end%}

{%end%}

]]

return function(interface, props)
    local structs = GetStructures()
    --local interfaces = GetInterfaces()
    local head_body, src_body = "", ""

    if target == "client" then
        head_body = client_header_base
        src_body = src_body .. generate(client_source_base, { module_name = props.module_name })
    elseif target == "server" then
        head_body = server_header_base
        src_body = src_body .. generate(server_source_base, { module_name = props.module_name })
    end

    for _, str in pairs(structs) do
        head_body = head_body .. generate(structure_header_template, str)
        src_body = src_body .. generate(structure_source_template, str)
    end
    if target == "client" then
        head_body = head_body .. generate(client_header_template, { structures = structs, interface = interface.name,
                functions = interface.functions})

        src_body = src_body .. generate(client_source_template, { module_path = props.module_path, interface = interface.name,
                functions = interface.functions, none_t = none_t})
    elseif target == "server" then
        head_body = head_body .. generate(serverHeaderTemplate, { structures = structs, interface = interface.name, functions = interface.functions})
        src_body = src_body .. generate(serverSourceTemplate, { module_path = props.module_path, interface = interface.name,
                functions = interface.functions, none_t = none_t})
   end
    write_to_file(props.module_name .. ".cpp", src_body)
    write_to_file(props.module_name .. ".hpp", head_body)
end