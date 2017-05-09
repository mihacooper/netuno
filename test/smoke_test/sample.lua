
struct "SampleStructure"
{
    int_t "field1";
    string_t "field2";
}

class "SampleInterface"
{
    func "MyFunction1": SampleStructure(int_t "param1", int_t "param2");
    func "MyFunction2": int_t(SampleStructure "param1", string_t "param2");
    func "MyFunction3": none_t(int_t "param1");
    func "MyFunction4": string_t();
    func "MyFunction5": none_t(string_t "msg"):with{
        connector = ({
            client = {
                "json_protocol_encode";
                "udp_connector_master";
                "localhost";
                8989;
            },
            server = {
                "udp_connector_slave";
                "localhost";
                8989;
                "json_protocol_decode";
                "plain_factory";
            }
        })[target]
    };
    func "FinishTest": none_t();

    connector = ({
        client = {
            "json_protocol_encode";
            "tcp_connector_master";
            "localhost";
            9898;
        },
        server = {
            "tcp_connector_slave";
            "localhost";
            9898;
            "json_protocol_decode";
            "plain_factory";
        }
    })[target]
}

if target == "client" then
    exports.masters = { SampleInterface }
elseif target == "server" then
    exports.slaves = { SampleInterface }
end
