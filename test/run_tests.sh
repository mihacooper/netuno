#!/bin/bash

USE_INSTALL=true

TEST_MASK=$1
if [ "$TEST_MASK" == "" ]; then
    TEST_MASK=".*"
fi

export ROOT_DIR="$(cd $(dirname $0); pwd)"
export WORK_DIR="$ROOT_DIR/work_dir"
if $USE_INSTALL; then
    export SDK_DIR="$WORK_DIR/sdk"
else
    export SDK_DIR="$ROOT_DIR/../src"
fi
export LUA_RPC_SDK=$SDK_DIR

if ! [ -d $WORK_DIR ]; then
    mkdir $WORK_DIR
fi

if ! [ -d $SDK_DIR ]; then
    mkdir $SDK_DIR
fi

$USE_INSTALL && sh $ROOT_DIR/../install.sh $SDK_DIR

export CLR_RED='\033[0;31m'
export CLR_GREEN='\033[0;32m'
export CLR_NONE='\033[0m'

function testf_log() {
    echo -e "[$(date +'%8T.%3N')] $@"
}

function testf_tlog()
{
    read LINE
    while ! [ "$LINE" == "" ]; do
        testf_log $LINE
        read LINE
    done
}

function testf_err() {
    testf_log "${CLR_RED}$@${CLR_NONE}"
}

function testf_ok() {
    testf_log "${CLR_GREEN}$@${CLR_NONE}"
}

function testf_assert()
{
    $@ || { testf_log "${CLR_RED}[  ASSERT   ]${CLR_NONE} '$@'"; exit 1; }
}

function testf_expect()
{
    $@ || testf_log "[  EXPECT   ] '$@'"
}

export -f testf_log
export -f testf_err
export -f testf_ok
export -f testf_assert

echo "[############] Start time: $(date +'%D %T.%3N')"

for test_suite in $(find . -name "*_test" -type d  -printf "%f\n"); do
    SUITE_HAS_ERROR=false
    testf_log "----------------------------------------------"
    testf_log "[   START   ] $test_suite test suite"
    cd $test_suite
    export TEST_DIR=$PWD
    for test_case in $(find . -name 'test_*.sh' -type f  -printf "%f\n"); do
        # Filter tests
        echo "$test_suite.$test_case" | grep "$TEST_MASK" >/dev/null 2>&1 || continue

        # Run test
        testf_log "[   START   ] $test_suite.$test_case test case"
        bash -e $test_case
        if [ $? == 0 ]; then
            testf_ok "[  SUCCESS  ] $test_suite.$test_case"
        else
            SUITE_HAS_ERROR=true
            testf_err "[  FAILED   ] $test_suite.$test_case"
        fi
        #rm -r $WORK_DIR/* 2>/dev/null
    done
    cd ..
    if $SUITE_HAS_ERROR; then
        testf_err "[  FAILED   ] $test_suite"
    else
        testf_ok "[  SUCCESS  ] $test_suite"
    fi
done

testf_log "----------------------------------------------"
echo "[############] Finish time: $(date +'%D %T.%3N')"
