class "RRInterface"
{
    func "Send": string_t(string_t "msg");

    connector = ({
        client = {
            "raw_protocol_encode";
            "tcp_connector_master";
            "localhost";
            9898;
        },
        server = {
            "tcp_connector_slave";
            "localhost";
            9898;
            "raw_protocol_decode";
            "singleton_factory";
        }
    })[target]
}

if target == "client" then
    exports.masters = { RRInterface }
elseif target == "server" then
    exports.slaves = { RRInterface }
end
