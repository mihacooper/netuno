module_path = "plain_factory";
submodules  = {};

component {
    name    = "plain_factory";
    type    = "custom";
    scheme  = "outstate-singleton";
    entry   = "get_factory";
    methods = {"new", "get", "del"};
    fields  = { };
}