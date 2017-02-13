#!/bin/bash

function checkfile()
{
    if [ ! -f $1 ]; then
        echo "File '$1' not found!"
    fi
}

ROOT_DIR="$(cd $(dirname $0); pwd)"
export LUA_RPC_SDK="$ROOT_DIR/../src"

cd $ROOT_DIR
if ! [ -d work_dir ]; then
    mkdir work_dir
fi
cd work_dir

$LUA_RPC_SDK/main.lua ../sample.lua SampleInterface cpp server
checkfile "SampleInterface.cpp"
checkfile "SampleInterface.h"
checkfile "SampleStructure.cpp"
checkfile "SampleStructure.h"

g++ ../server_main.cpp SampleInterface.cpp SampleStructure.cpp -I$PWD -I../../LuaBridge -I/usr/include/lua5.2 -llua5.2 -o sample

cp ../sample.lua .
./sample
