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

# 2. Effil building
mkdir $WORK_DIR/effil_build
cd $WORK_DIR/effil_build
cmake $ROOT_DIR/externals/effil -DCMAKE_BUILD_TYPE=Debug
make -j4 && make install
mkdir $DEST_DIR/externals/effil 2> /dev/null
cp $WORK_DIR/effil_build/libeffil.so $DEST_DIR/externals/effil
cp $WORK_DIR/effil_build/effil.lua $DEST_DIR/externals/effil

# 3. Bind sources
cd $ROOT_DIR

lua $ROOT_DIR/externals/luacc/bin/luacc.lua \
    -o $DEST_DIR/loader.lua \
    -i $ROOT_DIR -i $ROOT_DIR/src -i $ROOT_DIR/externals -i $DEST_DIR/externals/effil \
    -i $WORK_DIR/socket/modules -i $ROOT_DIR/externals/json/json \
    loader helpers dsl networking effil \
    template.lib.resty.template \
    lang-cpp.binding \
    socket json

# 4. Copy other resources
cp -r $ROOT_DIR/src/rpc.lua $DEST_DIR/
mkdir $DEST_DIR/externals 2>/dev/null
mkdir $DEST_DIR/externals/sol2 2>/dev/null
cp -r $ROOT_DIR/src/lang-cpp/sol2/single/sol/sol.hpp $DEST_DIR/externals/sol2

mkdir $DEST_DIR/externals/socket 2>/dev/null
cp -r $WORK_DIR/socket/lib/socket/* $DEST_DIR/externals/socket

#rm -rf $WORK_DIR
