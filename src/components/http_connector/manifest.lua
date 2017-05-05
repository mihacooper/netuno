module_path = "http_connector";
submodules  = {};

component {
    name    = "http_connector_slave";
    type    = "custom";
    scheme  = "service";
    methods = {};
    service_main  = "run";
    channel = "channel";
}

component {
    name    = "http_connector_worker";
    type    = "custom";
    scheme  = "service";
    methods = {"set_socket_fd"};
    service_main  = "run";
    channel = "channel";
}
