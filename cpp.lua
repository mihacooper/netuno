local general =
{
    --[[
        Common language config
    --]]
    outputFileExt = ".cpp",

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

function general.generator:SetInterfaceName(name)
    self.interfaceName = name
end

function general.generator:AddFunction(output, name, input)
    table.insert(self.functions, { name = name, output = output, input = input })
end

function general.generator:GenerateHeader()
    local result = string.format("class %s\n{\npublic:\n", self.interfaceName)
    for _, func in pairs(self.functions)
    do
        result = result .. string.format("\t%s %s(%s);\n",
            func.output, func.name, table.concat(func.input, ", "))
    end
    result = result .. "};\n"
    return result
end

return general