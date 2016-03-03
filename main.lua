#!/usr/bin/lua

require "os"
require "string"

HELP = "HELP"

local moduleName = arg[1]
if moduleName == nil or io.open(moduleName .. ".lua", "r") == nil then
    print(HELP)
    os.exit(0)
end

Int     = "int"
String  = "std::string"
Double  = "double"
Float   = "float"
Short   = "short"
Char    = "char"

print("Load module " .. moduleName .. ".cpp")
local interfaces = require(moduleName)

OutputFilename = moduleName .. ".cpp"

output = io.open(OutputFilename, "w")
for interf, val1 in pairs(interfaces) do
    output:write(string.format("class %s\n{\npublic:\n", interf))
    for func, val2 in pairs(val1) do
        output:write(string.format("\t%s %s\(%s\);\n", val2.Output, func, val2.Input[1]))
    end
    output:write("};\n")
end
output:close()