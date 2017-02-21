require "os"
require "string"
require "helpers"

return function(module_name, language, target)
    local root_dir = os.getenv("LUA_RPC_SDK") or "."
    _G.target = target

    if not value_in_table(target, {'client', 'server'}) then
        return false, "Invalid target: " .. target
    end

    if module_name == nil or io.open(module_name, "r") == nil then
        return false, "Invalid module file: " .. module_name
    end

    require "dsl"
    if language == nil or io.open(root_dir .. "/lang-" .. language .. "/binding.lua", "r") == nil then
        return false, "Invalid language: " .. language
    end

    generator = require("lang-" .. language .. ".binding")

    local ret, err = pcall(dofile, module_name)
    if not ret then
        return false, err
    end
    return true, generator
end