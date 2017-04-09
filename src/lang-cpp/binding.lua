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
#include "externals/sol2/sol.hpp"
#include "atomic"
#include "thread"
#include "mutex"

namespace rpc_sdk
{

class RpcSdk {
public:
    RpcSdk();
    ~RpcSdk();
    void Initialize(const std::string& pathToModule = "", int port = 9898);
    void Uninitialize();

{%if #slave_interfaces > 0 then%}
private:
    void ServerWorker(int port);

    std::atomic_bool m_bStopThread;
    std::shared_ptr<std::thread> m_pServerThread;
{%end%}
};

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
    ~{*interface.name*}();
{%for _, func  in ipairs(interface.functions) do%}
    {*func.output.lang.name*} {*func.name*}({%for i = 1, #func.input do%}{*func.input[i].type.lang.name*} {*func.input[i].name*}{%if i ~= #func.input then%}, {%end%} {%end%});
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

namespace rpc_sdk
{

#define CHECK(x, msg) { \
    if(!(x)) { printf("ERROR at %s:%d\n\t%s ", __FILE__, __LINE__, #x); \
        throw std::runtime_error(msg);} }

struct SdkState
{
    sol::state state;
    std::mutex lock;
};

std::shared_ptr<SdkState> g_sdkState;

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
class WrapperOf{*interface.name*} : public {*interface.name*}
{
public:
{%for _, func  in ipairs(interface.functions) do%}
{-raw-}    {-raw-}{%if func.output.lang.to_lua then%}sol::object{%else%}{*func.output.lang.name*}{%end%} WrapperOf{*func.name*}({%for i = 1, #func.input do%}{%if func.input[i].type.lang.from_lua then%}sol::stack_object{%else%}{*func.input[i].type.lang.name*}{%end%} {*func.input[i].name*}{%if i ~= #func.input then%}, {%end%} {%end%})
    {
{-raw-}        {-raw-}{%if func.output ~= none_t then%}{-raw-}return {-raw-}{%if func.output.lang.to_lua then%}{*func.output.lang.to_lua*}(g_sdkState->state, {%else%}({%end%}{%else%}({%end%}{*interface.name*}::{*func.name*}({%for i = 1, #func.input do%}{%if func.input[i].type.lang.from_lua then%}{*func.input[i].type.lang.from_lua*}{%end%}({*func.input[i].name*}){%if i ~= #func.input then%},{%end%}{%end%}));
    }

{%end%}
};
{%end%}

{%for _, interface  in pairs(master_interfaces) do%}
{*interface.name*}::{*interface.name*}()
{
    std::lock_guard<std::mutex> lock(g_sdkState->lock);
    sol::table interfaceFactory = g_sdkState->state["{*interface.name*}"];
    CHECK(interfaceFactory.valid(), "Unable to get Lua interface type");
    m_interface = interfaceFactory["new"](interfaceFactory);
    CHECK(m_interface.valid(), "Unable to get Lua interface instance");
}

{*interface.name*}::~{*interface.name*}()
{}

{%for _, func  in ipairs(interface.functions) do%}
{*func.output.lang.name*} {*interface.name*}::{*func.name*}({%for i = 1, #func.input do%}{*func.input[i].type.lang.name*} {*func.input[i].name*}{%if i ~= #func.input then%}, {%end%} {%end%})
{
    std::lock_guard<std::mutex> lock(g_sdkState->lock);
    sol::function func = m_interface["{*func.name*}"];
    CHECK(func.valid(), "Unable to get Lua function object");
{-raw-}    {-raw-}{%if func.output ~= none_t then%}{-raw-}return {-raw-}{%if func.output.lang.from_lua then%}{*func.output.lang.from_lua*}{%end%}{%end%}(func({%for i = 1, #func.input do%}{%if func.input[i].type.lang.to_lua then%}{*func.input[i].type.lang.to_lua*}(g_sdkState->state, {%else%}({%end%}{*func.input[i].name*}){%if i ~= #func.input then%},{%end%}{%end%}));
}

{%end%}
{%end%}
{%if #slave_interfaces > 0 then%}
namespace {
{%for _, interface  in pairs(slave_interfaces) do%}
sol::object {*interface.name*}Creator(const sol::this_state& state)
{
    sol::usertype<WrapperOf{*interface.name*}> type(
{%for i = 1, #interface.functions do%}
        "{*interface.functions[i].name*}", &WrapperOf{*interface.name*}::WrapperOf{*interface.functions[i].name*}{%if i ~= #interface.functions then%},{%end%}
{%end%}
    );
    sol::stack::push(state, type);
    sol::stack::pop<sol::object>(state);
    return sol::make_object(state, WrapperOf{*interface.name*}());
}

{%end%}
}
{%end%}

RpcSdk::RpcSdk() {%if #slave_interfaces > 0 then%} : m_bStopThread(false), m_pServerThread(nullptr) {%end%}{ }

{%if #slave_interfaces > 0 then%}
void RpcSdk::ServerWorker(int port)
{
    {
        std::lock_guard<std::mutex> lock(g_sdkState->lock);
        g_sdkState->state["connectors"]["initialize"]();
    }
    while(!m_bStopThread) {
        std::lock_guard<std::mutex> lock(g_sdkState->lock);
        g_sdkState->state["connectors"]["loop"]();
    };
}
{%end%}

void RpcSdk::Initialize(const std::string& pathToModule, int port)
{
    g_sdkState = std::make_shared<SdkState>();
    CHECK(g_sdkState.get() != nullptr, "Unable to create lus state");
    g_sdkState->state.open_libraries();

    const char* cPath = getenv("LUA_RPC_SDK");
    const std::string sdkPath = cPath ? cPath : ".";
    const std::string pathToLoader = sdkPath + std::string("/loader.lua");
    g_sdkState->state.script("package.path = package.path .. ';' .. '" + sdkPath + "' .. '/?.lua'");
    sol::function loadInterfaceFunc = g_sdkState->state.script_file(pathToLoader);
    CHECK(loadInterfaceFunc.valid(), "Unable to load loader");
    loadInterfaceFunc(pathToModule.empty() ? "{*module_path*}" : pathToModule, "cpp", "{*target*}");

{%if #slave_interfaces > 0 then%}
{%for _, interface  in pairs(slave_interfaces) do%}
    g_sdkState->state["{*interface.name*}"]["server"] = &{*interface.name*}Creator;
{%end%}
    m_pServerThread = std::make_shared<std::thread>(&RpcSdk::ServerWorker, this, port);
{%end%}
}

void RpcSdk::Uninitialize()
{
{%if #slave_interfaces > 0 then%}
    if (m_pServerThread)
    {
        m_bStopThread = true;
        m_pServerThread->join();
    }
    m_pServerThread.reset();
{%end%}
    g_sdkState.reset();
}

RpcSdk::~RpcSdk()
{
    Uninitialize();
}

} // rpc_sdk
]]

return function(props)
    local structs = GetStructures()
    local config = {
        target = target,
        module_name = props.module_name,
        module_path = props.module_path,
        structs = structs,
        master_interfaces = master_interfaces,
        slave_interfaces = slave_interfaces
    }
    local head_body = generate(header_template, config)
    local src_body = generate(source_template, config)

    write_to_file(props.module_name .. ".cpp", src_body)
    write_to_file(props.module_name .. ".hpp", head_body)
end