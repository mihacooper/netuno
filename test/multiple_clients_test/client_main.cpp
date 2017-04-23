#include "sample.hpp"
#include <iostream>
#include <mutex>

using namespace rpc_sdk;

std::mutex g_lock;
int g_return_code = 0;
size_t g_createdIfaces = 0;

#define CHECK(f, res) \
    { \
        auto got = (f); \
        if ( ! (got == res)) {\
            std::cout << "Error: " << #f << " returns " << got << ", but '" \
                << res << "' expected" << std::endl; \
            std::unique_lock<std::mutex> lock(g_lock); \
            g_return_code = 1; \
        } \
    }

void ThreadWorker()
{
    Incrementer inc;
    {
        std::unique_lock<std::mutex> lock(g_lock);
        g_createdIfaces++;
    }
    int result = 0;
    for (size_t i = 0; i < 1000; ++i)
    {
        const int value = i * (rand() % 2 == 0 ? -1 : 1);
        result += value;
        inc.Increment(value);
    }
    CHECK(inc.Result(), result);
}

int main()
{
    srand(time(0));
    const size_t threads_num = 100;
    std::vector<std::thread> threads;

    Initialize();
    for (size_t i = 0; i < threads_num; ++i)
    {
        threads.emplace_back(std::thread(ThreadWorker));
    }

    while (g_createdIfaces != threads_num) {}

    g_return_code = 1;
    try {
        Incrementer inc;
    }
    catch (const sol::error& err)
    {
        std::cout << "Client got exception: " << err.what() << std::endl;
        g_return_code = 0;
    }
    CHECK(g_return_code, 0);

    for (auto& thr: threads)
        thr.join();

    Uninitialize();
    return g_return_code;
}