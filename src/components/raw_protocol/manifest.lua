module_path = "raw_protocol";
submodules  = {};

component {
    name    = "raw_protocol_encode";
    type    = "custom";
    scheme  = "instate";
    entry   = "get_raw_encode";
}

component {
    name    = "raw_protocol_decode";
    type    = "custom";
    scheme  = "instate";
    entry   = "get_raw_decode";
}
