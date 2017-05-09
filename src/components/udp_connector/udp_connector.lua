local socket = require "socket"
local effil = require "effil"

--[[
    udp_connector_master
]]

function get_udp_master(host, port)
    local sock = assert(socket.udp())
    sock:setpeername(host, port)
    sock:settimeout(0)
    log_dbg( ("Client starts connection [%s]"):format(sock:getfd()))

    local udp_connector_master = { sock = sock }

    function udp_connector_master:send(data)
        log_dbg("UDP connector [%s] send data '%s'", self.sock:getfd(), data)
        self.sock:send(data)
    end

    function udp_connector_master:close()
        self.sock:close()
        self.sock = nil
    end
    return udp_connector_master
end

--[[
    udp_connector_slave
]]

function run_udp_slave(host, port, protocol_name, factory_name)
    log_dbg("Run a 'udp_connector' server with: %s:%s %s %s", host, port, protocol_name, factory_name)
    local protocol = component:load(protocol_name, factory_name)

    local udp = socket.udp()
    udp:setsockname("*", port)
    udp:settimeout(0)

    while not effil.G.shutdown do
        local data, ip, port = udp:receivefrom()
        if data then
            log_dbg("Server 'udp_connector' received a data from %s:%s:\n\t%s", ip, port, data)
            protocol:process(data)
            --log_dbg("Server 'udp_connector' sent: %s", data_to_send)
            --udp:sendto(data_to_send, ip, port)
        end
    end
    log_dbg("Shutdown 'udp_connector' server thread")
    udp:close()
end
