#!/bin/bash

function checkfile()
{
    if [ ! -f $1 ]; then
        echo "File '$1' not found!"
    fi
}

export LUA_RPC_SDK="$PWD/.."
../main.lua sample SampleInterface cpp server
checkfile "sample.cpp"
checkfile "sample.h"

g++ server_main.cpp sample.cpp -I../LuaBridge -I/usr/include/lua5.2 -llua5.2 -o sample
./sample
