DEBUG = true

if LUA_RPC_SDK == nil then
    LUA_RPC_SDK = os.getenv("LUA_RPC_SDK") or ".."
end


package.path = package.path .. ";" .. LUA_RPC_SDK .. "/?.lua"
package.path = package.path .. ";" .. LUA_RPC_SDK .. "/src/?.lua"
package.path = package.path .. ";" .. LUA_RPC_SDK .. "/externals/?.lua"
package.path = package.path .. ";" .. LUA_RPC_SDK .. "/externals/json/json/?.lua"
package.path = package.path .. ";" .. LUA_RPC_SDK .. "/externals/effil/build/?.lua"
package.path = package.path .. ";" .. LUA_RPC_SDK .. "/externals/luasocket_build/modules/?.lua"
--
package.cpath = package.cpath .. ";" .. LUA_RPC_SDK .. "/?.so"
package.cpath = package.cpath .. ";" .. LUA_RPC_SDK .. "/externals/effil/build/?.so"
package.cpath = package.cpath .. ";" .. LUA_RPC_SDK .. "/externals/luasocket_build/lib/?.so"
--

require 'string'

effil = require "effil"
local json = require "json"
local templates = require "template.lib.resty.template"

if effil.G.system ==  nil then
    effil.G.system = {}
end

if effil.G.system.storage ==  nil then
  effil.G.system.storage = {
      data = { lock = effil.channel() },

      new = function(self)
          self.data.lock:pop()
          local id = #self.data + 1
          self.data[id] = {}
          self.data.lock:push(true)
          return id
      end,

      get = function(self, id)
          return self.data[id]
      end,

      del = function(self, id)
          self.data[id] = nil
      end,
  }
  effil.G.system.storage.data.lock:push(true)
end

if effil.G.system.exchange ==  nil then
    effil.G.system.exchange = {}
end

local function create_unique_share(type, capacity)
    local info = debug.getinfo(3)
    local name = info.source .. ":" .. info.currentline
    if effil.G.system.exchange[name] == nil then
        log_dbg("Create new unique share '%s'(%s)", name, type)
        effil.G.system.exchange[name] = effil[type](capacity)
    else
        log_dbg("Return existent unique share '%s'(%s)", name, type)
    end
    return effil.G.system.exchange[name]
end

share = {
    storage       = effil.G.system.storage,
    place_channel = function(capacity) return create_unique_share('channel', capacity) end,
    place_table   = function() return create_unique_share('table') end,
}

function log_dbg(fmt, ...)
    if DEBUG then
        print(("[%15s] "):format(effil.thread_id()) .. string.format(fmt, ...))
    end
end

function log_err(fmt, ...)
    local msg = string.format(fmt, ...)
    print(msg)
    error(msg)
end

function Expect(cond, msg)
    if not cond then
        Error(msg)
    end
end

function encode(data)
    local ret, jdata = pcall(json.encode, data, true)
    if not ret then
        log_err("Unable to parse data to json:%s\n%s\n", jdata, table.show(data))
    end
    return jdata .. "\n"
end

function decode(jdata)
    local ret, data = pcall(json.decode, jdata)
    if not ret then
        log_err("Unable to parse data to json:%s\n%s\n", tostring(data), jdata)
    end
    return data
end

function table.copy(dst, src)
    for k, v in pairs(src) do
        dst[k] = v
    end
end

function table.rcopy(src)
    if not is_table(src) then
      return src
    end
    local dst = {}
    for k, v in pairs(src) do
        if is_table(v) then
            dst[k] = table.rcopy(v)
        else
            dst[k] = v
        end
    end
    return dst
end

function table.exclude(dst, src)
    for k, v in pairs(src)
    do
        dst[k] = nil
    end
end

function table.iforeach(array, func)
    local res = {}
    for _, v in ipairs(array)
    do
        table.insert(res, func(v))
    end
    return res
end

function write_to_file(filename, data)
    local file = io.open(filename, "w")
    file:write(data)
    file:close()
end

function is_table(val)
    return type(val) == type({}) or (type(val) == "userdata" and tostring(val):sub(1, 12) == "effil::table")
end

function is_string(val)
    return type(val) == type('')
end

function value_in_table(val, cont)
    for _, v in pairs(cont) do
        if v == val then
            return true
        end
    end
    return false
end

function generate(temp, data)
    local render_res = ""
    templates.print = function(res)
        render_res = res
    end
    templates.render(temp, data)
    return render_res
end

function table.show(t, name, indent)
   local cart     -- a container
   local autoref  -- for self references

   --[[ counts the number of elements in a table
   local function tablecount(t)
      local n = 0
      for _, _ in pairs(t) do n = n+1 end
      return n
   end
   ]]
   -- (RiciLake) returns true if the table is empty
   local function isemptytable(t) return next(t) == nil end

   local function basicSerialize (o)
      local so = tostring(o)
      if type(o) == "function" then
         local info = debug.getinfo(o, "S")
         -- info.name is nil because o is not a calling level
         if info.what == "C" then
            return string.format("%q", so .. ", C function")
         else 
            -- the information is defined through lines
            return string.format("%q", so .. ", defined in (" ..
                info.linedefined .. "-" .. info.lastlinedefined ..
                ")" .. info.source)
         end
      elseif type(o) == "number" or type(o) == "boolean" then
         return so
      else
         return string.format("%q", so)
      end
   end

   local function addtocart (value, name, indent, saved, field)
      indent = indent or ""
      saved = saved or {}
      field = field or name

      cart = cart .. indent .. field

      if type(value) ~= "table" then
         cart = cart .. " = " .. basicSerialize(value) .. ";\n"
      else
         if saved[value] then
            cart = cart .. " = {}; -- " .. saved[value] 
                        .. " (self reference)\n"
            autoref = autoref ..  name .. " = " .. saved[value] .. ";\n"
         else
            saved[value] = name
            --if tablecount(value) == 0 then
            if isemptytable(value) then
               cart = cart .. " = {};\n"
            else
               cart = cart .. " = {\n"
               for k, v in pairs(value) do
                  k = basicSerialize(k)
                  local fname = string.format("%s[%s]", name, k)
                  field = string.format("[%s]", k)
                  -- three spaces between levels
                  addtocart(v, fname, indent .. "   ", saved, field)
               end
               cart = cart .. indent .. "};\n"
            end
         end
      end
   end

   name = name or "__unnamed__"
   if type(t) ~= "table" then
      return name .. " = " .. basicSerialize(t)
   end
   cart, autoref = "", ""
   addtocart(t, name, indent)
   return cart .. autoref
end

local function dump_table__(t, funcs)
    if type(t) == "number" or type(t) == "boolean" then
        return tostring(t)
    elseif type(t) == "string" then
        return "'" .. t .. "'"
    elseif type(t) == "function" then
        table.insert(funcs, string.dump(t))
        return ("loadstring(funcs[%s])"):format(#funcs)
    elseif type(t) == "table" then
        local ret = "{"
        for k, v in pairs(t) do
            ret = ret .. "[" .. dump_table__(k, funcs) .. "]=" .. dump_table__(v, funcs) .. ","
        end
        return ret .. "}"
    else
        error("Unable to dump type: " .. type(t))
    end
end

function dump_table(t)
    local funcs = {}
    local dumped = dump_table__(t, funcs)
    return [[
local funcs = {...}
return ]] .. dumped, unpack(funcs)
end
