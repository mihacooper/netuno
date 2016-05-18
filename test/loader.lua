package.path = package.path .. ";" .. os.getenv("LUA_RPC_SDK") .. "/?.lua"

require "helpers"
require "dsl"
require "cpp"
SpecializeType = nil -- only language module can specialize types

require "sample"
SampleInterface = GetInterface("SampleInterface")
for _, func in pairs(SampleInterface) do
    if IsTable(func) then
        SampleInterface[func.funcName] = func.impl
    end
end