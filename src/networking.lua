require "helpers"
local socket = require "socket"
local effil = require "libeffil"
json = require "json"

tcp_connector = {}
default_connector = tcp_connector

function encode(data)
    local ret, jdata = pcall(json.encode, data, true)
    assert(ret, "Unable to parse data to json:\n" .. jdata .. "\n" .. table.show(data))
    return jdata .. "\n"
end

function decode(jdata)
    local ret, data = pcall(json.decode, jdata)
    assert(ret, "Unable to parse data from json, err: " .. tostring(data))
    return data
end

function tcp_connector:new_interface(interface)
    local conn = {}
    conn.sock = assert(socket.connect(interface.hostname, interface.port))

    function conn:send_with_return(data)
        self:send(data)
        local line, err = self.sock:receive("*l")
        assert(err == nil)
        local ret = decode(line)
        return ret--next(ret) == nil and nil or ret
    end

    function conn:send(data)
        local msg = encode(data)
        self.sock:send(msg)
    end

    function conn:close()
        self.sock:close()
        self.sock = nil
    end

    local response = conn:send_with_return({interface.type.name})
    assert(response.answer == "ok", "got: " .. response.answer)
    return conn
end

function tcp_connector:run_server(port)
    local sock = assert(socket.bind("127.0.0.1", port))
    assert(sock:setoption("reuseaddr", true))
    assert(sock:setoption("linger", { on = false, timeout = 0}))

    local conn = assert(sock:accept())
    conn:settimeout(10)

    local line, err = conn:receive("*l")
    local err, iface = pcall(function()
            assert(err == nil, err)
            local request = decode(line)
            local iface_t = _G[request[1]]
            assert(iface_t)
            local iface = iface_t:new()
            assert(iface)
            return iface
        end
    )
    if err then
        conn:send(encode({ answer = "ok"}))
    else
        conn:send(encode({ answer = "error"}))
        assert(false, iface)
    end

    while 1 do
        local line, err = conn:receive("*l")
        if err == "closed" then
            break
        end
        assert(err == nil, err)
        local request = decode(line)
        local ret = iface[request.func_name](unpack(request.args))
        conn:send(encode(ret))
    end
end
