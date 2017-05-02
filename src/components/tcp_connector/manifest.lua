module_path = "tcp_connector";
submodules  = {};

component {
    name    = "tcp_connector_master";
    type    = "custom";
    scheme  = "instate";
    methods = {"request_new", "request_call", "request_del"};
}

component {
    name    = "tcp_connector_slave";
    type    = "custom";
    scheme  = "service";
    methods = {};
    service_main  = "run";
    channel = "channel";
}

component {
    name    = "tcp_connector_worker";
    type    = "custom";
    scheme  = "service";
    methods = {"set_socket_fd"};
    service_main  = "run";
    channel = "channel";
}
