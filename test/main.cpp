#include "sample.h"

int main()
{
    SampleInterface interface;

    int val1 = interface.MyFunction1(10, 10);
    int val2 = interface.MyFunction2(10, "string");
    interface.MyFunction3(10);
}