struct "SampleStructure"
{
    int_t "field1";
    str_t "field2";
}

default_connector = tcp_connector("127.0.0.1", 9898)
default_protocol  = json_protocol

class "SampleInterface"
{
    func "MyFunction1": SampleStructure(int_t "param1", int_t "param2");
    func "MyFunction2": int_t(SampleStructure "param1", str_t "param2");
    func "MyFunction3": none_t(int_t "param1");
    func "MyFunction4": str_t();
    func "FinishTest": none_t();
    factory = "plain_factory";
}

if target == "client" then
    system.register_target({SampleInterface}, {})
elseif target == "server" then
    system.register_target({}, {SampleInterface})
end
