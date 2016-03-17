DEBUG = true

function Debug(...)
    if DEBUG then
        print(table.concat(arg, " "))
    end
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