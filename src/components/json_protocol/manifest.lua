module_path = "json_protocol";
submodules  = {};

component {
    name    = "json_protocol_encode";
    type    = "custom";
    scheme  = "instate";
    methods = {"request_new", "request_call", "request_del"};
    fields  = { };
}

component {
    name    = "json_protocol_decode";
    type    = "custom";
    scheme  = "instate";
    methods = {"process"};
    fields  = { };
}
