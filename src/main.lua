#!/usr/bin/lua

package.path = package.path .. ";" .. os.getenv("LUA_RPC_SDK") .. "/?.lua"

HELP =
"./main.lua [module] [interface] [language] [type] \
    module     - the name of module included the interface \
    interface  - the name of interface which should be generated \
    language   - the destination language \
    type       - client or server source file. \
"

local module_name = arg[1]
local class_Name  = arg[2]
local language    = arg[3]
local target      = arg[4]

local loader = require "loader"
local ret, generator = loader(module_name, class_Name, language, target)
if not ret then
    print(generator) -- it's error message
    print(HELP)
    os.exit(1)
end

local ret, msg = pcall(generator, _G[class_Name], { module_name = module_name })
if not ret then
    print(msg)
    os.exit(1)
end
