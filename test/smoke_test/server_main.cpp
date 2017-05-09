#include <iostream>
#include "sample-server.hpp"
#include "atomic"

using namespace rpc_sdk;

std::mutex g_lock;
volatile size_t g_ifaceCount = 0;
volatile bool g_returnCode = true;

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
    std::unique_lock<std::mutex> lock(g_lock);
    if (param1 != 10)
    {
        g_returnCode = false;
        std::cout << "SampleInterface::MyFunction3 received invalid 'param1' value == " << param1
            << ", '10' expected" << std::endl;
    }
}

std::string SampleInterface::MyFunction4()
{
    return "return string";
}

void SampleInterface::MyFunction5(std::string msg)
{
    std::unique_lock<std::mutex> lock(g_lock);
    std::cout << "SampleInterface::MyFunction5 received: " << msg << std::endl;
    if (msg != "This is message")
    {
        g_returnCode = false;
        std::cout << "SampleInterface::MyFunction5 received invalid 'msg' == '" << msg
            << "', 'This is message' expected" << std::endl;
    }
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
    return g_returnCode ? 0 : 1;
}