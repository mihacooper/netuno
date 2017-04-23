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

local header_template =
[[
#pragma once
#include "lua.hpp"
#include "sol2/sol.hpp"
#include "atomic"
#include "thread"
#include "mutex"

namespace rpc_sdk
{

void Initialize(const std::string& pathToModule = "");
void Uninitialize();

typedef std::shared_ptr<sol::state> SdkState;

template<typename T>
inline std::shared_ptr<T> createInterface()
{
    return std::make_shared<T>();
}

{%for _, str  in pairs(structs) do%}
struct {*str.name*}
{
{%for _, field  in pairs(str.fields) do%}
    {*field.type.lang.name*} {*field.name*};
{%end%}
};

{%end%}

{%for _, interface  in pairs(slave_interfaces) do%}
class {*interface.name*}
{
public:
    {*interface.name*}();
    virtual ~{*interface.name*}();
{%for _, func  in ipairs(interface.functions) do%}
    virtual {*func.output.lang.name*} {*func.name*}({%for i = 1, #func.input do%}{*func.input[i].type.lang.name*} {*func.input[i].name*}{%if i ~= #func.input then%}, {%end%} {%end%});
{%end%}
};

{%end%}

{%for _, interface  in pairs(master_interfaces) do%}
class {*interface.name*}
{
public:
    {*interface.name*}();
    virtual ~{*interface.name*}();
{%for _, func  in ipairs(interface.functions) do%}
    virtual {*func.output.lang.name*} {*func.name*}({%for i = 1, #func.input do%}{*func.input[i].type.lang.name*} {*func.input[i].name*}{%if i ~= #func.input then%}, {%end%} {%end%});
{%end%}

private:
    SdkState m_sdkState;
    std::mutex m_lock;
    sol::table m_interface;
};

{%end%}

} // rpc_sdk
]]

local source_template =
[[
#include "{*module_name*}.hpp"

#include <stdlib.h>
#include <memory>
#include <functional>

namespace rpc_sdk
{

#define CHECK(x, msg) { \
    if(!(x)) { printf("ERROR at %s:%d\n\t%s ", __FILE__, __LINE__, #x); \
        throw std::runtime_error(msg);} }

namespace {

std::vector<std::shared_ptr<std::thread>> g_serverThreads;
std::string g_pathToModule = ".";
std::string g_sdkPath = ".";

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

{%for _, interface  in pairs(slave_interfaces) do%}
class WrapperOf{*interface.name*}
{
public:
    WrapperOf{*interface.name*}(std::shared_ptr<{*interface.name*}> obj) : m_interface(obj) {}
{%for _, func  in ipairs(interface.functions) do%}
{-raw-}    {-raw-}{%if func.output.lang.to_lua then%}sol::object{%else%}{*func.output.lang.name*}{%end%} WrapperOf{*func.name*}(sol::this_state state{%for i = 1, #func.input do%}, {%if func.input[i].type.lang.from_lua then%}sol::stack_object{%else%}{*func.input[i].type.lang.name*}{%end%} {*func.input[i].name*}{%end%})
    {
{-raw-}        {-raw-}{%if func.output ~= none_t then%}{-raw-}return {-raw-}{%if func.output.lang.to_lua then%}{*func.output.lang.to_lua*}(state, {%else%}({%end%}{%else%}({%end%}m_interface->{*func.name*}({%for i = 1, #func.input do%}{%if func.input[i].type.lang.from_lua then%}{*func.input[i].type.lang.from_lua*}{%end%}({*func.input[i].name*}){%if i ~= #func.input then%},{%end%}{%end%}));
    }

{%end%}
    std::shared_ptr<{*interface.name*}> m_interface;
};
{%end%}

{%for _, interface  in pairs(slave_interfaces) do%}
sol::object {*interface.name*}Creator(const sol::this_state& state)
{
    auto ptr = createInterface<{*interface.name*}>();
    if (ptr.get() == nullptr)
        return sol::nil;
    return sol::make_object(state, std::make_unique<WrapperOf{*interface.name*}>(ptr));
}

{%end%}

void RunNewState(sol::this_state, const sol::function&);

SdkState CreateNewState()
{
    SdkState sdkState = std::make_shared<sol::state>();
    sdkState->open_libraries();

    sdkState->script("package.path = package.path .. ';' .. '" + g_sdkPath + "' .. '/?.lua'");
    const std::string pathToLoader = g_sdkPath + std::string("/loader.lua");
    sol::function loadInterfaceFunc = sdkState->script_file(pathToLoader);
    CHECK(loadInterfaceFunc.valid(), "Unable to load loader");
    loadInterfaceFunc(g_pathToModule.empty() ? "{*module_path*}" : g_pathToModule, "cpp", "{*target*}");

{%for _, interface  in pairs(slave_interfaces) do%}
    {
        sol::usertype<WrapperOf{*interface.name*}> type(
    {%for i = 1, #interface.functions do%}
            "{*interface.functions[i].name*}", &WrapperOf{*interface.name*}::WrapperOf{*interface.functions[i].name*}{%if i ~= #interface.functions then%},{%end%}

    {%end%}
        );
        sol::stack::push(*sdkState, type);
        sol::stack::pop<sol::object>(*sdkState);
    }
    (*sdkState)["{*interface.name*}"]["server"] = &{*interface.name*}Creator;
{%end%}
    (*sdkState)["run_new_state"] = std::function<void(sol::this_state, const sol::function&)>(
                std::bind(&RunNewState, std::placeholders::_1, std::placeholders::_2));
    return sdkState;
}

void RunNewState(sol::this_state state, const sol::function& func)
{
    SdkState sdkState = CreateNewState();
    const std::string rawFunc = sol::state_view(state)["string"]["dump"](func);
    g_serverThreads.push_back(
        std::make_shared<std::thread>([=](SdkState sdkState){
            sol::function runnner = (*sdkState)["loadstring"](rawFunc);
            runnner();
        }, sdkState));
}

}

{%for _, interface  in pairs(master_interfaces) do%}
{*interface.name*}::{*interface.name*}() : m_sdkState(CreateNewState())
{
    std::lock_guard<std::mutex> lock(m_lock);
    sol::table interfaceType = (*m_sdkState)["{*interface.name*}"];
    CHECK(interfaceType.valid(), "Unable to get Lua interface type");
    m_interface = interfaceType["new"](interfaceType);
    CHECK(m_interface.valid(), "Unable to get Lua interface instance");
}

{*interface.name*}::~{*interface.name*}()
{
    std::lock_guard<std::mutex> lock(m_lock);
    sol::function del = m_interface["%del"];
    CHECK(del.valid(), "Unable to get Lua function object: " + std::string("{*interface.name*}::'%del'"));
    del(m_interface);
}

{%for _, func  in ipairs(interface.functions) do%}
{*func.output.lang.name*} {*interface.name*}::{*func.name*}({%for i = 1, #func.input do%}{*func.input[i].type.lang.name*} {*func.input[i].name*}{%if i ~= #func.input then%}, {%end%} {%end%})
{
    std::lock_guard<std::mutex> lock(m_lock);
    sol::function func = m_interface["{*func.name*}"];
    CHECK(func.valid(), "Unable to get Lua function object: " + std::string("{*interface.name*}::{*func.name*}"));
{-raw-}    {-raw-}{%if func.output ~= none_t then%}{-raw-}return {-raw-}{%if func.output.lang.from_lua then%}{*func.output.lang.from_lua*}{%end%}{%end%}(func({%for i = 1, #func.input do%}{%if func.input[i].type.lang.to_lua then%}{*func.input[i].type.lang.to_lua*}(*m_sdkState, {%else%}({%end%}{*func.input[i].name*}){%if i ~= #func.input then%},{%end%}{%end%}));
}

{%end%}
{%end%}

void Initialize(const std::string& pathToModule)
{
    const char* cPath = getenv("LUA_RPC_SDK");
    g_sdkPath = cPath ? cPath : ".";
    g_pathToModule = pathToModule;
{%if #slave_interfaces > 0 then%}
    SdkState sdkState = CreateNewState();
    CHECK(sdkState.get() != nullptr, "Unable to create new state");
    (*sdkState)["system"]["run"]();
{%end%}
}

void Uninitialize()
{
    sol::state state;
    state.open_libraries(sol::lib::base, sol::lib::package, sol::lib::os, sol::lib::string);
    state.script("package.path = package.path .. ';' .. '" + g_sdkPath + "' .. '/effil/?.lua'");
    state.script("package.cpath = package.cpath .. ';' .. '" + g_sdkPath + "' .. '/effil/?.so'");
    state.script("require 'effil'.G.shutdown = true");
    for (auto thread: g_serverThreads)
    {
        thread->join();
    }
    g_serverThreads.clear();
}

} // rpc_sdk
]]

return function(props)
    local config = {
        target = target,
        module_name = props.module_name,
        module_path = props.module_path,
        structs = system.structures,
        master_interfaces = system.master_interfaces,
        slave_interfaces = system.slave_interfaces
    }
    local head_body = generate(header_template, config)
    local src_body = generate(source_template, config)

    write_to_file(props.module_name .. ".cpp", src_body)
    write_to_file(props.module_name .. ".hpp", head_body)
end