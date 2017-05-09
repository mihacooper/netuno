local socket = require "socket"
local effil = require "effil"

--[[
    tcp_connector_master
]]

function get_tcp_master(host, port)
    local tcp_connector_master = {}

    tcp_connector_master.sock = assert(socket.connect(host, port))
    print( ("Client starts connection [%s]"):format(tcp_connector_master.sock:getfd()))

    function tcp_connector_master:send_with_return(data)
        self:send(data)
        log_dbg("TCP connector [%s] waiting for response from server...", self.sock:getfd())
        local line, err = self.sock:receive("*l")
        if err ~= nil then
            error( ("Client connection [%s] has received error: %s"):format(self.sock:getfd(), err))
        end
        log_dbg("TCP connector [%s] got response '%s'", self.sock:getfd(), line)
        return line
    end

    function tcp_connector_master:send(data)
        log_dbg("TCP connector [%s] send data '%s'", self.sock:getfd(), data)
        self.sock:send(data)
    end

    function tcp_connector_master:close()
        self.sock:close()
        self.sock = nil
    end
    return tcp_connector_master
end
--[[
    tcp_connector_slave
]]

function run_tcp_slave(host, port, protocol_name, factory_name)
    log_dbg("Run a 'tcp_connector' server with: %s:%s %s %s", host, port, protocol_name, factory_name)
    local dummy_server = assert(socket.bind(host, port + 1))
    dummy_server:settimeout(0)

    local server = assert(socket.bind(host, port))
    assert(server:setoption("reuseaddr", true))
    assert(server:setoption("linger", { on = false, timeout = 0}))
    server:settimeout(0)

    while not effil.G.shutdown do
        dummy_server:accept() -- to trash
        local new_conn = server:accept()
        if new_conn and new_conn:getfd() > 0 then
            log_dbg("Server 'tcp_connector' got a new connection", new_conn:getfd())
            component:load("tcp_connector_worker", host, port, new_conn:getfd(), protocol_name, factory_name)
            new_conn:setfd(-1)
        end
    end
end

--[[
    tcp_connector_worker
]]

function run_tcp_worker(host, port, socket_fd, protocol_name, factory_name)
    log_dbg("Server thread of 'tcp_connector' has started with [%s] on %s:%s (%s, %s)", socket_fd, host, port, protocol_name, factory_name)
    local protocol = component:load(protocol_name, factory_name)

    local exit_thread = false
    local connection = assert(socket.connect(host, port + 1))
    connection:close()
    connection:setfd(socket_fd)
    while not effil.G.shutdown and not exit_thread do
        log_dbg("Server thread [%s] waiting for request...", socket_fd)
        local data, status = connection:receive("*l")
        log_dbg("Server thread [%s] receive: %s, err: %s", socket_fd, data, status or "nil")
        if status == "closed" then
            log_dbg("Server thread [%s] socket closed", socket_fd)
            break
        else
            exit_thread, data_to_send = protocol:process(data)
            log_dbg("Server thread [%s] sent: %s", socket_fd, data_to_send)
            connection:send(data_to_send)
        end
    end
    log_dbg("Shutdown server thread [%s]", socket_fd)
    connection:close()
end
