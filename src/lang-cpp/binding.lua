require "helpers"
require "dsl"

int_t:
    specialize_type({ name = 'int'})
str_t:
    specialize_type({ name = 'std::string'})
none_t:
    specialize_type({ name = 'void'})
float_t:
    specialize_type({ name = 'float'})
double_t:
    specialize_type({ name = 'double'})
bool_t:
    specialize_type({ name = 'bool'})
struct:
    specialize_type(
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
#include "sol.hpp"
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

{%for _, interface  in pairs(slave_ifaces) do%}
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

{%for _, interface  in pairs(master_ifaces) do%}
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
#include <map>

namespace rpc_sdk
{

#define CHECK(x, msg) { \
    if(!(x)) { printf("ERROR at %s:%d\n\t%s ", __FILE__, __LINE__, #x); \
        throw std::runtime_error(msg);} }

namespace {

class OutstateAdapter;
SdkState CreateNewState();

typedef std::shared_ptr<OutstateAdapter> OutstateAdapterPtr;

// Pathes
std::string g_sdkPath = ".";
std::string g_pathToModule = "";

// State
std::recursive_mutex g_stateLock;
SdkState g_sdkState;

// Global storage
struct OutstateContext
{
    std::recursive_mutex lock;
    SdkState   state;
    size_t     storageId;

    OutstateContext(SdkState _state = nullptr) : state(_state.get() ? _state : CreateNewState()) {}
};

typedef std::shared_ptr<OutstateContext> OutstateContextPtr;

std::recursive_mutex g_outstatesLock;
std::vector<OutstateContextPtr> g_outstates;
std::mutex g_servicesLock;
std::vector<std::shared_ptr<std::thread>> g_serverThreads;

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

{%for _, interface  in pairs(slave_ifaces) do%}
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

{%for _, interface  in pairs(slave_ifaces) do%}
sol::object {*interface.name*}Creator(sol::state_view state)
{
    auto ptr = createInterface<{*interface.name*}>();
    if (ptr.get() == nullptr)
        return sol::nil;

    const std::string pathToLoader = g_sdkPath + std::string("/src/loader.lua");
    sol::function loadInterfaceFunc = state.script_file(pathToLoader);
    CHECK(loadInterfaceFunc.valid(), "Unable to load loader");
    loadInterfaceFunc(g_pathToModule.empty() ? "{*module_path*}" : g_pathToModule, "cpp", "{*target*}");

    state["{*interface.name*}"]["server"] = [=]() -> sol::object { return sol::make_object(state, std::make_unique<WrapperOf{*interface.name*}>(ptr)); };
    sol::table iface = state["{*interface.name*}"]["new"](state["{*interface.name*}"]);
    return iface;
}

{%end%}

sol::object SystemComponentCreator(sol::this_state state, const std::string& cmpName)
{
    static std::map<std::string, sol::object(*)(sol::state_view)> sysCreators
    {
{%for i = 1, #slave_ifaces do%}
                std::make_pair("interface_{*slave_ifaces[i].name*}", &{*slave_ifaces[i].name*}Creator){%if i ~= #slave_ifaces then%},{%end%}
{%end%}
    };
    if (sysCreators.find(cmpName) == sysCreators.end())
        throw sol::error("Unable to find system component '" + cmpName + "'");
    return sysCreators[cmpName](state);
}

int OutstateCreator(const std::string& cmpName, const std::string& loaderData)
{
    OutstateContextPtr context = std::make_shared<OutstateContext>();
    int componentId = -1;
    {
        std::lock_guard<std::recursive_mutex> lock(g_outstatesLock);
        g_outstates.push_back(context);
        componentId = g_outstates.size() - 1;
    }
    sol::function loader = (*context->state)["loadstring"](loaderData);
    loader();
    return componentId;
}

void OutstateUnload(const size_t id)
{
    std::lock_guard<std::recursive_mutex> lock(g_outstatesLock);
    g_outstates[id].reset();
}

void ServiceCreator(const std::string& cmpName, const std::string& loaderData)
{
    std::lock_guard<std::mutex> lock(g_servicesLock);
    SdkState state = CreateNewState();

    g_serverThreads.push_back(
        std::make_shared<std::thread>([=](SdkState state){
            sol::function loader = (*state)["loadstring"](loaderData);
            loader();
        }, state));
}

void OutstateMethodCall(sol::this_state thisState, size_t id, const std::string& method, const std::string& table)
{
    sol::state_view state(thisState);
    OutstateContextPtr componentContext;
    {
        std::lock_guard<std::recursive_mutex> lock(g_outstatesLock);
        componentContext = g_outstates[id];
    }

    std::lock_guard<std::recursive_mutex> lock(componentContext->lock);
    sol::table obj = (*componentContext->state)[table];
    obj[method](obj);
}

void CStorageMethodCall(sol::this_state thisState, const std::string& method)
{
    OutstateMethodCall(thisState, 0, method, "cstorage");
}

SdkState CreateNewState()
{
    SdkState sdkState = std::make_shared<sol::state>();
    sdkState->open_libraries();

    sdkState->script("package.path = package.path .. ';' .. '" + g_sdkPath + "' .. '/src/?.lua'");
    sdkState->script("require 'helpers'");
    (*sdkState)["system"] = sdkState->create_table();
    (*sdkState)["system"]["cstorage"]        = &CStorageMethodCall;
    (*sdkState)["system"]["outstate_create"] = &OutstateCreator;
    (*sdkState)["system"]["outstate_call"]   = &OutstateMethodCall;
    (*sdkState)["system"]["outstate_unload"] = &OutstateUnload;
    (*sdkState)["system"]["service_create"]  = &ServiceCreator;
    (*sdkState)["system"]["syscmp_create"] = &SystemComponentCreator;

    std::string csApiLoader;
    {
        std::lock_guard<std::recursive_mutex> lock(g_stateLock);
        csApiLoader = (*g_sdkState)["cstorage"]["get_cstorage_api"]((*g_sdkState)["cstorage"]);
    }

    sol::function apiLoader = (*sdkState)["loadstring"](csApiLoader);
    apiLoader();

{%for _, interface  in pairs(slave_ifaces) do%}
    {
        sol::usertype<WrapperOf{*interface.name*}> type(
    {%for i = 1, #interface.functions do%}
            "{*interface.functions[i].name*}", &WrapperOf{*interface.name*}::WrapperOf{*interface.functions[i].name*}{%if i ~= #interface.functions then%},{%end%}

    {%end%}
        );
        sol::stack::push(*sdkState, type);
        sol::stack::pop<sol::object>(*sdkState);
    }
{%end%}
    return sdkState;
}

}

{%for _, interface  in pairs(master_ifaces) do%}
{*interface.name*}::{*interface.name*}() : m_sdkState(CreateNewState())
{
    std::lock_guard<std::mutex> lock(m_lock);

    const std::string pathToLoader = g_sdkPath + std::string("/src/loader.lua");
    sol::function loadInterfaceFunc = m_sdkState->script_file(pathToLoader);
    CHECK(loadInterfaceFunc.valid(), "Unable to load loader");
    loadInterfaceFunc(g_pathToModule.empty() ? "{*module_path*}" : g_pathToModule, "cpp", "{*target*}");

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
{-raw-}    {-raw-}{%if func.output ~= none_t then%}{-raw-}return {-raw-}{%if func.output.lang.from_lua then%}{*func.output.lang.from_lua*}{%end%}{%end%}(func(m_interface{%for i = 1, #func.input do%}, {%if func.input[i].type.lang.to_lua then%}{*func.input[i].type.lang.to_lua*}(*m_sdkState, {%else%}({%end%}{*func.input[i].name*}){%end%}));
}

{%end%}
{%end%}

void Initialize(const std::string& pathToModule)
{
    const char* cPath = getenv("LUA_RPC_SDK");
    g_sdkPath = cPath ? cPath : ".";
    g_pathToModule = pathToModule;

    g_sdkState = std::make_shared<sol::state>();
    g_sdkState->open_libraries();
    g_outstates.push_back(std::make_shared<OutstateContext>(g_sdkState));

    (*g_sdkState)["system"] = g_sdkState->create_table();
    (*g_sdkState)["system"]["outstate_create"] = &OutstateCreator;
    (*g_sdkState)["system"]["outstate_call"] = &OutstateMethodCall;
    (*g_sdkState)["system"]["outstate_unload"] = &OutstateUnload;
    (*g_sdkState)["system"]["service_create"] = &ServiceCreator;

    g_sdkState->script("package.path = package.path .. ';' .. '" + g_sdkPath + "' .. '/src/?.lua'");
    g_sdkState->script_file(g_sdkPath + std::string("/src/cstorage.lua"));

    sol::table cstorage = (*g_sdkState)["cstorage"];
    cstorage["verbose"] = true;
    cstorage["load"](cstorage);

{%for _, interface  in pairs(slave_ifaces) do%}
    {
        sol::table ifaceMethods = g_sdkState->create_table_with(
        {%for i = 1, #interface.functions do%}
            {*i*}, "{*interface.functions[i].name*}"{%if i ~= #interface.functions then%},{%end%}
        {%end%}
        );
        sol::table manifest = g_sdkState->create_table_with(
            "name", "interface_{*interface.name*}",
            "type", "system",
            "methods", ifaceMethods,
            "scheme", "outstate"
        );
        cstorage["registrate_component"](cstorage, manifest);
    }
{%end%}

{%if #slave_ifaces > 0 then%}
    CreateNewState()->script("component:load('tcp_connector_slave', '127.0.0.1', 9898, 'json_protocol', 'plain_factory')");
{%end%}
}

void Uninitialize()
{
    {
        std::lock_guard<std::recursive_mutex> lock(g_stateLock);
        g_sdkState->script("require 'effil'.G.shutdown = true");
    }
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
        target      = target,
        module_name = props.module_name,
        module_path = props.module_path,
        structs     = exports.structures,
        master_ifaces = exports.masters,
        slave_ifaces  = exports.slaves
    }
    local head_body = generate(header_template, config)
    local src_body = generate(source_template, config)

    write_to_file(props.module_name .. ".cpp", src_body)
    write_to_file(props.module_name .. ".hpp", head_body)
end