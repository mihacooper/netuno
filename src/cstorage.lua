require "helpers"

cstorage = {
    verbose = false,
    component_types = {
        connector = true,
        factory   = true,
        protocol  = true,
        custom    = true,
        system    = true
    },
    api_channels = {}
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
    local cmp_file_data = io.open(tmp_file, "r"):read("*a")
    local comp_data_loader = load(cmp_file_data, cmp_name, "bt")
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

function cstorage:get_methods(cmp_name)
    return storage.components[cmp_name].methods or {}
end

function cstorage:get_component_loader(cmp_name)
    local cmp = storage.components[cmp_name]

    if cmp.type == "system" then
        return { loader = ("return system.syscmp_create('%s')"):format(cmp_name) }
    else
        local cmp_str = storage.storages[cmp.module_path]
        if not cmp_str then
            log_err("Unable to find component storage: %s", cmp_name)
        end
        local raw_comp_data = cmp_str.data

        local function instate_loader(cmp_name, raw_data)
            local sandbox_env = {
                _G = {},
                effil = effil,
                component = component,
                require_c = require_c,
                log_dbg = log_dbg,
                log_err = log_err,
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
                error = error,
                assert = assert,
                io = io,
                coroutine = { create = coroutine.create, resume = coroutine.resume, 
                  running = coroutine.running, status = coroutine.status, 
                  wrap = coroutine.wrap },
                string = { byte = string.byte, char = string.char, find = string.find, 
                  format = string.format, gmatch = string.gmatch, gsub = string.gsub, 
                  len = string.len, lower = string.lower, match = string.match, 
                  rep = string.rep, reverse = string.reverse, sub = string.sub, 
                  upper = string.upper },
                table = { insert = table.insert, maxn = table.maxn, remove = table.remove, 
                  sort = table.sort, concat = table.concat },
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
        return { loader = string.dump(instate_loader), data = {cmp_name, raw_comp_data} }
    end
end

function cstorage:load_instate_component(channel_id)
    local cmp_name = effil.G.system.storage:get(channel_id).input:pop(0)
    if not cmp_name then
        error("CStorage: unable to read input data from channel '" .. tostring(channel_id) .. "'")
    end
    log_dbg("Reading cstorage request data: channel ID = %s, component = %s", channel_id, cmp_name)

    local cmp = storage.components[cmp_name]
    if not cmp then
        error("CStorage: Invalid component name: " .. tostring(cmp_name))
    end
    effil.G.system.storage:get(channel_id).output:push(self:get_component_loader(cmp_name))
end

function cstorage:load_component(channel_id)
    local cmp_name = effil.G.system.storage:get(channel_id).input:pop(0)
    if not cmp_name then
        error("CStorage: unable to read input data from channel '" .. tostring(channel_id) .. "'")
    end
    log_dbg("Reading cstorage request data: channel ID = %s, component = %s", channel_id, cmp_name)

    local cmp = storage.components[cmp_name]
    if not cmp then
        error("CStorage: Invalid component name: " .. tostring(cmp_name))
    end
    local methods = cmp.methods

    local data_to_return = nil
    if cmp.scheme == "instate" then
        data_to_return = self:get_component_loader(cmp_name)
    elseif cmp.scheme == "outstate" then
        local storage_id = effil.G.system.storage:new()
        effil.G.system.storage:get(storage_id).creation_status = effil.channel()

        local outstate_cli_loader_src = [[
            return function()
                local stat, err = require('effil').G.system.storage:get({*storage_id*}).creation_status:pop()
                if not stat then
                    log_dbg(err)
                    return nil
                end
                return {
                    __component_id = {*comp_id*},
            {%for _, method in ipairs(methods) do%}
                    ["{*method*}"] = function(self, ...)
                        require('effil').G.system.storage:get({*storage_id*}).input = {...}
                        system.outstate_call({*comp_id*}, "{*method*}", "__loaded_component")
                        local res = require('effil').G.system.storage:get({*storage_id*}).output
                        local ret = {}
                        for _, v in ipairs(res) do table.insert(ret, table.rcopy(v)) end
                        return unpack(ret)
                    end,
            {%end%}
                }
            end
        ]]

        local outstate_srv_loader_src = [[
            return function()
                local loaded_cmp = component:load_instate("{*cmp_name*}")
                if not loaded_cmp then
                    require('effil').G.system.storage:get({*storage_id*}).creation_status:push(false,
                            "Outstate component loader returns nil ({*cmp_name*}, {*storage_id*})")
                    return nil
                end
                require('effil').G.system.storage:get({*storage_id*}).creation_status:push(true)
                _G.__loaded_component = {
                    loaded_cmp = loaded_cmp,
            {%for _, method in ipairs(methods) do%}
                    ["{*method*}"] = function(self)
                        local share = require('effil').G.system.storage:get({*storage_id*})
                        local input = {}
                        for k,v in ipairs(share.input) do input[k] = v end
                        share.output = table.pack(self.loaded_cmp["{*method*}"](self.loaded_cmp, unpack(input)))
                    end,
            {%end%}
                }
            end
        ]]
        local outstate_srv_loader = loadstring(generate(outstate_srv_loader_src,
                { cmp_name = cmp_name, methods = methods, storage_id = storage_id }))()
        local comp_id = system.outstate_create(cmp_name, string.dump(outstate_srv_loader))

        local outstate_cli_loader = loadstring(generate(outstate_cli_loader_src,
                { methods = methods, storage_id = storage_id, comp_id = comp_id }))()

        data_to_return = { loader = string.dump(outstate_cli_loader) }
    elseif cmp.scheme == "service" then
        local storage_id = require('effil').G.system.storage:new()
        require('effil').G.system.storage:get(storage_id).exchange_channel = require('effil').channel()
        require('effil').G.system.storage:get(storage_id).input_args = require('effil').channel()

        local service_cli_loader_src = [[
            return function(...)
                require('effil').G.system.storage:get({*storage_id*}).input_args:push(...)
                return require('effil').G.system.storage:get({*storage_id*}).exchange_channel
            end
        ]]

        local service_srv_loader_src = [[
            return function()
                local loaded_cmp = component:load_instate("{*cmp_name*}")
                local channel = require('effil').G.system.storage:get({*storage_id*}).exchange_channel
                loaded_cmp["{*service_main*}"](loaded_cmp, require('effil').G.system.storage:get({*storage_id*}).input_args:pop())
            end
        ]]
        local service_srv_loader = loadstring(generate(service_srv_loader_src,
                { cmp_name = cmp_name, service_main = cmp.service_main, storage_id = storage_id}))()
        system.service_create(string.dump(service_srv_loader))

        local service_cli_loader = loadstring(generate(service_cli_loader_src, {storage_id = storage_id}))()
        data_to_return = { loader = string.dump(service_cli_loader) }
    else
        error("Unknown component integration type " .. cmp.scheme)
    end
    log_dbg("Return data for request (%s, %s):", channel_id, cmp_name)
    for k,v in pairs(data_to_return) do
        log_dbg("\t%s = %s", string.sub(tostring(k), 1, 50), string.sub(tostring(v), 1, 50))
    end
    effil.G.system.storage:get(channel_id).output:push(data_to_return)

    collectgarbage()
    effil.gc.collect()
end

function cstorage:get_cstorage_api()
    local storage_id = require('effil').G.system.storage:new()
    require('effil').G.system.storage:get(storage_id).input = require('effil').channel()
    require('effil').G.system.storage:get(storage_id).output = require('effil').channel()
    table.insert(self.api_channels, storage_id)

    return generate([[
        component = { storage_id = {*storage_id*} }

        function component:__load(func, cmp_name, ...)
            require('effil').G.system.storage:get(self.storage_id).input:push(cmp_name)

            system.cstorage(func, self.storage_id)

            local str = require('effil').G.system.storage:get(self.storage_id).output:pop()
            local in_args = {}
            if str.data then
                for _, v in ipairs(str.data) do
                    table.insert(in_args, v)
                end
            end
            for _, v in ipairs({...}) do
                table.insert(in_args, v)
            end
            collectgarbage()
            require('effil').gc.collect()
            return loadstring(str.loader)(unpack(in_args))
        end

        function component:load(cmp_name, ...)
            return self:__load("load_component", cmp_name, ...)
        end

        function component:load_instate(cmp_name, ...)
            return self:__load("load_instate_component", cmp_name, ...)
        end

        function component:unload(cmp_data)
            if type(cmp_data) == "table" and cmp_data.__component_id then
                system.outstate_unload(cmp_data.__component_id)
            end
        end
    ]], { storage_id = storage_id })
end

return cstorage
