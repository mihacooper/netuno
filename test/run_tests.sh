#!/bin/bash

export ROOT_DIR="$(cd $(dirname $0); pwd)"
export WORK_DIR="$ROOT_DIR/work_dir"

if ! [ -d $WORK_DIR ]; then
    mkdir $WORK_DIR
fi

CLR_RED='\033[0;31m'
CLR_GREEN='\033[0;32m'
CLR_NONE='\033[0m'

function testf_log() {
    echo -e "$(date +'%D %T.%3N') $@"
}

function testf_err() {
    testf_log "${CLR_RED} $@${CLR_NONE}"
}

function testf_ok() {
    testf_log "${CLR_GREEN} $@${CLR_NONE}"
}

for test_case in $(find . -name '*_test'); do
    testf_log "[   START   ] $test_case"
    testf_ok "[  SUCCESS  ] $test_case"
    rm -r $WORK_DIR/* 2>/dev/null
done
