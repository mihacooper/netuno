DEBUG = true
require 'string'

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

function IsString(val)
    return type(val) == type('')
end

function In(val, cont)
    for _, v in pairs(cont) do
        if v == val then
            return true
        end
    end
    return false
end

function StrRepeat(str, args)
    local result = str
    for repKey, cases in pairs(args) do
        if IsTable(cases) then
            local pattern = string.format("<|%s|>(.-)<|%s|>", repKey, repKey)
            for instance in string.gmatch(result, pattern) do
                for _, case in pairs(cases) do
                    local substr = StrRepeat(instance, case)
                    result = string.gsub(result, pattern, string.format("%s<|%s|>%s<|%s|>", substr, repKey, '%1', repKey), 1)
                end
                result = string.gsub(result, pattern, '', 1)
            end
        else
            result = StrReplace(result, { [repKey] = cases})
        end
    end
    return result
end