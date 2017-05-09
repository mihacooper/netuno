#include <iostream>
#include "sample-server.hpp"
#include "atomic"

using namespace rpc_sdk;

RRInterface::RRInterface() {}

RRInterface::~RRInterface() {}

std::string RRInterface::Send(std::string msg)
{
    static std::string hello("Hello ");
    return hello + msg;
}

int main()
{
    Initialize();
    while(true)
    {
        std::this_thread::sleep_for(std::chrono::seconds(30));
    };
    Uninitialize();
}