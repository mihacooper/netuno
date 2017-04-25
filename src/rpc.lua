#!/usr/bin/lua
package.path = package.path .. ";" .. (os.getenv("LUA_RPC_SDK") or "..") .. "/?.lua"
package.path = package.path .. ";" .. (os.getenv("LUA_RPC_SDK") or "..") .. "/externals/argparse/src/?.lua"

argparse = require "argparse"
parser = argparse("rpc.lua", "Lua RPC tool")
parser:command_target("command")
generate_cmd = parser:command("generate", "generate sources")
    generate_cmd:argument("module", "the name of module included the interface")
    generate_cmd:argument("language", "the destination language")
    generate_cmd:argument("type", "client or server source file")
rebuild_cmd  = parser:command("rebuild",  "rebuild general manifest")
    rebuild_cmd:argument("component", "component name")
register_cmd = parser:command("register", "register component")
    register_cmd:argument("component", "component name")
delete_cmd   = parser:command("delete",   "delete component")
    delete_cmd:argument("component", "component name")
list_cmd   = parser:command("list",   "list all components")
args = parser:parse()

local storage_file = "./storage.lua"
local storage = {}
local component_types = { connector = true, factory = true, protocol = true, custom = true }

function load_storage()
    print("Load storage")
    local storage_loader = loadfile(storage_file) or function() return {} end
    storage =  storage_loader() or {}
end

function save_storage()
    print("Save storage")
    local data = "return " .. dump_table(storage)
    io.open(storage_file, "w"):write(string.dump(loadstring(data))):close()
end

function error_if(cond, msg)
    if not cond then
        print("Error: " .. msg)
        os.exit(1)
    end
end

function read_manifest(comp_name)
    print("Loading manifest for '" .. comp_name .. "'")
    local components = {}
    local context = {
        component = function(cfg)
            table.insert(components, cfg)
        end
    }
    local comp_f, err = loadfile("./components/" .. comp_name .. "/manifest.lua", "bt", context)
    error_if(comp_f ~= nil and pcall(comp_f), "Unable to load '" .. comp_name .. "' manifest file")
    for _, cmp in pairs(components) do
        cmp.path = comp_name
    end
    return components
end

function dump_table(t)
    if type(t) == "number" or type(t) == "bool" then
        return tostring(t)
    elseif type(t) == "string" then
        return "'" .. t .. "'"
    elseif type(t) == "table" then
        local ret = "{"
        for k, v in pairs(t) do
            ret = ret .. "[" .. dump_table(k) .. "]=" .. dump_table(v) .. ","
        end
        return ret .. "}"
    else
        error("Unable to dump type: " .. type(t))
    end
end

if args.generate then
    local module_path = args.module
    local language    = args.language
    local target      = args.type

    local loader = require "src.loader"
    local ret, generator = loader(module_path, language, target)
    if not ret then
        print(generator) -- it's error message
        print(HELP)
        os.exit(1)
    end

    local module_name = string.gsub(module_path, "(%w-).lua", "%1")
    if type(module_name) ~= "string" then
        print("Unable to get module name")
        os.exit(1)
    end

    local ret, msg = pcall(generator, { module_name = module_name, module_path = module_path })
    if not ret then
        print(msg)
        os.exit(1)
    end
elseif args.rebuild then
    local comp_file = loadfile("components.lua")
    error_if(comp_file, "Invalid SDK base")
    local comp_cfg = loadfile("components.lua")()

    local loaded = {
        connector = {},
        factory   = {},
        protocol  = {},
        custom    = {},
    }

    for _, v in pairs(comp_cfg) do
        print("Loading", v)
        local components = {}
        local context = {
            component = function(cfg)
                table.insert(components, cfg)
            end
        }
        local comp_f, err = loadfile(v .. "/manifest.lua", "bt", context)
        if comp_f == nil or not pcall(comp_f) then
            print("Unable to load", v, "manifest file")
            print("\t", err)
        else
            for _, cmp in pairs(components) do
                error_if(loaded[cmp.type], "Invalid type of component '" .. cmp.type .. "'")
                table.insert(loaded[cmp.type], cmp)
            end
        end
    end

    local storage_data = "return " .. dump_table(loaded)
    print(storage_data)
elseif args.register then
    parser:argument("component", "name of component")
    error_if(io.open("./components/" .. args.component .. "/manifest.lua", "r") ~= nil, "Unable to find component manifest file")

    load_storage()
    local manifest_data = read_manifest(args.component)
    for _, cmp in ipairs(manifest_data) do
        error_if(storage[cmp.name] == nil, "Component with name '" .. cmp.name .. "' already exists")
        error_if(component_types[cmp.type], "Invalid type of component '" .. cmp.type .. "'")
        print("Register component '" .. cmp.name .. "'")
        storage[cmp.name] = cmp
        cmp.name = nil
    end
    save_storage()
elseif args.delete then
    parser:argument("component", "name of component")
    error_if(io.open("./components/" .. args.component .. "/manifest.lua", "r") ~= nil, "Unable to find component manifest file")

    load_storage()
    local manifest_data = read_manifest(args.component)
    for _, cmp in ipairs(manifest_data) do
        error_if(storage[cmp.name] ~= nil, "Component with name '" .. cmp.name .. "' not found")
        print("Delete component '" .. cmp.name .. "'")
        storage[cmp.name] = nil
    end
    save_storage()
elseif args.list then
    load_storage()
    print("------------")
    for cmp_name, cmp in pairs(storage) do
        print(cmp_name)
        print("\ttype:    ", cmp.type)
        print("\tversion: ", cmp.version)
        print("\tpath:    ", "components/" .. cmp.path)
        print("\tmethods: ", table.concat(cmp.methods, ", "))
        print("\tfields:  ", dump_table(cmp.fields))
    print("------------")
    end
else
    error("Wrong command")
end




