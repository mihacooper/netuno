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

local CppConfig =
{
    Header =
[[
class %InterfaceName%
{
    %InterfaceName%
    %FuncOutputType% %FuncName%(%FuncListOfInputTypes%);
};
]]
}

function general.generator:SetInterfaceName(name)
    self.interfaceName = name
end

function general.generator:AddFunction(output, name, input)
    table.insert(self.functions, { name = name, output = output, input = input })
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
    <|functions|>{{output}} {{funcName}}(<|parameters|>{{type}} {{name}}{{c}}<|parameters|>);
    <|functions|>

protected:
    luabridge::lua_State* m_luaState;
};
]]

print(
    StrRepeat(headerTemplate, { interface = "MyInterface", functions = 
            {
                { output = 'void', funcName = "Function1", parameters = { {type = 'int', name = 'param1', c = ', '}, {type = 'std::string', name = 'param2', c = ''}}},
                { output = 'int', funcName = "Function2", parameters = { {type = 'float', name = 'param1', c = ', '}, {type = 'double', name = 'param2', c = ''}}},
            }
        }
    )
)

function general.generator:GenerateHeader(moduleName)
    local headBody = StrReplace(
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
]]
        , { interface = self.interfaceName}
    )
    for _, func in pairs(self.functions)
    do
        headBody = headBody .. string.format("    %s %s(%s);\n",
            func.output or "void", func.name, table.concat(func.input, ", "))
    end
    headBody = headBody .. "\n"
    headBody = headBody .. "protected:\n    luabridge::lua_State* m_luaState;\n"
    headBody = headBody .. "};\n"
    WriteToFile(moduleName .. ".h", headBody)
end


function general.generator:GenerateSource(moduleName)
    local srcBody = ""
    srcBody = srcBody .. StrReplace(
    [[
#include "{{module}}.h"

using namespace luabridge;

#define CHECK(x, msg) { \\
    if(x) { printf(\"ERROR at %s:%d %s \\nWhat: %s\\n", __FILE__, __LINE__, #x, msg); \\
        throw std::runtime_error(msg);} }

{{interface}}::{{interface}}()
    : m_luaState(luaL_newstate())
{
    luaL_loadfile(m_luaState, "{{module}}.lua");
    luaL_openlibs(m_luaState);
    lua_pcall(m_luaState, 0, 0, 0);
}
    ]],
        { module = moduleName, interface = self.interfaceName}
    )
    for _, func in pairs(self.functions)
    do
        local paramNum = 0
        srcBody = srcBody .. string.format("%s %s::%s(%s)\n", func.output or "void", self.interfaceName, func.name,
                table.concat(
                    table.iforeach(func.input, function(v)
                            local r = v .. " param" .. paramNum
                            paramNum = paramNum + 1
                            return r 
                        end
                    ),", "
                )
        )
        srcBody = srcBody .. "{\n"
        srcBody = srcBody .. "    "
        if func.output ~= nil then
            srcBody = srcBody .. "return "
        end
        local paramNum = 0
        srcBody = srcBody .. string.format("getGlobal(m_luaState, \"%s\")[\"%s\"][\"impl\"](%s)",
                self.interfaceName, func.name,
                table.concat(
                    table.iforeach(func.input, function(v)
                            local r = "param" .. paramNum
                            paramNum = paramNum + 1
                            return r 
                        end
                    ),", "
                )
        )
        if func.output ~= nil then
            srcBody = srcBody .. string.format(".cast<%s>()", func.output)
        end
        srcBody = srcBody .. ";\n"
        srcBody = srcBody .. "}\n\n"
    end
    WriteToFile(moduleName .. ".cpp", srcBody)
end

return general