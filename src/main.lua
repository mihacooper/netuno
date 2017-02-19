#!/usr/bin/lua

require "os"
package.path = package.path .. ";" .. os.getenv("LUA_RPC_SDK") .. "/?.lua"
require "string"
require "helpers"

HELP =
"./main.lua [module] [interface] [language] [type] \
    module     - the name of module included the interface \
    interface  - the name of interface which should be generated \
    language   - the destination language \
    type       - client or server source file. \
"

local moduleName    = arg[1]
local interfaceName = arg[2]
local outputLang    = arg[3]
local returnType    = arg[4] or 'both'

if not In(returnType, {'client', 'server', 'both'}) then
    print("Invalid 'type' = " .. returnType)
    print(HELP)
    os.exit(0)
end

if not In(outputLang, {'cpp'}) then
    print("Invalid 'language' = " .. returnType)
    print(HELP)
    os.exit(0)
end

if moduleName == nil or io.open(moduleName, "r") == nil then
    print("Invalid module file")
    print(HELP)
    os.exit(0)
end

require "dsl"
generator = require("lang-" .. outputLang .. ".binding")

dofile(moduleName)
local interface = GetInterface(interfaceName)
generator:SetInterfaceName(interfaceName)

for _, func in pairs(interface) do
    generator:AddFunction(func)
end

local structures = GetStructures()
for name, str in pairs(structures) do
    generator:AddStructure(str)
end

if In(returnType, {'client', both}) then
    generator:GenerateClientFiles(moduleName)
elseif In(returnType, {'server', both}) then
    generator:GenerateServerFiles(moduleName)
else
    print("Output type is not selected")
end
