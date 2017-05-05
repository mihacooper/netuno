
class "HttpInterface"
{
    func "get_info": str_t(str_t "field", int_t "time");
    func "stop": str_t();

    connector = "http_connector";
    factory   = "plain_factory";
    protocol  = "http_protocol";

    host = "localhost";
    port = 9898;
}

exports.slaves = { HttpInterface }
