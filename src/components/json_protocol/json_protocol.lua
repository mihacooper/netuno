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
    log_dbg("Start request for new interface '%s'", iface_name)
    local response = self.connector:send_with_return(encode({ request = "new", interface = iface_name}))
    local response = decode(response)
    if response.result ~= 0 then
        log_err("Attept to create a new connection has failed, error: %s", response.msg)
    end
    if type(response.msg) ~= "string" or response.msg == "" then
        log_err("New connection has received invalid IID = %s", response.msg)
    end
    self.iid = response.msg
end

function json_protocol_encode:request_call(func, ...)
    local data_to_send = { iid = self.iid, request = "call", method = func.type.name, args = {...} }
    local response = decode(self.connector:send_with_return(encode(data_to_send)))
    if response.result ~= 0 then
        log_err("Connection got error: %s", response.msg)
    end
    return response.msg
end

function json_protocol_encode:request_del()
    self.connector:send_with_return(encode { iid = self.iid, request = "close" })
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
                return false, { result = 1, msg = id }
            end
            return false, { result = 0, msg = id }
        end,
        call = function(data)
            local iface = self.factory:get(data.iid)
            if iface == nil then
                return false, { result = 1, msg = "invalid IID = " .. tostring(data.iid)}
            end
            local method = iface[data.method]
            if method == nil then
                return false, { result = 1, msg = "unknown method requested: " .. tostring(data.method)}
            end
            local call_res, call_ret = pcall(method, iface, unpack(data.args))
            if not call_res then
                return true, { result = 1, msg = ("Exception occurs during method (%s) call: %s"):format(method, call_ret) }
            end
            return false, { result = 0, msg = call_ret }
        end,
        close = function(data)
            self.factory:del(data.iid)
            return true, { result = 0 }
        end
    }
    local decoded_data = decode(data)
    local request = decoded_data["request"]
    local data_to_send = ""
    if request == nil or processor[request] == nil then
        return false, encode({ result = 1, msg = "invalid request"})
    else
        local call_res, do_exit, response = pcall(processor[request], decoded_data)
        if not response then
            return encode({ result = 1, msg = do_exit })
        end
        return do_exit, encode(response)
    end
end
