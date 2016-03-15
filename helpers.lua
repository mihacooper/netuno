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