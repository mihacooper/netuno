return
{
    Interface = function(intr)
      return intr
    end,

    Function = function(...)
        local mt = { __concat = function(l, r) l.output = r return l end }
        local f = { input = {} }
        setmetatable(f, mt)
        args = {...}
        for i = 1, #args do
            table.insert(f.input, args[i])
        end
        return f
    end,
}
