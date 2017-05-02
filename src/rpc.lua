#!/usr/bin/lua

LUA_RPC_SDK = os.getenv("LUA_RPC_SDK") or ".."
package.path = package.path .. ";" .. LUA_RPC_SDK .. "/?.lua"
package.path = package.path .. ";" .. LUA_RPC_SDK .. "/src/?.lua"
package.path = package.path .. ";" .. LUA_RPC_SDK .. "/externals/argparse/src/?.lua"

require "helpers"
argparse = require "argparse"
cstorage = require "cstorage"
cstorage.verbose = true

parser = argparse("rpc.lua", "Lua RPC tool")
parser:command_target("command")
generate_cmd = parser:command("generate", "generate sources")
    generate_cmd:argument("module", "the name of module included the interface")
    generate_cmd:argument("language", "the destination language")
    generate_cmd:argument("type", "client or server source file")
rebuild_cmd  = parser:command("rebuild",  "rebuild general manifest")
    rebuild_cmd:argument("component", "component name"):args("?")
register_cmd = parser:command("register", "register component")
    register_cmd:argument("component", "component name")
delete_cmd   = parser:command("delete",   "delete component")
    delete_cmd:argument("component", "component name")
list_cmd   = parser:command("list",   "list all components")
args = parser:parse()

function error_if(cond, msg)
    if not cond then
        print("Error: " .. msg)
        os.exit(1)
    end
end

if args.generate then
    local module_path = args.module
    local language    = args.language
    local target      = args.type

    _G.target = target

    if module_path == nil or io.open(module_path, "r") == nil then
        log_err("Invalid module file: " .. module_path)
    end

    require "dsl"
    local err, generator = pcall(require,  "lang-" .. language .. ".binding")
    if language == nil or not err then
        log_err("Invalid language: " .. language)
    end

    local ret, err = pcall(dofile, module_path)
    if not ret then
        log_err("Error during module loading: %s", err)
    end

    local module_name = string.gsub(module_path, "(%w-).lua", "%1")
    if type(module_name) ~= "string" then
        log_err("Unable to get module name")
    end

    local ret, msg = pcall(generator, { module_name = module_name, module_path = module_path })
    if not ret then
        log_err("Error during generation: %s", msg)
    end
elseif args.rebuild then
    cstorage:load()
    local storage = cstorage:data()

    if args.component then
        cstorage:remove_component(args.component)
        cstorage:add_component(args.component)
    else
        local all_comp_strs = {}
        for str_name, _ in pairs(cstorage:data().storages) do
            table.insert(all_comp_strs, str_name)
        end
        for _, str_name in ipairs(all_comp_strs) do
            cstorage:remove_component(str_name)
            cstorage:add_component(str_name)
        end
    end

    cstorage:save()
elseif args.register then
    error_if(io.open("./components/" .. args.component .. "/manifest.lua", "r") ~= nil, "Unable to find component manifest file")
    cstorage:load()
    cstorage:add_component(args.component)
    cstorage:save()
elseif args.delete then
    error_if(io.open("./components/" .. args.component .. "/manifest.lua", "r") ~= nil, "Unable to find component manifest file")
    cstorage:load()
    cstorage:remove_component(args.component)
    cstorage:save()
elseif args.list then
    cstorage:load()
    local storage = cstorage:data()
    print("------------")
    for cmp_name, cmp in pairs(storage.components) do
        print(cmp_name)
        print("\ttype:    ", cmp.type)
        print("\tversion: ", cmp.version)
        print("\tpath:    ", "components/" .. cmp.module_path)
        print("\tmethods: ", table.concat(cmp.methods, ", "))
        print("\tfields:  ", dump_table(cmp.fields))
    print("------------")
    end
else
    error("Wrong command")
end




