#!/bin/sh

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


ROOT_DIR="$(cd $(dirname $0); pwd)"
WORK_DIR=$ROOT_DIR/work_dir

# 1. Lua socket
cd $ROOT_DIR/externals/luasocket
make -j4 LUAV=5.2 LUAINC_linux=/usr/include/lua5.2
make install LUAV=5.2 \
    LUAINC_linux=/usr/include/lua5.2 \
    DESTDIR=$WORK_DIR/socket \
    CDIR=lib \
    LDIR=modules \
    prefix=""

cd $ROOT_DIR

# 2. Bind sources
lua $ROOT_DIR/externals/luacc/bin/luacc.lua \
    -o $DEST_DIR/loader.lua \
    -i $ROOT_DIR -i $ROOT_DIR/src \
    loader helpers dsl \
    template.lib.resty.template \
    lang-cpp.binding

# 3.
cp -r $ROOT_DIR/src/main.lua $DEST_DIR/rpc.lua
mkdir $DEST_DIR/externals 2>/dev/null
mkdir $DEST_DIR/externals/sol2 2>/dev/null
cp -r $ROOT_DIR/src/lang-cpp/sol2/single/sol/sol.hpp $DEST_DIR/externals/sol2

mkdir $DEST_DIR/externals/socket 2>/dev/null
cp -r $WORK_DIR/socket/lib/* $DEST_DIR/externals/socket
cp -r $WORK_DIR/socket/modules/* $DEST_DIR/externals/socket

#rm -rf $WORK_DIR
