#include <iostream>
#include "sample-server.hpp"
#include "atomic"

using namespace rpc_sdk;

std::vector<std::vector<int>> g_storage;

ArrayTransmitter::ArrayTransmitter() {}

ArrayTransmitter::~ArrayTransmitter() {}

void ArrayTransmitter::Send(std::vector<int> in)
{
    g_storage.push_back(in);
}

std::vector<int> ArrayTransmitter::Receive(int id)
{
    if (id < 0 || id >= g_storage.size())
        throw sol::error("Invalid ID required: " + std::to_string(id));
    return g_storage[id];
}

volatile std::atomic_bool g_stopProc(false);

void ArrayTransmitter::FinishTest()
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