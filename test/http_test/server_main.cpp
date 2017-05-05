#include <map>
#include <iostream>
#include "sample-server.hpp"

using namespace rpc_sdk;

bool g_makeStop = false;
HttpInterface::HttpInterface() {}

HttpInterface::~HttpInterface() {}

std::string HttpInterface::stop()
{
    g_makeStop = true;
    return "Server going to shutdown";
}

std::string HttpInterface::get_info(std::string field, int time)
{
    static const std::string unknownMess = "Unknown field or time";
    static std::map<std::string, std::map<int, std::string>> fields{
        std::make_pair<std::string, std::map<int, std::string>>(
            "help", {
                std::make_pair<int, std::string>(1, "help information at 1"),
                std::make_pair<int, std::string>(2, "help information at 2"),
                std::make_pair<int, std::string>(3, "help information at 3"),
                std::make_pair<int, std::string>(4, "help information at 4"),
                std::make_pair<int, std::string>(5, "help information at 5")
            }
        ),
        std::make_pair<std::string, std::map<int, std::string>>(
            "home", {
                std::make_pair<int, std::string>(1, "home information at 1"),
                std::make_pair<int, std::string>(2, "home information at 2"),
                std::make_pair<int, std::string>(3, "home information at 3"),
                std::make_pair<int, std::string>(4, "home information at 4"),
                std::make_pair<int, std::string>(5, "home information at 5")
            }
        ),
        std::make_pair<std::string, std::map<int, std::string>>(
            "version", {
                std::make_pair<int, std::string>(1, "version information at 1"),
                std::make_pair<int, std::string>(2, "version information at 2"),
                std::make_pair<int, std::string>(3, "version information at 3"),
                std::make_pair<int, std::string>(4, "version information at 4"),
                std::make_pair<int, std::string>(5, "version information at 5")
            }
        )
    };

    if (fields.find(field) == fields.end() || fields[field].find(time) == fields[field].end())
        return unknownMess;
    return fields[field][time];
}

int main()
{
    Initialize();
    while(!g_makeStop) { std::this_thread::sleep_for(std::chrono::seconds(5)); };
    Uninitialize();
}