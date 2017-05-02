module_path = "json_protocol";
submodules  = {};

component {
    name    = "json_protocol_encode";
    type    = "custom";
    scheme  = "instate";
    methods = {"request_new", "request_call", "request_del", "set_connector"};
    fields  = { };
}

component {
    name    = "json_protocol_decode";
    type    = "custom";
    scheme  = "instate";
    methods = {"set_factory", "process"};
    fields  = { };
}
