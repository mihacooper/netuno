#!/usr/bin/lua

package.path = package.path .. ";" .. os.getenv("LUA_RPC_SDK") .. "/?.lua"

HELP =
"./main.lua [module] [interface] [language] [type] \
    module     - the name of module included the interface \
    interface  - the name of interface which should be generated \
    language   - the destination language \
    type       - client or server source file. \
"

local module_path = arg[1]
local language    = arg[2]
local target      = arg[3]

local loader = require "loader"
local ret, generator = loader(module_path, language, target)
if not ret then
    print(generator) -- it's error message
    print(HELP)
    os.exit(1)
end

local module_name = string.gsub(module_path, "(%w-).lua", "%1")
if type(module_name) ~= "string" then
    print("Unable to get module name")
    os.exit(1)
end

local ret, msg = pcall(generator, { module_name = module_name, module_path = module_path })
if not ret then
    print(msg)
    os.exit(1)
end
