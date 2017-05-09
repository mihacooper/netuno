module_path = "tcp_connector";
submodules  = {};

component {
    name    = "tcp_connector_master";
    type    = "custom";
    scheme  = "instate";
    entry   = "get_tcp_master";
    methods = {"request_new", "request_call", "request_del"};
}

component {
    name    = "tcp_connector_slave";
    type    = "custom";
    scheme  = "service";
    entry   = "run_tcp_slave";
    channel = "channel";
}

component {
    name    = "tcp_connector_worker";
    type    = "custom";
    scheme  = "service";
    entry   = "run_tcp_worker";
    channel = "channel";
}
