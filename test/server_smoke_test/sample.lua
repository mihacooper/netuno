struct "SampleStructure"
{
    int "field1";
    str "field2";
}

class "SampleInterface"
{
    func (int) "MyFunction1"(int "param1", int "param2");
    func (int) "MyFunction2"(int "param1", str "param2");
    func "MyFunction3"(int "param1");
    func (str) "MyFunction4"();
}
