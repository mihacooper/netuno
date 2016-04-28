return
{
    Interface = function(intr)
      return intr
    end,

    Function = function(input_args)
        local mt = { __concat = function(l, r) l.output = r return l end }
        local f = { input = {}, impl = function(...)
                print("HERE WILL BE IMPLEMENTATION")
            end
        }
        setmetatable(f, mt)
        f.input = {}
        for pName, pType in pairs(input_args) do
            table.insert( f.input, { paramName = pName, paramType = pType} )
        end
        return f
    end,
}
