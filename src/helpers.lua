DEBUG = true
require 'string'
local templates = require "template.lib.resty.template"

function Debug(...)
    if DEBUG then
        print(table.concat(arg, " "))
    end
end

function Error(...)
    error(table.concat({...}, " "))
    os.exit(1)
end

function Expect(cond, msg)
    if not cond then
        Error(msg)
    end
end

function table.copy(dst, src)
    for k, v in pairs(src)
    do
        dst[k] = v
    end
end

function table.rcopy(dst, src)
    for k, v in pairs(src) do
        if IsTable(v) then
            dst[k] = {}
            table.rcopy(dst[k], v)
        else
            dst[k] = v
        end
    end
end

function table.exclude(dst, src)
    for k, v in pairs(src)
    do
        dst[k] = nil
    end
end

function table.iforeach(array, func)
    local res = {}
    for _, v in ipairs(array)
    do
        table.insert(res, func(v))
    end
    return res
end

function write_to_file(filename, data)
    local file = io.open(filename, "w")
    file:write(data)
    file:close()
end

function is_table(val)
    return type(val) == type({})
end

function is_string(val)
    return type(val) == type('')
end

function value_in_table(val, cont)
    for _, v in pairs(cont) do
        if v == val then
            return true
        end
    end
    return false
end

function generate(temp, data)
    local render_res = ""
    templates.print = function(res)
        render_res = res
    end
    templates.render(temp, data)
    return render_res
end