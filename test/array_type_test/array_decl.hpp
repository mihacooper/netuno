#include <vector>

namespace array_t
{
    inline sol::object ArrayToLuaObject(sol::state_view state, const std::vector<int>& input)
    {
        sol::table output = state.create_table();
        for(size_t i = 0; i < input.size(); ++i)
            output[i + 1] = input[i];
        return output;
    }

    inline std::vector<int> ArrayFromLuaObject(const sol::table& input)
    {
        if (!input.valid())
        {
            throw sol::error("Unable to parse invalid table to std::vector");
        }
        std::vector<int> output;
        for(size_t i = 1; i <= input.size(); ++i)
            output.push_back(input[i]);
        return output;
    }
};
