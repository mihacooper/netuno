#include <iostream>
#include "SampleInterface.h"

int main()
{
    SampleInterface interface;

#define TEST_FUNC0(f) { f; std::cout << "\tCpp: " #f << std::endl; }
#define TEST_FUNC(f) std::cout << "\tCpp: " #f << " -> " << f << std::endl

    TEST_FUNC(interface.MyFunction1(10, 10));
    TEST_FUNC(interface.MyFunction2(10, "string"));
    TEST_FUNC0(interface.MyFunction3(10));
    TEST_FUNC(interface.MyFunction4());
}