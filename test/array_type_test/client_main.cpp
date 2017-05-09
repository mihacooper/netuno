#include <iostream>
#include "sample-client.hpp"

using namespace rpc_sdk;

int return_code = 0;

std::ostream& operator <<(std::ostream& s, const std::vector<int>& vec)
{
    s << "{ ";
    for(auto val: vec)
        s << val << ", ";
    s << " }";
    return s;
}

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
    Initialize();
    ArrayTransmitter interface;

    const std::vector<int> v1{99, 22, 39, 908, 2, 354, 245, 1};
    const std::vector<int> v2{45, 56, 23, 4, 53, 22, 345, 32, 567};
    const std::vector<int> v3{67, 233, 3423, 323, 4567, 56, 34, 3456, 567};

    interface.Send(v1);
    interface.Send(v2);

    CHECK_FUNC(interface.Receive(1), v2);
    CHECK_FUNC(interface.Receive(0), v1);

    interface.Send(v3);

    CHECK_FUNC(interface.Receive(2), v3);
    CHECK_FUNC(interface.Receive(1), v2);
    CHECK_FUNC(interface.Receive(0), v1);

    interface.FinishTest();

    Uninitialize();
    return return_code;
}