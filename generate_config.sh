#!/bin/bash -e
#
#Copyright (C) 2018 The Android Open Source Project
#
#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#Unless required by applicable law or agreed to in writing, software
#distributed under the License is distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.


# This script is used to generate files in the <platform> directories needed to
# build libaom. Every time libaom source code is updated run this script.
#
# $ ./generate_config.sh
#
# And this will update all the config files needed.

BASE_DIR=$(pwd)
LIBAOM_SRC_DIR="libaom"
LIBAOM_CONFIG_DIR="config"
TEMP_DIR="$LIBAOM_SRC_DIR.temp"
ARCH_x86="x86"
ARCH_x86_64="x86_64"
ARCH_ARM="arm"
ARCH_ARM_64="arm64"

# Clean files from previous make.
function make_clean {
  make clean > /dev/null
  rm -f libaom_srcs.txt
}

# Extract a list of C sources from a libaom_srcs.txt file
# $1 - path to libaom_srcs.txt
function libaom_srcs_txt_to_c_srcs {
    ##grep "CMakeFiles" $1 | grep -v "aom_config.c"| grep -v "gen_src" | grep -v "encoder" | grep -v "mkvmuxer" | grep -v "hdr_util" | sed 's/.*dir/"libaom/' | sed 's/.o$/",/' | sort
    grep "CMakeFiles" $1 | grep -v "aom_config.c"| grep -v "gen_src" | grep -v "encoder" | grep -v "mkvmuxer" | grep -v "hdr_util" | sed 's/.*dir/        "libaom/' | sed 's/.o$/",/' | sort
}

# Convert a list of sources to a blueprint file containing a variable
# assignment.
# $1 - arch type
function gen_bp_srcs {
  (
    varprefix=libaom_${1//-/_}
    echo "${varprefix}_c_srcs = ["
    libaom_srcs_txt_to_c_srcs libaom_srcs_$1.txt
    echo "\"$LIBAOM_CONFIG_DIR/$1/$LIBAOM_CONFIG_DIR/aom_config.c\","
    echo "]"
    echo
  ) > $BASE_DIR/$TEMP_DIR/config_$1.bp
}


# Generate and copy config folder to $BASE_DIR/$LIBAOM_CONFIG_DIR/$1/$LIBAOM_CONFIG_DIR
# $1 - arch type
function libaom_gen_config {
    mkdir $LIBAOM_CONFIG_DIR/$1
    mkdir $TEMP_DIR/$1/
    cd $TEMP_DIR/$1/

    if [ $1 == $ARCH_x86_64 ]; then
        cmake $BASE_DIR/$LIBAOM_SRC_DIR -DCONFIG_AV1_ENCODER=0 -DCONFIG_LOWBITDEPTH=0 -DCONFIG_LIBYUV=0 -DCMAKE_BUILD_TYPE=Release -DCMAKE_SH="CMAKE_SH-NOTFOUND" -G "Unix Makefiles" -DENABLE_AVX=0 -DENABLE_AVX2=0 -DENABLE_SSE4_1=0 -DENABLE_SSE4_2=0 -DENABLE_SSSE3=0 -DENABLE_SSE3=0 > /dev/null
        make aom aom_common_app_util aom_decoder_app_util > libaom_srcs_$1.txt

    elif [ $1 == $ARCH_x86 ]; then
        cmake $BASE_DIR/$LIBAOM_SRC_DIR -DCONFIG_AV1_ENCODER=0 -DCONFIG_LOWBITDEPTH=0 -DCONFIG_LIBYUV=0 -DCMAKE_BUILD_TYPE=Release -DCMAKE_SH="CMAKE_SH-NOTFOUND" -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE=$BASE_DIR/$LIBAOM_SRC_DIR/build/cmake/toolchains/x86-linux.cmake -DENABLE_AVX=0 -DENABLE_AVX2=0 -DENABLE_SSE4_1=0 -DENABLE_SSE4_2=0 -DENABLE_SSSE3=0 -DENABLE_SSE3=0
        make aom aom_common_app_util aom_decoder_app_util > libaom_srcs_$1.txt

    elif [ $1 == $ARCH_ARM ]; then
        cmake $BASE_DIR/$LIBAOM_SRC_DIR -DCONFIG_AV1_ENCODER=0 -DCONFIG_LOWBITDEPTH=0 -DCONFIG_LIBYUV=0 -DCMAKE_BUILD_TYPE=Release -DCMAKE_SH="CMAKE_SH-NOTFOUND" -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE=$BASE_DIR/$LIBAOM_SRC_DIR/build/cmake/toolchains/armv7-linux-gcc.cmake -DCROSS=arm-linux-gnueabihf-
        make aom aom_common_app_util aom_decoder_app_util webm > libaom_srcs_$1.txt

    elif [ $1 == $ARCH_ARM_64 ]; then
        cmake $BASE_DIR/$LIBAOM_SRC_DIR -DCONFIG_AV1_ENCODER=0 -DCONFIG_LOWBITDEPTH=0 -DCONFIG_LIBYUV=0 -DCMAKE_BUILD_TYPE=Release -DCMAKE_SH="CMAKE_SH-NOTFOUND" -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE=$BASE_DIR/$LIBAOM_SRC_DIR/build/cmake/toolchains/arm64-linux-gcc.cmake -DCROSS=aarch64-linux-gnu-
        make aom aom_common_app_util aom_decoder_app_util webm > libaom_srcs_$1.txt

    else
        echo "Architecture not supported."
    fi

    gen_bp_srcs $1

    rm $LIBAOM_CONFIG_DIR/*.cmake
    cp -R $LIBAOM_CONFIG_DIR $BASE_DIR/$LIBAOM_CONFIG_DIR/$1
    cd $BASE_DIR
}

# Remove the temporary directory in case it already exists and create a new temporary diretory.
if [ -d "$TEMP_DIR" ]; then
  rm -rf $TEMP_DIR
fi

mkdir $TEMP_DIR

# Remove the config folder in case it already exists and create a new config folder.
if [ -d "$LIBAOM_CONFIG_DIR" ]; then
  rm -rf $LIBAOM_CONFIG_DIR
fi

mkdir $LIBAOM_CONFIG_DIR

libaom_gen_config $ARCH_ARM_64
libaom_gen_config $ARCH_ARM
libaom_gen_config $ARCH_x86_64
libaom_gen_config $ARCH_x86

cd $BASE_DIR/$TEMP_DIR/
(
  echo "// THIS FILE IS AUTOGENERATED, DO NOT EDIT"
  echo "// Generated from Android.bp.in, run ./generate_config.sh to regenerate"
  echo
  cat config_*.bp
  cat $BASE_DIR/Android.bp.in
) > $BASE_DIR/Android.bp

cd $BASE_DIR
rm -r $BASE_DIR/$TEMP_DIR/
