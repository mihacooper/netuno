DEBUG = true

package.path = package.path .. ";" .. LUA_RPC_SDK .. "/externals/?.lua"
package.path = package.path .. ";" .. LUA_RPC_SDK .. "/externals/json/json/?.lua"

require 'string'

local json = require "json"
local templates = require "template.lib.resty.template"

function log_dbg(fmt, ...)
    if DEBUG then
        print(string.format(fmt, ...))
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
    for k, v in pairs(src)
    do
        dst[k] = v
    end
end

function table.rcopy(dst, src)
    for k, v in pairs(src) do
        if IsTable(v) then
            dst[k] = {}
            table.rcopy(dst[k], v)
        else
            dst[k] = v
        end
    end
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
    return type(val) == type({})
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

function dump_table(t)
    if type(t) == "number" or type(t) == "bool" then
        return tostring(t)
    elseif type(t) == "string" then
        return "'" .. t .. "'"
    elseif type(t) == "table" then
        local ret = "{"
        for k, v in pairs(t) do
            ret = ret .. "[" .. dump_table(k) .. "]=" .. dump_table(v) .. ","
        end
        return ret .. "}"
    else
        error("Unable to dump type: " .. type(t))
    end
end
