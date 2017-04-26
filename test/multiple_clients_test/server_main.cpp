#include <iostream>
#include "sample.hpp"
#include "atomic"
#include "csignal"
#include "mutex"

rpc_sdk::Incrementer::Incrementer() {}
rpc_sdk::Incrementer::~Incrementer() {}
void rpc_sdk::Incrementer::Increment(int) {}
int rpc_sdk::Incrementer::Result() { return 0; }

class IncrementerWithState : public rpc_sdk::Incrementer
{
public:
    IncrementerWithState() : m_count(0) {}

    void Increment(int value) final
    {
        m_count += value;
    }

    int Result() final
    {
        return m_count;
    }

protected:
    int m_count;
};

std::mutex g_lock;
const size_t g_maxSlavesNum = 100;
std::vector<std::shared_ptr<IncrementerWithState> > g_slaves;

namespace rpc_sdk
{
    std::shared_ptr<Incrementer> createIncrementer()
    {
        std::unique_lock<std::mutex> lock(g_lock);
        if (g_slaves.size() == g_maxSlavesNum)
            return nullptr;
        auto ptr = std::make_shared<IncrementerWithState>();
        g_slaves.push_back(ptr);
        return std::dynamic_pointer_cast<Incrementer>(ptr);
    }
}

using namespace rpc_sdk;

int main()
{
    Initialize();
    bool doExit = false;
    while (!doExit || g_slaves.size() != g_maxSlavesNum)
    {
        {
            std::unique_lock<std::mutex> lock(g_lock);
            doExit = true;
            for (auto& slave: g_slaves)
            {
                doExit = doExit && slave.use_count() == 1;
            }
        }
        std::this_thread::sleep_for(std::chrono::seconds(1));
    }
    Uninitialize();
}