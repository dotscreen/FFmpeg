#!/bin/bash

SCRIPT_PATH="`dirname \"$0\"`"
SCRIPT_PATH="`( cd \"${SCRIPT_PATH}\" && pwd )`"
export PATH="${SCRIPT_PATH}/gas-preprocessor:${PATH}"

shopt -s extglob
XCODE_HOME=$(xcode-select --print-path)

if [[ -z $XCODE_HOME ]]; then 
    echo "Could not find the XCode Command Line Tools required by this script"
    exit 1
elif [[ ! -x $XCODE_HOME ]]; then
    echo "Could not find the XCode Command Line Tools in ${XCODE_HOME}"
    exit 1
fi

modules="libavcodec libavdevice libavformat libavutil libswscale"

TARGET_PATH="$SCRIPT_PATH"
mkdir -p "$TARGET_PATH"
for lib in $modules; do
    rm ${TARGET_PATH}/${lib}*.a > /dev/null 2>&1
done

function build_arch() {
    arch=$1
    vers=$2
    arch_code=$3
    arch_options=$4

    PLATFORM_HOME=${XCODE_HOME}/Platforms/${arch}.platform
    SDK_HOME=(${PLATFORM_HOME}/Developer/SDKs/${arch}${vers}.sdk)
    TOOLS_PATH=${PLATFORM_HOME}/Developer/usr/bin/
    EXTRA_FLAGS="-arch ${arch_code} -isysroot ${SDK_HOME}"

    echo "SDK $arch: $SDK_HOME"
    make distclean > /dev/null 2>&1
    ./configure --prefix=${arch_code} --cross-prefix=${TOOLS_PATH} $FFMPEG_GENERAL_OPTIONS $arch_options --sysroot=${SDK_HOME} "--extra-cflags=${EXTRA_FLAGS}" "--extra-ldflags=${EXTRA_FLAGS}" "--as='gas-preprocessor/gas-preprocessor.pl ${TOOLS_PATH}/gcc'"
    make -j3 || exit 1
    make install

#for lib in $modules; do
#        mv "${lib}/${lib}.a" "${TARGET_PATH}/${lib}-${arch_code}.a"
#    done
}

function package_lib() {
    for lib in $modules; do
        args=""
        for arch in i386 armv7 armv7s; do
            args="${args} -arch ${arch} ${TARGET_PATH}/${arch}/lib/${lib}.a"
        done
        xcrun -sdk iphoneos lipo -create $args -output "${TARGET_PATH}/universal/lib/$lib.a"
    done
}


FFMPEG_SIMULATOR_GCC="${XCODE_HOME}/Platforms/iPhoneOS.platform/Developer/usr/bin/gcc"

FFMPEG_GENERAL_OPTIONS="--enable-cross-compile --target-os=darwin --enable-pic"
FFMPEG_GENERAL_OPTIONS="${FFMPEG_GENERAL_OPTIONS} --disable-doc --disable-ffmpeg --disable-encoders --disable-ffplay --disable-ffprobe --disable-ffserver --disable-swresample --disable-avfilter --disable-postproc"
FFMPEG_GENERAL_OPTIONS="${FFMPEG_GENERAL_OPTIONS} --disable-debug --disable-asm"

build_arch iPhoneSimulator 6.1 i386 "--arch=i386"
build_arch iPhoneOS 6.1 armv7 "--cpu=cortex-a8 --arch=arm"
build_arch iPhoneOS 6.1 armv7s "--cpu=cortex-a9 --arch=arm"

package_lib

