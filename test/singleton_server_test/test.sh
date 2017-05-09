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
