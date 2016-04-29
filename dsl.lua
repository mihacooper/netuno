function CheckName(name)
    return true
end

function NewType(pType)
    local t = { paramType = pType}
    setmetatable(t, 
        { 
            __call = function(t, name)
                local r = {}
                table.rcopy(r, t)
                r.paramName = name
                return r
            end,
            __concat = function(t, func)
                local r = {}
                table.rcopy(r, t)
                func.output = r
                return func
            end
        }
    )
    return t
end

function Interface(intr)
  return intr
end

function Function(name)
    local mt = {
        __call = function(func, params)
            func.input = params
            return func
        end
    }
    local f = { funcName = name} 
    f.impl = function(...)
        print("HERE WILL BE IMPLEMENTATION")
    end
    setmetatable(f, mt)
    return f
end
