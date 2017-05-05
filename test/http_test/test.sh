#!/bin/bash

set -e

testf_log "Server creation"
testf_generate_cpp sample server
testf_compile sample_server $TEST_DIR/server_main.cpp sample-server.cpp
testf_log "Server has been created"

testf_log "Run server"
./sample_server &
SERVER_PID=$!
testf_assert [ $SERVER_PID -gt 0 ]
testf_log "Server PID = $SERVER_PID"
sleep 0.5

function make_request()
{
    REQ_PATH=$1
    EXP_RESULT=$2
    EXP_STRING=$3

    RET_STR=$(curl -s "localhost:9898${REQ_PATH}")
    RET_CODE=$?
    [ $RET_CODE -eq $EXP_RESULT ] || testf_error "Return code is not $EXP_RESULT"
    if ! [ "$EXP_STRING" == "" ]; then
        [ "$RET_STR" == "$EXP_STRING" ] || testf_error "Invalid server response: $RET_STR"
    fi
}

for field in 'home' 'help' 'version'; do
    for time in 1 2 3 4 5; do
        make_request "/HttpInterface/get_info?field=$field&time=$time" 0 "${field} information at ${time}"
    done
done

make_request "/HttpInterface/stop" 0

testf_log "Waiting server process completion..."
wait $SERVER_PID || testf_error "Server process return code is not 0"
