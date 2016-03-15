return
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
    syntax = 
    {
        interface = 
        {
            prefix = function(name)
                return string.format("class %s\n{\npublic:\n", name)
            end,
            postfix = function()
                return "};\n"
            end,
        },
        func = 
        {
            declare = function(output, name, input)
                return string.format("\t%s %s(%s);\n", output, name, table.concat(input, ", "))
            end,
        },
    },
}
