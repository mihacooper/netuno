local socket = require "socket"
local effil = require "effil"

function process_request(data)
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

    local iface = component:load_instate("system::interface::" .. iface_name)
    if iface == nil then
        log_dbg("Unable to load interface %s", iface_name)
        return "Internal error"
    end
    local method = iface[method_name]
    if method == nil then
        return "Invalid method call: " .. method_name
    end
    
    local returns = { method(iface, unpack(args)) }
    return [[
HTTP/1.1 200 OK

]] .. table.concat(returns, "\n")
end



--[[
    http_connector_slave
]]

function run_slave(host, port)
    log_dbg("Run a 'http_connector' server with: %s:%s", host, port)
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
            component:load("http_connector::worker", host, port, new_conn:getfd())
            new_conn:setfd(-1)
        end
    end
end

--[[
    http_connector_worker
]]

function run_worker(host, port, socket_fd)
    log_dbg("Server thread of 'http_connector' has started with [%s] on %s:%s", socket_fd, host, port)

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
            local data_to_send = process_request(data)
            
            log_dbg("Server thread [%s] sent:\n%s", socket_fd, data_to_send)
            connection:send(data_to_send)
        end
    end
    connection:close()

    log_dbg("Shutdown server thread [%s]", socket_fd)
end
