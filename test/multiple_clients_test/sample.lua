default_connector = tcp_connector("127.0.0.1", 9898)
default_protocol  = json_protocol
default_factory   = plain_factory

class "Incrementer"
{
    func "Increment": none_t(int_t "value");
    func "Result": int_t();
}

if target == "client" then
    system.register_target({Incrementer}, {})
elseif target == "server" then
    system.register_target({}, {Incrementer})
end
