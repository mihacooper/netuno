Interface "SampleInterface"
{
    Int .. Function "MyFunction1" { Int "param1", Int "param2"}
    {
    	function(p1, p2) return p1 + p2 end,
    },
    Int .. Function "MyFunction2" { Int "param1", String "param2"},
    Function "MyFunction3" { Int "param1"},
    String .. Function "MyFunction4" { },
}
