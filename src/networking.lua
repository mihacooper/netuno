local socket = require "socket"

tcp_connector = {}
default_connector = tcp_connector

function tcp_connector:new_interface(interface)
    local conn = {}
    conn.sock = assert(socket.connect(interface.hostname, interface.port))

    function conn:send_with_return(...)
        self:send(...)
        local line, err = self.sock:receive("*l")
        assert(err == nil)
        return line
    end

    function conn:send(...)
        local msg = ""
        for _, field in ipairs({...}) do
            msg = msg .. tostring(field)
        end
        self.sock:send(msg .. "\n")
    end

    function conn:close()
        self.sock:close()
        self.sock = nil
    end

    local response = conn:send_with_return(interface.type.name)
    assert(response == "ok", "got: " .. response)
    print("finished")
    return conn
end

function tcp_connector:run_server(port)
    local sock = assert(socket.bind("127.0.0.1", port))
    assert(sock:setoption("reuseaddr", true))
    assert(sock:setoption("linger", { on = false, timeout = 0}))

    local conn = assert(sock:accept())
    conn:settimeout(10)

    local line, err = conn:receive("*l")
    print("received")
    local err, msg = pcall(function()
            assert(err == nil, err)
            local iface_t = _G[line]
            assert(iface_t)
            local iface = iface_t()
            assert(iface)
        end
    )
    if err then
        conn:send("ok\n")
    else
        conn:send("error\n")
        assert(false, msg)
    end

    while 1 do
        local line, err = conn:receive("*l")
        if err == "closed" then
            break
        end
        assert(err == nil, err)
        conn:send("asdasd" .. "\n")
        --local ret = iface(line)
        --if ret then
        --end
    end
end

