if LUA_RPC_SDK == nil then
    LUA_RPC_SDK = os.getenv("LUA_RPC_SDK") or ".."
end
--
package.path = package.path .. ";" .. LUA_RPC_SDK .. "/?.lua"
package.path = package.path .. ";" .. LUA_RPC_SDK .. "/src/?.lua"
package.path = package.path .. ";" .. LUA_RPC_SDK .. "/externals/effil/build/?.lua"
package.path = package.path .. ";" .. LUA_RPC_SDK .. "/externals/luasocket_build/modules/?.lua"
--
package.cpath = package.cpath .. ";" .. LUA_RPC_SDK .. "/?.so"
package.cpath = package.cpath .. ";" .. LUA_RPC_SDK .. "/externals/effil/build/?.so"
package.cpath = package.cpath .. ";" .. LUA_RPC_SDK .. "/externals/luasocket_build/lib/?.so"
--

require "os"
require "string"
require "helpers"
effil = require "effil"

system = {}

if effil.G.system ==  nil then
    effil.G.system = {}
end

if effil.G.system.storage ==  nil then
  effil.G.system.storage = {
      data = {},
      new = function(self)
          local id = #self.data + 1
          self.data[id] = {}
          return id
      end,
      get = function(self, id)
          return self.data[id]
      end,
      del = function(self, id)
          self.data[id] = false
      end,
  }
end

if effil.G['system']['exchange'] ==  nil then
    effil.G['system']['exchange'] = {}
end

function system.unique_channel(capacity)
    local info = debug.getinfo(2)
    local name = info.source .. ":" .. info.currentline
    if effil.G['system']['exchange'][name] == nil then
        log_dbg("Create new unique channel '" .. name .. "'")
        effil.G['system']['exchange'][name] = effil.channel(capacity)
    else
        log_dbg("Return existent unique channel '" .. name .. "'")
    end
    return effil.G['system']['exchange'][name]
end

return function(module_name, language, target)
    if not value_in_table(target, {'client', 'server'}) then
        return false, "Invalid target: " .. target
    end

    _G.target = target

    if module_name == nil or io.open(module_name, "r") == nil then
        return false, "Invalid module file: " .. module_name
    end

    require "dsl"
    local err, generator = pcall(require,  "lang-" .. language .. ".binding")
    if language == nil or not err then
        return false, "Invalid language: " .. language
    end

    local ret, err = pcall(dofile, module_name)
    if not ret then
        return false, err
    end
    return true, generator
end