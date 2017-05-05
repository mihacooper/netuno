local json = require "json"

--[[
    Decoder
]]

http_protocol_decode = {}

function http_protocol_decode:set_factory(factory)
    self.factory = component:load(factory)
end

function http_protocol_decode:process(data)
    if #data == 0 then
        return "Invalid request: data is nil"
    end
    local raw_str = string.match(data[1], "GET (.+) HTTP")
    if not raw_str then
        return "Invalid request format: " .. data[1]
    end

    local iface_name, method_name, raw_args = raw_str:match("/(.+)/(.+)?(.+)")
    if not iface_name then
        iface_name, method_name = raw_str:match("/(.+)/(.+)")
    end
    if not iface_name and not method_name then
        return "Invalid request format: " .. raw_str
    end

    local args = {}
    if raw_args then
        for val in (raw_args .. "&"):gmatch("([^&]*)&") do
            if val ~= nil and val ~= '' then
                local value = val:match(".+=(.+)")
                if value ~= nil and value ~= '' then
                    if tonumber(value) ~= nil then
                        table.insert(args, tonumber(value))
                    else
                        table.insert(args, value)
                    end
                end
            end
        end
    end

    local status, id = self.factory:new(iface_name)
    if not status then
        log_dbg("Factory return error: %s", id)
        return "Internal error"
    end
    local iface = self.factory:get(id)
    if iface == nil then
        log_dbg("Unable to get iface from factory with ID = %s", id)
        return "Internal error"
    end
    local method = iface[method_name]
    if method == nil then
        return "Invalid method call: " .. method_name
    end
    
    local returns = { method(iface, unpack(args)) }
    self.factory:del(id)

    return [[
HTTP/1.1 200 OK

]] .. table.concat(returns, "\n")
end
