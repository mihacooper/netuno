require "helpers"
local socket = require "socket.socket"
local effil = require "effil"
local json = require "json"

-- Global variables
connectors = {}
interface_instances = {}

function connectors.initialize()
    for _, conn in ipairs(connectors) do
        conn:initialize_slave()
    end
end

function connectors.loop()
    for _, conn in ipairs(connectors) do
        conn:loop()
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

local function encode(data)
    local ret, jdata = pcall(json.encode, data, true)
    assert(ret, "Unable to parse data to json:\n" .. jdata .. "\n" .. table.show(data))
    return jdata .. "\n"
end

local function decode(jdata)
    local ret, data = pcall(json.decode, jdata)
    assert(ret, "Unable to parse data from json, err: " .. tostring(data))
    return data
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
            assert(err == nil)
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
            assert(response.status == "ok", "got: " .. response.status)
            assert(type(response.iid) == "string" and response.iid ~= "", "got invalid IID = " .. response.iid)
            interface.iid = response.iid
        end
        conn.iid = interface.iid
        return conn
    end

    function connector:handle_message(data)
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
        return processor[data["request"]](data)
    end

    function connector:initialize_slave()
        local server = assert(socket.bind(self.host, self.port))
        assert(server:setoption("reuseaddr", true))
        assert(server:setoption("linger", { on = false, timeout = 0}))
        server:settimeout(0)
        self.server = server
        self.queue = {}
    end

    function connector:loop(port)
         -- 1. Handle new conncetions 
        local new_conn = self.server:accept()
        if new_conn then
            table.insert(self.queue, new_conn)
        end
         -- 2. Handle existent conn's
        local to_recv, to_send = socket.select(self.queue, self.queue, 0)
        for sock_n, sock in ipairs(to_recv) do
            local data, status = sock:receive("*l")
            if status == "closed" then
                table.remove(self.queue, sock_n)
                sock:close()
            else
                local response = self:handle_message(decode(data))
                sock:send(encode(response))
            end
        end
    end
    return connector
end
