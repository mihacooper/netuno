require "helpers"
local socket = require "socket"

local interface_instances = {}

iface_factory = {}

function iface_factory:new(iface_name)
    iface_t = _G[iface_name]
    if iface_t == nil then
        return false, "Unknown interface type: " .. iface_name
    end
    local status, iface = pcall(iface_t.new, iface_t)
    if not status then
        return false, iface
    end
    local id = self:get_id(iface)
    interface_instances[id] = iface
    return true, id
end

function iface_factory:get(id)
    return interface_instances[id]
end

function iface_factory:del(id)
    interface_instances[id] = nil
end

function iface_factory:get_id(iface)
    local str = tostring(iface.server)
    local _, id_pos = string.find(str, "0x")
    return string.sub(str, id_pos + 1)
end

json_protocol = {}

function json_protocol.new_master(connector)
    assert(connector ~= nil)
    local protocol = { connector = connector }

    function protocol:request_new(iface_name)
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

    function protocol:request_call(func, ...)
        local data_to_send = { iid = self.iid, request = "call", method = func.type.name, args = {...} }
        if func.type.output == none_t then
            self.connector:send(encode(data_to_send))
        else
            return decode(self.connector:send_with_return(encode(data_to_send)))
        end
    end

    function protocol:request_del()
        self.connector:send(encode { iid = self.iid, request = "close" })
    end

    return protocol
end

function json_protocol.new_slave(factory)
    local protocol = { factory = factory }

    function protocol:process(data)
        local processor = {
            new = function(data)
                local status, id = self.factory:new(data.interface)
                if not status then
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
                return false, method(unpack(data.args))
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
            if response == nil then
                return do_exit
            else
                return do_exit, encode(response)
            end
        end
    end

    return protocol
end

function tcp_connector(host, port)
    local connector = { port = port, host = host }

    function connector:create()
        local conn = {}
        conn.sock = assert(socket.connect(self.host, self.port))
        log_dbg("Client starts connection [%s]", conn.sock:getfd())

        function conn:send_with_return(data)
            self:send(data)
            local line, err = self.sock:receive("*l")
            if err ~= nil then
                log_err("Client connection [%s] has received error: %s", conn.sock:getfd(), err)
            end
            return line
        end

        function conn:send(data)
            self.sock:send(data)
        end

        function conn:close()
            self.sock:close()
            self.sock = nil
        end
        return conn
    end

    function connector:set_protocol(protocol)
        self.protocol = protocol.new_slave(iface_factory)
    end

    function connector:run_server_thread(socket_fd)
        log_dbg("Server thread of 'tcp_connector' has started with %s", socket_fd)
        local exit_thread = false
        local connection = assert(socket.connect(self.host, self.port + 1))
        connection:close()
        connection:setfd(socket_fd)
        while not effil.G.shutdown and not exit_thread do
            local data, status = connection:receive("*l")
            log_dbg("Server thread [%s] receive: %s, err: %s", socket_fd, data, status or "nil")
            if status == "closed" then
                connection:close()
                break
            else
                exit_thread, data_to_send = self.protocol:process(data)
                if data_to_send ~= nil then
                    log_dbg("Server thread [%s] sent: %s", socket_fd, data_to_send)
                    connection:send(data_to_send)
                end
            end
        end
        log_dbg("Shutdown server thread [%s]", socket_fd)
        connection:close()
    end

    function connector:listen()
        log_dbg("Run a 'tcp_connector' server")
        local dummy_server = assert(socket.bind(self.host, self.port + 1))
        dummy_server:settimeout(0)

        local server = assert(socket.bind(self.host, self.port))
        assert(server:setoption("reuseaddr", true))
        assert(server:setoption("linger", { on = false, timeout = 0}))
        server:settimeout(0)
        effil.G['system']['tcp_connector'] = effil.channel()

        while not effil.G.shutdown do
            dummy_server:accept() -- to trash
            local new_conn = server:accept()
            if new_conn and new_conn:getfd() > 0 then
                log_dbg("Server 'tcp_connector' got a new connection", new_conn:getfd())
                effil.G['system']['tcp_connector']:push(self.host, self.port, new_conn:getfd())

                run_new_state(function()
                        local host, port, fd = effil.G['system']['tcp_connector']:pop()
                        local conn = tcp_connector(host, port)
                        conn:set_protocol(default_protocol)
                        conn:run_server_thread(fd)
                    end
                )
                new_conn:setfd(-1)
            end
        end
    end

    return connector
end
