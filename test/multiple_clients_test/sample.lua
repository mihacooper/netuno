class "Incrementer"
{
    func "Increment": none_t(int_t "value");
    func "Result": int_t();

    connector = "tcp_connector";
    factory   = "plain_factory";
    protocol  = "json_protocol";

    host = "localhost";
    port = 9898;
}

if target == "client" then
    exports.masters = { Incrementer }
elseif target == "server" then
    exports.slaves  = { Incrementer }
end
