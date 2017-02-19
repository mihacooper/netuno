struct "SampleStructure"
{
    int "field1";
    str "field2";
}

class "SampleInterface"
{
    func (SampleStructure) "MyFunction1"(int "param1", int "param2")
    {
        impl = function(self, param1, param2)
            print(param1, param2)
            return { field1 = param1, field2 = tostring(param2) }
        end
    };
    func (int) "MyFunction2"(SampleStructure "param1", str "param2");
    func "MyFunction3"(int "param1");
    func (str) "MyFunction4"();
}
