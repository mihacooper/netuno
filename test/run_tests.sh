#!/bin/bash

USE_INSTALL=false
TEST_MASK=".*"

while [[ $# -ge 1 ]]; do
    case $1 in
        -r|--reinstall)
            export USE_INSTALL=true
            shift
        ;;
        -f|--filter)
            TEST_MASK="$2"
            shift
        ;;
        *)
          echo "Unknown option $1"
          exit 1
        ;;
    esac
    shift # past argument or value
done

export ROOT_DIR="$(cd $(dirname $0); pwd)"
export WORK_DIR="$ROOT_DIR/work_dir"
export SDK_DIR="$ROOT_DIR/../src"
export LUA_RPC_SDK="$ROOT_DIR/.."

if ! [ -d $WORK_DIR ]; then
    mkdir $WORK_DIR
fi

#if ! [ -d $SDK_DIR ]; then
#    mkdir $SDK_DIR
#fi

#$USE_INSTALL && sh $ROOT_DIR/../install.sh $SDK_DIR

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

function testf_error() {
    testf_log "${CLR_RED}[  ERROR    ]${CLR_NONE} $@"; exit 1
}

function testf_assert()
{
    $@ || { testf_log "${CLR_RED}[  ASSERT   ]${CLR_NONE} '$@'"; exit 1; }
}

function testf_expect()
{
    $@ || testf_log "[  EXPECT   ] '$@'"
}

function testf_compile()
{
    binary_name=$1; shift
    testf_assert g++ -O0 -g -pthread -std=c++14 $@ \
        -I/usr/include/lua5.2 -I$SDK_DIR/lang-cpp/sol2/single/sol -I$WORK_DIR \
        -llua5.2 -o $binary_name
}

function testf_generate_cpp()
{
    MODULE_NAME=$1
    cp $TEST_DIR/${MODULE_NAME}.lua .
    lua $SDK_DIR/rpc.lua generate "${MODULE_NAME}.lua" cpp $2 -o "${MODULE_NAME}-$2"
    testf_assert [ -f "${MODULE_NAME}-$2.cpp" ]
    testf_assert [ -f "${MODULE_NAME}-$2.hpp" ]
}

export -f testf_log
export -f testf_err
export -f testf_error
export -f testf_ok
export -f testf_assert
export -f testf_compile
export -f testf_generate_cpp

testf_log "[############] Start time: $(date +'%D %T.%3N')"

cd $WORK_DIR
for test_suite in $(find ${ROOT_DIR} -name "*_test" -type d  -printf "%f\n"); do
    SUITE_HAS_ERROR=false
    testf_log "----------------------------------------------"
    testf_ok  "[   START   ] $test_suite test suite"
    export TEST_DIR=${ROOT_DIR}/$test_suite
    for test_case in $(find ${ROOT_DIR}/${test_suite} -name "test*.sh" -type f  -printf "%f\n"); do
        # Filter tests
        echo "$test_suite.$test_case" | grep "$TEST_MASK" >/dev/null 2>&1 || continue

        # Run test
        testf_ok "[   START   ] $test_suite.$test_case test case"
        bash -e ${ROOT_DIR}/${test_suite}/$test_case &> >(tee .log)
        if [ $? == 0 ]; then
            testf_ok "[  SUCCESS  ] $test_suite.$test_case"
        else
            SUITE_HAS_ERROR=true
            testf_err "[  FAILED   ] $test_suite.$test_case"
            cp -r $WORK_DIR/ "${ROOT_DIR}/${test_suite}.$test_case.workdir"
        fi
        #rm -r $WORK_DIR/* > /dev/null 2>&1
    done
    if $SUITE_HAS_ERROR; then
        testf_err "[  FAILED   ] $test_suite"
    else
        testf_ok "[  SUCCESS  ] $test_suite"
    fi
done

testf_log "----------------------------------------------"
echo "[############] Finish time: $(date +'%D %T.%3N')"
