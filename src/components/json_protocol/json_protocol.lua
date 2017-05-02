local json = require "json"

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

--[[
    Encoder
]]

json_protocol_encode = {}

function json_protocol_encode:set_connector(connector)
    self.connector = component:load(connector)
    self.connector:set_connection_string("127.0.0.1", 9898)
end

function json_protocol_encode:request_new(iface_name)
    assert(type(iface_name) == "string")
    local response = self.connector:send_with_return(encode({ request = "new", interface = iface_name}))
    local response = decode(response)
    if response.status ~= "ok" then
        log_err("Attept to create a new connection has failed, error: %s", response.status)
    end
    if type(response.iid) ~= "string" or response.iid == "" then
        log_err("New connection has received invalid IID = %s", response.iid)
    end
    self.iid = response.iid
end

function json_protocol_encode:request_call(func, ...)
    local data_to_send = { iid = self.iid, request = "call", method = func.type.name, args = {...} }
    return decode(self.connector:send_with_return(encode(data_to_send)))
end

function json_protocol_encode:request_del()
    self.connector:send(encode { iid = self.iid, request = "close" })
end

--[[
    Decoder
]]

json_protocol_decode = {}

function json_protocol_decode:set_factory(factory)
    self.factory = component:load(factory)
end

function json_protocol_decode:process(data)
    local processor = {
        new = function(data)
            local status, id = self.factory:new(data.interface)
            if not status then
                log_dbg("Factory return error: %s", id)
                return false, { status = id }
            end
            return false, { status = "ok", iid = id }
        end,
        call = function(data)
            local iface = self.factory:get(data.iid)
            if iface == nil then
                return false, { status = "error", msg = "invalid IID = " .. tostring(data.iid)}
            end
            local method = iface[data.method]
            if method == nil then
                return false, { status = "error", msg = "unknown method request: " .. tostring(data.method)}
            end
            return false, method(iface, unpack(data.args))
        end,
        close = function(data)
            self.factory:del(data.iid)
            return true
        end
    }
    local decoded_data = decode(data)
    local request = decoded_data["request"]
    local data_to_send = ""
    if request == nil or processor[request] == nil then
        return false, encode({status = "error: invalid request"})
    else
        local do_exit, response = processor[request](decoded_data)
        return do_exit, encode(response)
    end
end
