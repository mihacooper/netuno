#!/usr/bin/lua

require "os"
package.path = package.path .. ";" .. os.getenv("LUA_RPC_SDK") .. "/?.lua"
require "string"
require "helpers"

HELP =
"./main.lua [module] [interface] [language] [type] \
    module     - the name of module insluded the interface \
    interface  - the name of interface which should be generated \
    language   - the destination language \
    type       - dst or src source file \
"

local moduleName    = arg[1]
local interfaceName = arg[2]
local outputLang    = arg[3]
local returnType    = arg[4]

if moduleName == nil or outputLang == nil or io.open(moduleName .. ".lua", "r") == nil then
    print(HELP)
    os.exit(0)
end

language = require(outputLang)

require "dsl"
function LoadTargetModule(modName, intName)
    table.copy(_G, language.types)
    require(modName)
    table.exclude(_G, language.types)
    return _G[intName]
end

--[[
    Implementation body
--]]

local interface = LoadTargetModule(moduleName, interfaceName)

language.generator:SetInterfaceName(interfaceName)
for _, func in pairs(interface)
do
    language.generator:AddFunction(func)
end

language.generator:GenerateFiles(moduleName)
