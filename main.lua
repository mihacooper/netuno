#!/usr/bin/lua

require "os"
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

function LoadTargetModule(modName, intName)
    local dsl = require "dsl"
    table.copy(_G, dsl)
    table.copy(_G, language.types)
    require(modName)
    table.exclude(_G, language.types)
    table.exclude(_G, dsl)
    return _G[intName]
end

--[[
    Implementation body
--]]

local interface = LoadTargetModule(moduleName, interfaceName)

language.generator:SetInterfaceName(interfaceName)
for funcName, func in pairs(interface)
do
    language.generator:AddFunction(func.output, funcName, func.input)
end

language.generator:GenerateFiles(moduleName)
