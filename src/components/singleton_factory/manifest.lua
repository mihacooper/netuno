module_path = "singleton_factory";
submodules  = {};

component {
    name    = "singleton_factory";
    type    = "custom";
    scheme  = "outstate-singleton";
    entry   = "get_factory";
    methods = {"new", "get", "del"};
    fields  = { };
}