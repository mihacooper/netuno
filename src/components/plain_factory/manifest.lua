module_path = "plain_factory";
submodules  = {};

component {
    name    = "plain_factory";
    type    = "custom";
    scheme  = "outstate";
    methods = {"new", "get", "del"};
    fields  = { };
}