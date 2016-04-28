require "helpers"

local general =
{
    --[[
        Types
    --]]
    types =
    {
        Int     = "int",
        String  = "std::string",
        Double  = "double",
        Float   = "float",
        Short   = "short",
        Char    = "char",
        Void    = "void",
    },

    --[[
        Syntax
    --]]
    generator =
    {
        interfaceName = "__InvalidValue__",
        functions = {},
    }
}

function general.generator:SetInterfaceName(name)
    self.interfaceName = name
end

function general.generator:AddFunction(output, name, input)
    table.insert(self.functions, { funcName = name, output = output, input = input })
end

function general.generator:GenerateFiles(moduleName)
    self:GenerateHeader(moduleName)
    self:GenerateSource(moduleName)
end

local headerTemplate =
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
protected:
    luabridge::lua_State* m_luaState;
};
]]

local sourceTemplate =
[[
#include "{{module}}.h"

using namespace luabridge;

#define CHECK(x, msg) { \
    if(x) { printf("ERROR at %s:%d\n\t%s ", __FILE__, __LINE__, #x); \
        throw std::runtime_error(msg);} }

{{interface}}::{{interface}}()
    : m_luaState(luaL_newstate())
{
    CHECK(luaL_loadfile(m_luaState, "{{module}}.lua"), lua_tostring(m_luaState, -1));
    luaL_openlibs(m_luaState);
    CHECK(lua_pcall(m_luaState, 0, 0, 0), lua_tostring(m_luaState, -1));
}
<|functions|>
{{output}} {{interface}}::{{funcName}}(<|input|>{{paramType}} {{paramName}}<|comma|>, <|comma|><|input|>)
{
    LuaRef interface = getGlobal(m_luaState, "{{interface}}");
    CHECK(!interface.isNil(), "Unable to get Lua interface");
    LuaRef funcObj = interface["{{funcName}}"];
    CHECK(!funcObj.isNil(), "Unable to get Lua function object");
    LuaRef function = funcObj["impl"];
    CHECK(!function.isNil(), "Unable to get Lua function implementation");
    <|doReturn|>return <|doReturn|>function(<|input|>{{paramName}}<|comma|>, <|comma|><|input|>)<|doCast|>.cast<{{output}}>()<|doCast|>;
}
<|functions|>
]]

function CommonPreparation(funcs)
    for _, f in pairs(funcs) do
        -- add separators
        local lastParam
        for _, param in pairs(f.input) do
            lastParam = param
            param.comma = {{}}
        end
        lastParam.comma = {}
        -- add separators
        f.output = f.output or general.types.Void
    end
    return funcs
end

function general.generator:GenerateHeader(moduleName)
    local body = StrRepeat(headerTemplate, { interface = self.interfaceName, functions = CommonPreparation(self.functions)})
    WriteToFile(moduleName .. ".h", body)
end


function general.generator:GenerateSource(moduleName)
    local funcs = CommonPreparation(self.functions)
    for _, func in pairs(funcs) do
        if func.output == general.types.Void then
            func.doReturn = {}
            func.doCast = {}
        else
            func.doReturn = {{}}
            func.doCast = {{}}
        end
    end
    local body = StrRepeat(sourceTemplate, { module = moduleName, interface = self.interfaceName, functions = funcs})
    WriteToFile(moduleName .. ".cpp", body)
end

return general