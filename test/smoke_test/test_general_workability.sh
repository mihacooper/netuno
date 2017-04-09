#!/bin/bash

cd $WORK_DIR
cp $TEST_DIR/sample.lua .

testf_log "Client creation"

lua $SDK_DIR/rpc.lua $TEST_DIR/sample.lua cpp client
testf_assert [ -f "sample.cpp" ]
testf_assert [ -f "sample.hpp"   ]

testf_assert g++ -pthread -std=c++14 \
    $TEST_DIR/client_main.cpp sample.cpp \
    -I/usr/include/lua5.2 -I$SDK_DIR -I$WORK_DIR \
    -llua5.2 -o sample_client

testf_log "Client has been created"

testf_log "Server creation"

lua $SDK_DIR/rpc.lua $TEST_DIR/sample.lua cpp server
testf_assert [ -f "sample.cpp" ]
testf_assert [ -f "sample.hpp"   ]

testf_assert g++ -pthread -std=c++14 \
    $TEST_DIR/server_main.cpp sample.cpp \
    -I/usr/include/lua5.2 -I$SDK_DIR -I$WORK_DIR \
    -llua5.2 -o sample_server

testf_log "Server has been created"


testf_log "Run server"
./sample_server &
SERVER_PID=$!
testf_assert [ $SERVER_PID -gt 0 ]

testf_log "Run client"
./sample_client &
CLIENT_PID=$!
testf_assert [ $CLIENT_PID -gt 0 ]

testf_log "Wait for client comletion"
testf_assert wait $CLIENT_PID

testf_log "Kill server"
ps -p $SERVER_PID > /dev/null && kill -KILL $SERVER_PID
exit 0