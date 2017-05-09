#include <iostream>
#include "sample-client.hpp"

using namespace rpc_sdk;

#define CHECK_FUNC(f, res) \
    { \
        auto got = (f); \
        if ( ! (got == res)) {\
            std::cout << "Error: " << #f << " returns " << got << ", but '" \
                << res << "' expected" << std::endl; \
            return_code = 1; \
        } \
    }

int main()
{
    srand(time(0));
    Initialize();
    RRInterface interface;

    std::string user("world");
    size_t start = time(0);
    for (size_t i = 0; i < 500000; ++i)
    {
        std::string reply = interface.Send(user + std::to_string(rand() % 32000));
        std::cout << "Client received: " << reply << std::endl;
    }
    std::cout << "Time = " << time(0) - start << std::endl;

    Uninitialize();
    return 0;
}