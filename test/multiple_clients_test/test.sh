#!/bin/bash

set -e

testf_log "Server generation"
testf_generate_cpp sample server

testf_log "Modify server header"
patch < $TEST_DIR/server_patch

testf_log "Server comilation"
testf_compile sample_server $TEST_DIR/server_main.cpp sample-server.cpp
testf_log "Server has been created"

testf_log "Client creation"
testf_generate_cpp sample client
testf_compile sample_client $TEST_DIR/client_main.cpp sample-client.cpp
testf_log "Client has been created"


testf_log "Run server"
./sample_server &> >(tee $WORK_DIR/server.log) &
SERVER_PID=$!
testf_log "Server PID = $SERVER_PID"
testf_assert [ $SERVER_PID -gt 0 ]
sleep 0.5

CLIENTS_NUM=1
testf_log "Run $CLIENTS_NUM clients"
for ind in $(seq 1 $CLIENTS_NUM); do
    ./sample_client &> >(tee $WORK_DIR/client-$ind.log) &
    CLIENT_PID[$ind]=$!
    testf_log "Client PID = ${CLIENT_PID[$ind]}"
    testf_assert [ ${CLIENT_PID[$ind]} -gt 0 ]
done

RETURN_CODE=0
testf_log "Wait for client completion"
for ind in $(seq 1 $CLIENTS_NUM); do
    testf_log "Wait for client PID = ${CLIENT_PID[$ind]}"
    wait ${CLIENT_PID[$ind]} || { testf_error "Client #$ind (PID=${CLIENT_PID[$ind]}) returns error"; RETURN_CODE=1; }
    testf_log "Client ${CLIENT_PID[$ind]} has finished"
done
testf_log "All clients were finished"

testf_log "Wait for server completion"
wait $SERVER_PID || { testf_error "Server $SERVER_PID returns error"; RETURN_CODE=1; }
testf_log "Server has finished"

exit $RETURN_CODE