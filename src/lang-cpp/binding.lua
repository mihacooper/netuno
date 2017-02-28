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

local client_header_template =
[[
#pragma once
#include "lua.hpp"
#include "externals/sol2/sol.hpp"

namespace rpc_sdk
{

void InitializeSdk(const std::string& pathToModule = "");

{%for _, str  in pairs(structs) do%}
struct {*str.name*}
{
{%for _, field  in pairs(str.fields) do%}
    {*field.type.lang.name*} {*field.name*};
{%end%}
};

{%end%}

{%for _, interface  in pairs(interfaces) do%}
class {*interface.name*}
{
public:
    {*interface.name*}();
    virtual ~{*interface.name*}();
{%for _, func  in ipairs(interface.functions) do%}
    virtual {*func.output.lang.name*} {*func.name*}({%for i = 1, #func.input do%}{*func.input[i].type.lang.name*} {*func.input[i].name*}{%if i ~= #func.input then%}, {%end%} {%end%});
{%end%}

private:
    sol::table m_interface;
};

{%end%}

} // rpc_sdk
]]

local client_source_template =
[[
#include "{*module_name*}.hpp"

#include <stdlib.h>
#include <memory>

namespace rpc_sdk
{

#define CHECK(x, msg) { \
    if(!(x)) { printf("ERROR at %s:%d\n\t%s ", __FILE__, __LINE__, #x); \
        throw std::runtime_error(msg);} }

std::shared_ptr<sol::state> g_luaState;

void InitializeSdk(const std::string& pathToModule)
{
    g_luaState = std::make_shared<sol::state>();
    CHECK(g_luaState.get() != nullptr, "Unable to create lus state");
    g_luaState->open_libraries();

    const char* cPath = getenv("LUA_RPC_SDK");
    const std::string sdkPath = cPath ? cPath : ".";
    const std::string pathToLoader = sdkPath + std::string("/loader.lua");
    g_luaState->script("package.path = package.path .. ';' .. '" + sdkPath + "' .. '/?.lua'");
    sol::function loadInterfaceFunc = g_luaState->script_file(pathToLoader);
    CHECK(loadInterfaceFunc.valid(), "Unable to load loader");

    loadInterfaceFunc(pathToModule.empty() ? "{*module_path*}" : pathToModule, "cpp", "client");
}

{%for _, str  in pairs(structs) do%}
static sol::object {*str.name*}ToLuaObject(sol::state_view state, {*str.name*} str)
{
    return state.create_table_with(
{%for i = 1, #str.fields do%}
        "{*str.fields[i].name*}", str.{*str.fields[i].name*}{%if i ~= #str.fields then%},{%end%} 
{%end%}
    );
}

static {*str.name*} {*str.name*}FromLuaObject(const sol::stack_table& obj)
{
    {*str.name*} str;
{%for _, field  in pairs(str.fields) do%}
    str.{*field.name*} = obj["{*field.name*}"];
{%end%}
    return str;
}

{%end%}

{%for _, interface  in pairs(interfaces) do%}
{*interface.name*}::{*interface.name*}()
{
    m_interface = (*g_luaState)["{*interface.name*}"]();
    CHECK(m_interface.valid(), "Unable to get Lua interface");
}

{*interface.name*}::~{*interface.name*}()
{}

{%for _, func  in ipairs(interface.functions) do%}
{*func.output.lang.name*} {*interface.name*}::{*func.name*}({%for i = 1, #func.input do%}{*func.input[i].type.lang.name*} {*func.input[i].name*}{%if i ~= #func.input then%}, {%end%} {%end%})
{
    sol::function func = m_interface["{*func.name*}"];
    CHECK(func.valid(), "Unable to get Lua function object");
{-raw-}    {-raw-}{%if func.output ~= none_t then%}{-raw-}return {-raw-}{%if func.output.lang.from_lua then%}{*func.output.lang.from_lua*}{%end%}{%end%}(func(m_interface{%for i = 1, #func.input do%}, {%if func.input[i].type.lang.to_lua then%}{*func.input[i].type.lang.to_lua*}(*g_luaState, {%else%}({%end%}{*func.input[i].name*}){%end%}));
}

{%end%}
{%end%}

#undef CHECK

} // rpc_sdk
]]

local server_header_template =
[[
#pragma once
#include "lua.hpp"
#include "externals/sol2/sol.hpp"

namespace rpc_sdk
{

void InitializeSdk(const std::string& pathToModule = "");

{%for _, str  in pairs(structs) do%}
struct {*str.name*}
{
{%for _, field  in pairs(str.fields) do%}
    {*field.type.lang.name*} {*field.name*};
{%end%}
};

{%end%}

{%for _, interface  in pairs(interfaces) do%}
class {*interface.name*}
{
public:
    {*interface.name*}();
    ~{*interface.name*}();
{%for _, func  in ipairs(interface.functions) do%}
    {*func.output.lang.name*} {*func.name*}({%for i = 1, #func.input do%}{*func.input[i].type.lang.name*} {*func.input[i].name*}{%if i ~= #func.input then%}, {%end%} {%end%});
{%end%}
};

{%end%}

} // rpc_sdk
]]

local server_source_template =
[[
#include "{*module_name*}.hpp"

#include <stdlib.h>
#include <memory>

namespace rpc_sdk
{

#define CHECK(x, msg) { \
    if(!(x)) { printf("ERROR at %s:%d\n\t%s ", __FILE__, __LINE__, #x); \
        throw std::runtime_error(msg);} }

std::shared_ptr<sol::state> g_luaState;

void InitializeSdk(const std::string& pathToModule)
{
    g_luaState = std::make_shared<sol::state>();
    CHECK(g_luaState.get() != nullptr, "Unable to create lus state");
    g_luaState->open_libraries();

    const char* cPath = getenv("LUA_RPC_SDK");
    const std::string sdkPath = cPath ? cPath : ".";
    const std::string pathToLoader = sdkPath + std::string("/loader.lua");
    g_luaState->script("package.path = package.path .. ';' .. '" + sdkPath + "' .. '/?.lua'");
    sol::function loadInterfaceFunc = g_luaState->script_file(pathToLoader);
    CHECK(loadInterfaceFunc.valid(), "Unable to load loader");
    loadInterfaceFunc(pathToModule.empty() ? "{*module_path*}" : pathToModule, "cpp", "server");

{%for _, interface  in pairs(interfaces) do%}
    sol::usertype<{*interface.name*}> type(
{%for i = 1, #interface.functions do%}
        "{*interface.functions[i].name*}", &{*interface.name*}::{*interface.functions[i].name*}{%if i ~= #interface.functions then%},{%end%} 
{%end%}
    );
    sol::stack::push(*g_luaState, type);
    (*g_luaState)["{*interface.name*}"]["server"] = sol::stack::pop<sol::object>(*g_luaState);
{%end%}
    sol::table server = (*g_luaState)["tcp"]["new_server"](9898);
    server["run"](server);
}

} // rpc_sdk
]]

return function(props)
    local structs = GetStructures()
    local interfaces = GetInterfaces()

    local header_template =
            target == "client" and client_header_template or
            target == "server" and server_header_template or
            error("Invalid terget")
    local source_template =
            target == "client" and client_source_template or
            target == "server" and server_source_template or
            error("Invalid terget")

    local head_body = generate(header_template,
        {
            module_name = props.module_name,
            module_path = props.module_path,
            structs = structs,
            interfaces = interfaces,
        }
    )
    local src_body = generate(source_template,
            {
                module_name = props.module_name,
                module_path = props.module_path,
                structs = structs,
                interfaces = interfaces,
            }
    )

    write_to_file(props.module_name .. ".cpp", src_body)
    write_to_file(props.module_name .. ".hpp", head_body)
end