local socket = require "socket"
local effil = require "effil"

--[[
    http_connector_slave
]]

http_connector_slave = {}

function http_connector_slave:run(host, port, protocol_name, factory_name)
    log_dbg("Run a 'http_connector' server with: %s:%s %s %s", host, port, protocol_name, factory_name)
    local dummy_server = assert(socket.bind(host, port + 1))
    dummy_server:settimeout(0)

    local server = assert(socket.bind(host, port))
    assert(server:setoption("reuseaddr", true))
    assert(server:setoption("linger", { on = false, timeout = 0}))
    server:settimeout(5)

    while not effil.G.shutdown do
        dummy_server:accept() -- to trash
        local new_conn = server:accept()
        if new_conn and new_conn:getfd() > 0 then
            log_dbg("Server 'http_connector' got a new connection", new_conn:getfd())
            component:load("http_connector_worker", host, port, new_conn:getfd(), protocol_name, factory_name)
            new_conn:setfd(-1)
        end
    end
end

--[[
    http_connector_worker
]]

http_connector_worker = {}

function http_connector_worker:run(host, port, socket_fd, protocol_name, factory_name)
    log_dbg("Server thread of 'http_connector' has started with [%s] on %s:%s (%s, %s)", socket_fd, host, port, protocol_name, factory_name)
    local protocol = component:load(protocol_name .. "_decode")
    protocol:set_factory(factory_name)

    local exit_thread = false
    local connection = assert(socket.connect(host, port + 1))
    connection:close()
    connection:setfd(socket_fd)
    connection:settimeout(2)

    log_dbg("Server thread [%s] waiting for request...", socket_fd)

    local first_batch = connection:receive("*l")
    if first_batch ~= nil then
        local data = { first_batch }
        repeat
            local batch = connection:receive("*l")
            if batch ~= nil then
                table.insert(data, batch)
            end
        until batch == nil

        if #data == 0 then
            log_dbg("Server thread [%s] receive not data", socket_fd)
        else
            local data_to_print = tostring(data[1])
            for i = 2, #data do
                data_to_print = data_to_print .. "\n" .. data[i]
            end

            log_dbg("Server thread [%s] receive: %s, err: %s", socket_fd, data_to_print, status or "nil")
            local data_to_send = protocol:process(data)
            
            log_dbg("Server thread [%s] sent: %s", socket_fd, data_to_send)
            connection:send(data_to_send)
        end
    end
    connection:close()

    log_dbg("Shutdown server thread [%s]", socket_fd)
end
