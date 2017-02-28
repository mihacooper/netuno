local socket = require "socket"

tcp = {}

function tcp.new_connection(hostname, port)
    local conn = {}
    conn.sock = assert(socket.connect(hostname, port))

    function conn:send_with_return(...)
        self:send(...)
        local line, err = self.sock:receive()
        assert(err)
        return line
    end

    function conn:send(...)
        local msg = ""
        for _, field in ipairs(...) do
            msg = msg .. tostring(field)
        end
        self.sock:send(msg .. "\n")
    end

    function conn:close(...)
        self.sock:close()
        self.sock = nil
    end
    return conn
end

function tcp.new_server(port)
    local conn = {}
    conn.sock = assert(socket.bind("*", port))

    function conn:run(handler)
        local connection = self.sock:accept()
        connection:settimeout(10)
        while 1 do
            local line, err = self.sock:receive()
            assert(err)
            local ret = handler(line)
            if ret then
                self.sock:send(ret .. "\n")
            end
        end
    end
    return conn
end

