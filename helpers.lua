DEBUG = true
require 'string'

function Debug(...)
    if DEBUG then
        print(table.concat(arg, " "))
    end
end

function Error(...)
    error(Debug(...))
    os.exit(1)
end

function table.copy(dst, src)
    for k, v in pairs(src)
    do
        dst[k] = v
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

function WriteToFile(filename, data)
    local file = io.open(filename, "w")
    file:write(data)
    file:close()
end

function StrReplace(str, args)
    local result = str
    for name, value in pairs(args) do
        local pattern = '{{' .. name .. '}}'
        result = string.gsub(result, pattern, value)
    end
    return result
end

function ToString(val)
    return val .. ''
end

function IsTable(val)
    return type(val) == type({})
end
--[[
    Usage: StrRepeat("||1||{{a}}||1||||2||{{b}}||2||", { {{a = 1}, {a = 2}}, {{ b = 3, b = 4}} })
    will return string:
        1234
]]
function StrRepeat(str, args)
    local result = str
    for repKey, cases in pairs(args) do
        if IsTable(cases) then
            local pattern = string.format("<|%s|>(.*)<|%s|>", repKey, repKey)
            for _, case in pairs(cases) do
                substr = StrRepeat(string.match(str, pattern), case)
                result = string.gsub(result, pattern, string.format("%s<|%s|>%s<|%s|>", substr, repKey, '%1', repKey))
            end
            result = string.gsub(result, pattern, '')
        else
            result = StrReplace(result, { [repKey] = cases})
        end
    end
    return result
end
return StrRepeat