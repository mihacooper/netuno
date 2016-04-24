#include "sample.h"

int main()
{
    SampleInterface interface;

    int val = interface.MyFunction1(10, 10);
    std::string str = interface.MyFunction2(10, 10);
    interface.MyFunction3(10, 10);
}