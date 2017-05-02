struct "SampleStructure"
{
    int_t "field1";
    str_t "field2";
}

class "SampleInterface"
{
    func "MyFunction1": SampleStructure(int_t "param1", int_t "param2");
    func "MyFunction2": int_t(SampleStructure "param1", str_t "param2");
    func "MyFunction3": none_t(int_t "param1");
    func "MyFunction4": str_t();
    func "FinishTest": none_t();

    connector = "tcp_connector";
    factory   = "plain_factory";
    protocol  = "json_protocol";
}

if target == "client" then
    exports.masters = { SampleInterface }
elseif target == "server" then
    exports.slaves = { SampleInterface }
end
