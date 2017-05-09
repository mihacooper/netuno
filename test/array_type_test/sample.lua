
--[[
    Type declaration
]]
array_t    = new_type(
    function(self, value)
        if type(value) ~= "table" then
            error( ("Invalid type '%s' of array_t argument, 'table' expected"):format(type(value)))
        end
        local data = {}
        for k, v in ipairs(value) do
            if type(v) ~= "number" then
                error(("Invalid type '%s' of array element #%s, 'number' expected"):format(type(value), k))
            end
            table.insert(data, v)
        end
        return data
    end
)

array_t:specialize_type(
    {
        props = {
            includes = { [["array_decl.hpp"]] };
            name = "std::vector<int>";
            to_lua = "array_t::ArrayToLuaObject";
            from_lua = "array_t::ArrayFromLuaObject";
        }
    }
)

exports.types = { array_t }

--[[
    Interface declaration
]]

class "ArrayTransmitter"
{
    func "Send": none_t(array_t "data");
    func "Receive": array_t(int_t "id");
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
    exports.masters = { ArrayTransmitter }
elseif target == "server" then
    exports.slaves = { ArrayTransmitter }
end
