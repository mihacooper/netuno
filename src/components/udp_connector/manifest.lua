module_path = "udp_connector";
submodules  = {};

component {
    name    = "udp_connector_master";
    type    = "custom";
    scheme  = "instate";
    entry   = "get_udp_master";
}

component {
    name    = "udp_connector_slave";
    type    = "custom";
    scheme  = "service";
    entry   = "run_udp_slave";
    channel = "channel";
}
