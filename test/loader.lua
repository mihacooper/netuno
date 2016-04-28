package.path = package.path .. ";" .. os.getenv("LUA_RPC_SDK") .. "/?.lua"

require 'helpers'
dsl = require "dsl"
cpp = require "cpp"

table.copy(_G, dsl)
table.copy(_G, cpp.types)
require "sample"

