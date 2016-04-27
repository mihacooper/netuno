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

function general.generator:GenerateHeader(moduleName)
    local headBody = ""
    headBody = headBody .. "#include \"LuaBridge.h\"\n\n"
    headBody = headBody .. "extern \"C\"\n{\n"
    headBody = headBody .. "    #include \"lua.h\"\n"
    headBody = headBody .. "    #include \"lauxlib.h\"\n"
    headBody = headBody .. "    #include \"lualib.h\"\n"
    headBody = headBody .. "}\n\n"
    headBody = headBody .. string.format("class %s\n{\npublic:\n", self.interfaceName)
    headBody = headBody .. string.format("    %s();\n", self.interfaceName)
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
    srcBody = srcBody .. string.format("#include \"%s.h\"\n\n", moduleName)
    srcBody = srcBody .. string.format("using namespace luabridge;\n\n", self.interfaceName)
    srcBody = srcBody .. "#define CHECK(x, msg) { \\\n"
    srcBody = srcBody .. "\tif(x) { printf(\"ERROR at %s:%d %s\\nWhat: %s\\n\", __FILE__, __LINE__, #x, msg); \\\n"
    srcBody = srcBody .. "\t\tthrow std::runtime_error(msg);} }\n\n"
    srcBody = srcBody .. string.format("%s::%s()\n", self.interfaceName, self.interfaceName)
    srcBody = srcBody .. string.format(
        "    : m_luaState(luaL_newstate())\n{\n    luaL_loadfile(m_luaState, \"%s.lua\");\
        \n    luaL_openlibs(m_luaState);\n    lua_pcall(m_luaState, 0, 0, 0);\n}\n\n"
    , moduleName);
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