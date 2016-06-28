#!/bin/bash

function checkfile()
{
    if [ ! -f $1 ]; then
        echo "File '$1' not found!"
    fi
}

export LUA_RPC_SDK="$PWD/.."
../main.lua sample SampleInterface cpp server
checkfile "SampleInterface.cpp"
checkfile "SampleInterface.h"
checkfile "SampleStructure.cpp"
checkfile "SampleStructure.h"

g++ server_main.cpp SampleInterface.cpp SampleStructure.cpp -I../LuaBridge -I/usr/include/lua5.2 -llua5.2 -o sample
./sample
