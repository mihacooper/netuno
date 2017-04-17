require "helpers"
local socket = require "socket"

-- Global variables
connectors = {}
interface_instances = {}

function connectors.initialize()
    for _, conn in ipairs(connectors) do
        conn:initialize_slave()
    end
end

function connectors.add(conn)
    local is_new = true
    for _, val in ipairs(connectors) do
        if val == conn then
            is_new = false
            break
        end
    end
    if is_new then
        table.insert(connectors, conn)
    end
end

function connectors.size()
    return #connectors
end

function get_interface_id(interface)
    local str = tostring(interface.server)
    local _, id_pos = string.find(str, "0x")
    return string.sub(str, id_pos + 1)
end

function tcp_connector(host, port)
    local connector = { port = port, host = host }

    function connector:initialize_master(interface)
        local conn = {}
        conn.sock = assert(socket.connect(self.host, self.port))

        function conn:send_with_return(data)
            self:send(data)
            local line, err = self.sock:receive("*l")
            if err ~= nil then
                log_err("Connection [%s] has received error: %s", self.iid, err)
            end
            local ret = decode(line)
            return ret--next(ret) == nil and nil or ret
        end

        function conn:send(data)
            data.iid = self.iid
            local msg = encode(data)
            self.sock:send(msg)
        end

        function conn:close()
            self.sock:close()
            self.sock = nil
        end

        if interface.iid == nil then
            local response = conn:send_with_return({ request = "new", interface = interface.type.name})
            if response.status ~= "ok" then
                log_err("Attept to create a new connection has failed, error: %s", response.status)
            end
            if type(response.iid) ~= "string" or response.iid == "" then
                log_err("New connection has received invalid IID = %s", response.iid)
            end
            interface.iid = response.iid
        end
        conn.iid = interface.iid
        return conn
    end

    function connector:run_server_thread(socket_fd)
        local processor = {
            new = function(data)
                local iface_t = _G[data.interface]
                if iface_t == nil then return { status = "error"} end

                local iface = iface_t:new()
                if iface_t == nil then return { status = "error"} end
                local id = get_interface_id(iface)
                interface_instances[id] = iface
                return { status = "ok", iid = id}
            end,
            call = function(data)
                local iface = interface_instances[data.iid]
                if iface == nil then return { status = "error", msg = "invalid IID = " .. tostring(data.iid)} end
                local method = iface[data.method]
                if method == nil then return { status = "error", msg = "unknown method request: " .. tostring(data.method)} end
                return method(unpack(data.args))
            end
        }
        log_dbg("Server thread of 'tcp_connector' has started with %s", socket_fd)
        local connection = assert(socket.connect(self.host, self.port + 1))
        connection:close()
        connection:setfd(socket_fd)
        while not effil.G.shutdown do
            local data, status = connection:receive("*l")
            log_dbg("Server thread [%s] receive: %s, err: %s", socket_fd, data, status or "nil")
            if status == "closed" then
                connection:close()
                break
            else
                local decoded_data = decode(data)
                local request = decoded_data["request"]
                local data_to_send = ""
                if request == nil or processor[request] == nil then
                    data_to_send = encode({status = "error: invalid request"})
                else
                    local response = processor[request](decoded_data)
                    data_to_send = encode(response)
                end
                log_dbg("Server thread [%s] sent: %s", socket_fd, data_to_send)
                connection:send(data_to_send)
            end
        end
    end

    function connector:run_slave()
        log_dbg("Run a 'tcp_connector' server")
        local dummy_server = assert(socket.bind(self.host, self.port + 1))
        local server = assert(socket.bind(self.host, self.port))
        assert(server:setoption("reuseaddr", true))
        assert(server:setoption("linger", { on = false, timeout = 0}))
        server:settimeout(0)
        effil.G['system']['tcp_connector'] = effil.channel()

        while not effil.G.shutdown do
            local new_conn = server:accept()
            if new_conn then
                log_dbg("Server 'tcp_connector' got a new connection", new_conn:getfd())
                effil.G['system']['tcp_connector']:push(self.host, self.port, new_conn:getfd())

                run_new_state(function()
                        local host, port, fd = effil.G['system']['tcp_connector']:pop()
                        tcp_connector(host, port):run_server_thread(fd)
                    end
                )
                new_conn:setfd(0)
            end
        end
    end

    return connector
end
