module_path = "http_connector";
submodules  = {};

component {
    name    = "http_connector";
    type    = "custom";
    scheme  = "service";
    entry   = "run_slave";
    channel = "channel";
}

component {
    name    = "http_connector::worker";
    type    = "custom";
    scheme  = "service";
    entry   = "run_worker";
    channel = "channel";
}
