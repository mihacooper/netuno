#!/bin/bash

function checkfile()
{
    if [ ! -f $1 ]; then
        echo "File '$1' not found!"
    fi
}

cd ../
cp ./test/sample.lua ./
./main.lua sample SampleInterface cpp src
checkfile "sample.cpp" "sample.h"
mv sample.cpp ./test/
mv sample.h ./test/

cd ./test/
g++ main.cpp sample.cpp -I../LuaBridge -I/usr/include/lua5.2 -llua5.2 -o sample

