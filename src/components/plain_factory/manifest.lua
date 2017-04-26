module_path = "plain_factory";
submodules  = {};

component {
    name    = "plain_factory";
    type    = "custom";
    scheme  = "instate";
    methods = {"new", "get", "del"};
    fields  = { };
}