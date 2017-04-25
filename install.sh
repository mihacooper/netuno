#!/bin/sh
set -e

ROOT_DIR="$(cd $(dirname $0); pwd)"

<<"COMMENT"
WORK_DIR=$ROOT_DIR/.build_dir
LOG_FILE=$WORK_DIR/.log
HELP_MSG="install.sh <dst directory>"
DEST_DIR=$1

if [ -z "$DEST_DIR" ]; then
    echo $HELP_MSG
    exit 1
fi

if ! [ -d $DEST_DIR ]; then
    echo "Destination directory does not exist: $DEST_DIR"
    exit 1
fi

export CLR_RED='\033[0;31m'
export CLR_GREEN='\033[0;32m'
export CLR_NONE='\033[0m'

log() {
    echo "[$(date +"%Y:%m:%d %H:%M:%S")] $@"
}

log_success() {
    echo -n "${CLR_GREEN}"
    log $@
    echo -n "${CLR_NONE}"
}

log_failure() {
    echo -n "${CLR_RED}"
    log $@
    echo -n "${CLR_NONE}"
}

log_lines() {
    echo $(wc -l $LOG_FILE | sed -r "s/([0-9]+) .+/\1/")
}

log_print_error() {
    log_failure "FAILED:"
    LINE_TO_PRINT=$(( $(log_lines) - $LAST_LOG_LINE ))
    tail "-$LINE_TO_PRINT" $LOG_FILE
    exit 1
}

echo "" > $LOG_FILE

LAST_LOG_LINE=0
log_success "#1 Building Lua socket"
{
COMMENT

    cd $ROOT_DIR/externals/luasocket
    make -j4 LUAV=5.2 LUAINC_linux=/usr/include/lua5.2 &&
    make install LUAV=5.2 \
        LUAINC_linux=/usr/include/lua5.2 \
        DESTDIR=$ROOT_DIR/externals/luasocket_build \
        CDIR=lib \
        LDIR=modules \
        prefix=""

<<"COMMENT"
} >> $LOG_FILE 2>&1 || log_print_error

LAST_LOG_LINE=$(log_lines)
log_success "#2 Building Effil"
{
    mkdir $WORK_DIR/effil
    cd $WORK_DIR/effil
COMMENT

    mkdir $ROOT_DIR/externals/effil/build || true
    cd $ROOT_DIR/externals/effil/build
    cmake .. -DCMAKE_BUILD_TYPE=Release &&
    make -j4 && make install

<<"COMMENT"
} >> $LOG_FILE 2>&1 || log_print_error

LAST_LOG_LINE=$(log_lines)
log_success "#3 Bind lua sources"
{
    cd $ROOT_DIR
    lua $ROOT_DIR/externals/luacc/bin/luacc.lua -o $DEST_DIR/loader.lua \
        -i $ROOT_DIR -i $ROOT_DIR/src -i $ROOT_DIR/externals \
        -i $WORK_DIR/socket/modules -i $ROOT_DIR/externals/json/json \
        loader helpers dsl networking \
        template.lib.resty.template \
        lang-cpp.binding \
        socket json
} >> $LOG_FILE 2>&1 || log_print_error

LAST_LOG_LINE=$(log_lines)
log_success "#4 Copy to destination directory"
{
    mkdir $DEST_DIR/sol2 2>/dev/null
    mkdir $DEST_DIR/socket 2>/dev/null
    mkdir $DEST_DIR/effil 2> /dev/null
    cp $ROOT_DIR/src/storage.lua $DEST_DIR/ &&
    cp $ROOT_DIR/src/rpc.lua $DEST_DIR/ &&
    cp $ROOT_DIR/externals/argparse/src/argparse.lua $DEST_DIR/ &&
    cp $ROOT_DIR/src/lang-cpp/sol2/single/sol/sol.hpp $DEST_DIR/sol2 &&
    cp $WORK_DIR/effil/libeffil.so $DEST_DIR/effil/ &&
    cp $WORK_DIR/effil/effil.lua $DEST_DIR/effil/ &&
    cp -r $WORK_DIR/socket/lib/socket/* $DEST_DIR/socket
} >> $LOG_FILE 2>&1 || log_print_error
COMMENT