#include <iostream>
#include "sample-client.hpp"

using namespace rpc_sdk;

bool operator ==(const SampleStructure& left, const SampleStructure& right)
{
    return left.field1 == right.field1 && left.field2 == right.field2;
}

std::ostream& operator <<(std::ostream& s, const SampleStructure& str)
{
    return s << "{ " << str.field1 << ", "<< str.field2 << " }";
}

int return_code = 0;

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
    SampleInterface interface;

    bool extra_client_code = false;
    try {
        SampleInterface dummy;
    }
    catch (const sol::error& err)
    {
        std::cout << "Client got exception: " << err.what() << std::endl;
        extra_client_code = true;
    }
    CHECK_FUNC(extra_client_code, true);

    SampleStructure str{76, "oprst"};
    CHECK_FUNC(interface.MyFunction1(10, 12), (SampleStructure{10,"12"}));
    CHECK_FUNC(interface.MyFunction2(str, "string"), str.field1);
    interface.MyFunction3(10); // return nothing, so just call it
    CHECK_FUNC(interface.MyFunction4(), "return string");
    interface.MyFunction5("This is message");
    interface.FinishTest();
    Uninitialize();
    return return_code;
}