require "helpers"

cstorage = {
    verbose = false,
    component_types = {
        connector = true,
        factory   = true,
        protocol  = true,
        custom    = true,
        system    = true
    }
}

if LUA_RPC_SDK == nil then
    LUA_RPC_SDK = os.getenv("LUA_RPC_SDK") or ".."
end

local storage_file = LUA_RPC_SDK .. "/src/storage"
local storage = {}

local function info(fmt, ...)
    if cstorage.verbose then
        print(string.format(fmt, ...))
    end
end

function cstorage:data()
    return storage
end

function cstorage:load()
    info("Load storage '%s'", storage_file)
    local storage_loader = loadfile(storage_file) or function() return {} end
    storage =  storage_loader() or {}
    if storage.storages == nil then
        storage.storages = {}
    end
    if storage.components == nil then
        storage.components = {}
    end
    for _, str in pairs(storage.storages) do
        local bin_data = str.data
        local str_data = ""
        for i = 1, bin_data:len(), 2 do
            local char_hex = table.concat({bin_data:sub(i, i + 1)}, "")
            local char_num = tonumber(char_hex, 16)
            str_data = str_data .. string.char(char_num)
        end
        str.data = str_data
    end
end

function cstorage:save()
    info("Save storage")
    for _, str in pairs(storage.storages) do
        local bin_data = ""
        for _, byte in ipairs({str.data:byte(1, str.data:len())}) do
            bin_data = bin_data .. ("%02X"):format(byte)
        end
        str.data = bin_data
    end
    local data = "return " .. dump_table(storage)
    if not data then
        log_err("Unable to dump storage data")
    end
    --local bin_data = string.dump(loadstring(data))
    io.open(storage_file, "w"):write(data):close()
end

function cstorage:read_manifest(comp_name)
    info("Loading manifest for '" .. comp_name .. "'")
    local components = {}
    local context = {
        component = function(cfg)
            table.insert(components, cfg)
        end
    }
    local comp_f, err = loadfile("./components/" .. comp_name .. "/manifest.lua", "bt", context)
    if comp_f == nil or not pcall(comp_f) then
        log_err ("Unable to load '" .. comp_name .. "' manifest file")
    end
    for _, cmp in pairs(components) do
        cmp.module_path = comp_name
    end
    return {module = context.module, submodules = context.submodules}, components
end

function cstorage:build_component(cmp_name, cmp_storage)
    info("Building component '" .. cmp_name .. "'")
    local cmp_dir = ("%s/src/components/%s"):format(LUA_RPC_SDK, cmp_name)
    local tmp_file = ("%16X"):format(math.floor(math.random() * 2 ^ 64))
    local status = os.execute(("lua %s/externals/luacc/bin/luacc.lua -o %s -i %s %s %s"):format(
        LUA_RPC_SDK, tmp_file, cmp_dir, cmp_name, table.concat(cmp_storage.submodules, " ")))
    if not status then
        log_err("Unable to run luacc")
    end
    local cmp_file = io.open(tmp_file, "r+")
    cmp_file:write("package = require 'package'\n")
    cmp_file:close()
    local comp_data_loader = loadfile(tmp_file)
    if not comp_data_loader then
        log_err("Unable to load generated component storage")
    end
    os.execute("rm " .. tmp_file)
    local comp_data = string.dump(comp_data_loader)
    if not comp_data then
        log_err("Unable to dump component storage")
    end
    return comp_data
end

function cstorage:add_component(cmp_str)
    if self:check_component_storage(cmp_str) then
        log_err("Component storage with name '%s' already exists", cmp_str)
    end

    local cmp_storage, components = self:read_manifest(cmp_str)
    storage.storages[cmp_str] = cmp_storage
    for _, cmp in ipairs(components) do
        if self:check_component(cmp.name) then
            log_err("Component with name '%s' already exists", cmp.name)
        end
        if not self:check_type(cmp.type) then
            log_err("Invalid type of component '%s'", cmp.type)
        end
        info("Register component '%s'", cmp.name)
        storage.components[cmp.name] = cmp
    end
    local storage_data = self:build_component(cmp_str, cmp_storage)
    storage.storages[cmp_str].data = storage_data
end

function cstorage:registrate_component(manifest, cmp_str)
    if self:check_component_storage(manifest.name) then
        log_err("Component storage with name '%s' already exists", manifest.name)
    end

    if self:check_component(manifest.name) then
        log_err("Component with name '%s' already exists", manifest.name)
    end
    if not self:check_type(manifest.type) then
        log_err("Invalid type of component '%s'", manifest.type)
    end
    log_dbg("Register component '%s'", manifest.name)
    if manifest.type ~= "system" then
        storage.storages[manifest.name] = {
            module_path = manifest.name,
            submodules = {},
            data = string.dump(cmp_str)
        }
        manifest.module_path = manifest.name
    end
    storage.components[manifest.name] = manifest
end

function cstorage:remove_component(cmp_str)
    if not self:check_component_storage(cmp_str) then
        log_err("Component storage with name '%s' not found", cmp_str)
    end
    storage.storages[cmp_str] = nil
    info("Component storage removed")
    info("Looking for components")
    for cmp_name, cmp in pairs(storage.components) do
        if cmp.module_path == cmp_str then
            info( ("Components '%s' removed"):format(cmp_name))
            storage.components[cmp_name] = nil
        end
    end
end

function cstorage:check_component(cmp_name)
    return storage.components[cmp_name] ~= nil
end

function cstorage:check_component_storage(str_name)
    return storage.storages[str_name] ~= nil
end

function cstorage:check_type(type_name)
    return cstorage.component_types[type_name] ~= nil
end

function cstorage:get_type(cmp_name)
    return storage.components[cmp_name].type
end

function cstorage:get_scheme(cmp_name)
    return storage.components[cmp_name].scheme
end

function cstorage:get_imports(cmp_name)
    return storage.components[cmp_name].imports or {}
end

function cstorage:load_component(cmp_name)
    local cmp = storage.components[cmp_name]
    local raw_comp_data = storage.storages[cmp.module_path].data

    function loader_to_import(cmp_name, raw_data)
        local sandbox_env = {
            _G = {},
            require_c = require_c,
            require = require,
            print = print,
            ipairs = ipairs,
            next = next,
            pairs = pairs,
            pcall = pcall,
            tonumber = tonumber,
            tostring = tostring,
            type = type,
            unpack = unpack,
            coroutine = { create = coroutine.create, resume = coroutine.resume, 
              running = coroutine.running, status = coroutine.status, 
              wrap = coroutine.wrap },
            string = { byte = string.byte, char = string.char, find = string.find, 
              format = string.format, gmatch = string.gmatch, gsub = string.gsub, 
              len = string.len, lower = string.lower, match = string.match, 
              rep = string.rep, reverse = string.reverse, sub = string.sub, 
              upper = string.upper },
            table = { insert = table.insert, maxn = table.maxn, remove = table.remove, 
              sort = table.sort },
            math = { abs = math.abs, acos = math.acos, asin = math.asin, 
              atan = math.atan, atan2 = math.atan2, ceil = math.ceil, cos = math.cos, 
              cosh = math.cosh, deg = math.deg, exp = math.exp, floor = math.floor, 
              fmod = math.fmod, frexp = math.frexp, huge = math.huge, 
              ldexp = math.ldexp, log = math.log, log10 = math.log10, max = math.max, 
              min = math.min, modf = math.modf, pi = math.pi, pow = math.pow, 
              rad = math.rad, random = math.random, sin = math.sin, sinh = math.sinh, 
              sqrt = math.sqrt, tan = math.tan, tanh = math.tanh },
            os = { clock = os.clock, difftime = os.difftime, time = os.time },
        }
        local cmp_loader = loadstring(raw_data, nil, nil, sandbox_env)
        if not cmp_loader then
            error("Unable to load component data")
        end
        local exe_stat, err = pcall(cmp_loader)
        if not exe_stat then
            error(("Unable to run component: %s"):format(err))
        end
        if sandbox_env[cmp_name] == nil then
            error(("Component entry point '%s' is nil"):format(cmp_name))
        end
        return sandbox_env[cmp_name]
    end
    return { methods = cmp.methods, loader = string.dump(loader_to_import), component = raw_comp_data }
end

return cstorage