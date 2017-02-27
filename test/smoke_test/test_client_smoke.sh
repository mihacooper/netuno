#!/bin/bash

cd $WORK_DIR
cp $TEST_DIR/sample.lua .

lua $SDK_DIR/rpc.lua $TEST_DIR/sample.lua cpp client
testf_assert [ -f "sample.cpp" ]
testf_assert [ -f "sample.hpp"   ]

testf_assert g++ -std=c++14 \
    $TEST_DIR/client_main.cpp sample.cpp \
    -I/usr/include/lua5.2 -I$SDK_DIR -I$WORK_DIR \
    -llua5.2 -o sample

testf_assert ./sample
