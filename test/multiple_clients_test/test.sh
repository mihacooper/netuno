#!/bin/bash

testf_log "Client creation"
testf_generate_cpp sample client
testf_compile sample_client $TEST_DIR/client_main.cpp sample.cpp
testf_log "Client has been created"

testf_log "Server generation"
testf_generate_cpp sample server

testf_log "Modify server header"
patch < $TEST_DIR/server_patch

testf_log "Server comilation"
testf_compile sample_server $TEST_DIR/server_main.cpp sample.cpp
testf_log "Server has been created"


testf_log "Run server"
./sample_server &
SERVER_PID=$!
testf_assert [ $SERVER_PID -gt 0 ]
sleep 0.5

CLIENTS_NUM=1
testf_log "Run $CLIENTS_NUM clients"
for ind in $(seq 1 $CLIENTS_NUM); do
    ./sample_client &
    CLIENT_PID[$ind]=$!
    echo "CLIENT PID ${CLIENT_PID[$ind]}"
    testf_assert [ ${CLIENT_PID[$ind]} -gt 0 ]
done

testf_log "Wait for client comletion"
for ind in $(seq 1 $CLIENTS_NUM); do
    testf_assert wait ${CLIENT_PID[$ind]}
done

testf_log "Wait for server comletion"
testf_assert wait $SERVER_PID
exit 0