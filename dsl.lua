return
{
    Interface = function(intr)
      return intr
    end,

    Function = function(...)
        local mt = { __concat = function(l, r) l.output = r return l end }
        local f = { input = {} }
        setmetatable(f, mt)
        for i = 1, #arg do
            print("arg " .. arg[i])
            table.insert(f.input, arg[i])
        end
        return f
    end,
}
