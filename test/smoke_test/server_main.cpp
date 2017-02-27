#include <iostream>
#include "sample.hpp"

using namespace rpc_sdk;

SampleInterface::SampleInterface() {}

SampleInterface::~SampleInterface() {}

SampleStructure SampleInterface::MyFunction1(int param1, int param2)
{
    return SampleStructure{};
}

int SampleInterface::MyFunction2(SampleStructure param1, std::string param2)
{
    return 0;
}

void SampleInterface::MyFunction3(int param1)
{}

std::string SampleInterface::MyFunction4()
{
    return "string";
}

int main()
{
    InitializeSdk();
}