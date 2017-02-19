#include <iostream>
#include "SampleInterface.h"
#include "SampleStructure.h"

std::ostream& operator <<(std::ostream& s, const SampleStructure& str)
{
    return s << "{ " << str.field1 << ", "<< str.field2 << " }";
}

int main()
{
    SampleInterface interface;
    SampleStructure str{76, "oprst"};

#define TEST_FUNC0(f) { f; std::cout << "\tCpp: " #f << std::endl; }
#define TEST_FUNC(f) std::cout << "\tCpp: " #f << " -> " << f << std::endl

    TEST_FUNC(interface.MyFunction1(10, 10));
    TEST_FUNC(interface.MyFunction2(str, "string"));
    TEST_FUNC0(interface.MyFunction3(10));
    TEST_FUNC(interface.MyFunction4());
}