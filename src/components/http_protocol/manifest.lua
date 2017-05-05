module_path = "http_protocol";
submodules  = {};

component {
    name    = "http_protocol_decode";
    type    = "custom";
    scheme  = "instate";
    methods = {"set_factory", "process"};
    fields  = { };
}
