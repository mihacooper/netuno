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

function encode(tbl)
    return dump_table(tbl) .. "\n"
end

function decode(tbl)
    return loadstring("return " .. tbl)()
end

--[[
    Encoder
]]

function get_raw_encode(connector, host, port)
    local raw_protocol_encode = {
        connector = component:load(connector, host, port)
    }

    function raw_protocol_encode:request_new(iface_name)
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
        return response.msg
    end

    function raw_protocol_encode:request_call(func, iid, ...)
        local data_to_send = { iid = iid, request = "call", method = func.type.name, args = {...} }
        local response = decode(self.connector:send_with_return(encode(data_to_send)))
        if response.result ~= 0 then
            log_err("Connection got error: %s", response.msg)
        end
        return response.msg
    end

    function raw_protocol_encode:request_del(iid)
        self.connector:send_with_return(encode { iid = iid, request = "close" })
    end

    return raw_protocol_encode
end
--[[
    Decoder
]]

function get_raw_decode(factory)
    local raw_protocol_decode = {
        factory = component:load_instate(factory)
    }

    function raw_protocol_decode:process(data)
        local processor = {
            new = function(data)
                local status, id = self.factory:new(data.interface)
                if not status then
                    log_dbg("Factory return error: %s", id)
                    return false, { result = 1, msg = id }
                end
                self.iface = self.factory:get(id)
                if not self.iface then
                    log_dbg("Factory return iface = nil: %s", id)
                    return false, { result = 1, msg = "Unable to get iface instance" }
                end
                return false, { result = 0, msg = id }
            end,
            call = function(data)
                local method = self.iface[data.method]
                if method == nil then
                    return false, { result = 1, msg = "unknown method requested: " .. tostring(data.method)}
                end
                local call_res, call_ret = pcall(method, self.iface, unpack(data.args))
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

    return raw_protocol_decode
end
