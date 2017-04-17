#include <iostream>
#include "sample.hpp"
#include "atomic"

using namespace rpc_sdk;

SampleInterface::SampleInterface() {}

SampleInterface::~SampleInterface() {}

SampleStructure SampleInterface::MyFunction1(int param1, int param2)
{
    return SampleStructure{param1, std::to_string(param2)};
}

int SampleInterface::MyFunction2(SampleStructure param1, std::string param2)
{
    return param1.field1;
}

void SampleInterface::MyFunction3(int param1)
{
    printf("MyFunction3: %d\n", param1);
}

std::string SampleInterface::MyFunction4()
{
    return "return string";
}

volatile std::atomic_bool g_stopProc(false);

void SampleInterface::FinishTest()
{
    std::cout << "Server received finished massage" << std::endl;
    g_stopProc = true;
}

int main()
{
    Initialize();
    while(!g_stopProc)
    {
        std::this_thread::sleep_for(std::chrono::seconds(1));
    };
    Uninitialize();
}