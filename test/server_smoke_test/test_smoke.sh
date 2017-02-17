#!/bin/bash

#!/bin/bash

cd $WORK_DIR
cp $TEST_DIR/sample.lua .

$SDK_DIR/main.lua $TEST_DIR/sample.lua SampleInterface cpp server
testf_assert [ -f "SampleInterface.cpp" ]
testf_assert [ -f "SampleInterface.h"   ]
testf_assert [ -f "SampleStructure.cpp" ]
testf_assert [ -f "SampleStructure.h"   ]

testf_assert g++ $TEST_DIR/server_main.cpp SampleInterface.cpp SampleStructure.cpp -I$PWD -I../../LuaBridge -I/usr/include/lua5.2 -llua5.2 -o sample

testf_assert ./sample
