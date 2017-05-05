#include <iostream>
#include "sample-server.hpp"
#include "atomic"

using namespace rpc_sdk;

std::mutex g_lock;
size_t g_ifaceCount = 0;

namespace rpc_sdk
{
    std::shared_ptr<SampleInterface> createSampleInterface()
    {
        std::unique_lock<std::mutex> lock(g_lock);
        if (g_ifaceCount >= 1)
            return nullptr;

        g_ifaceCount++;
        return std::make_shared<SampleInterface>();
    }
}

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