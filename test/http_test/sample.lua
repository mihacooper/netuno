
class "HttpInterface"
{
    func "get_info": string_t(string_t "field", int_t "time");
    func "stop": string_t();

    connector = {
        "http_connector";
        "localhost";
        9898;
    }
}

exports.slaves = { HttpInterface }
