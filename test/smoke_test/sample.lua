struct "SampleStructure"
{
    int_t "field1";
    str_t "field2";
}

class "SampleInterface"
{
    func "MyFunction1": SampleStructure(int_t "param1", int_t "param2")
    :with{
        impl = function(self, param1, param2)
            print("MyFunction1", param1, param2)
            return { field1 = param1, field2 = tostring(param2) }
        end
    };

    func "MyFunction2": int_t(SampleStructure "param1", str_t "param2")
    :with{
        impl = function(self, param1, param2)
            print("MyFunction2", param1, param2)
            return param1.field1
        end
    };

    func "MyFunction3": none_t(int_t "param1")
    :with{
        impl = function(self, param1)
            print("MyFunction3", param1)
        end
    };
    func "MyFunction4": str_t()
    :with{
        impl = function()
            print("MyFunction4")
            return "return string"
        end
    };
}
