#!/bin/bash

set -e

testf_log "Client creation"
testf_generate_cpp sample client
testf_compile sample_client $TEST_DIR/client_main.cpp sample-client.cpp
testf_log "Client has been created"

testf_log "Server generation"
testf_generate_cpp sample server

testf_log "Server compilation"
testf_compile sample_server $TEST_DIR/server_main.cpp sample-server.cpp
testf_log "Server has been created"

testf_log "Run server"
./sample_server &
SERVER_PID=$!
testf_assert [ $SERVER_PID -gt 0 ]
testf_log "Server PID = $SERVER_PID"
sleep 1

testf_log "Run client"
./sample_client &
CLIENT_PID=$!
testf_assert [ $CLIENT_PID -gt 0 ]
testf_log "Client PID = $CLIENT_PID"

testf_log "Wait for client completion"
testf_assert wait $CLIENT_PID

testf_log "Wait for server completion"
testf_assert wait $SERVER_PID
