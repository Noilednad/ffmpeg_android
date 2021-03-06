#!/bin/bash
#
#

TARGET=`pwd`/build/ffmpeg #&& rm -rf $TARGET
SOURCE=`pwd`/
ANDROID_NDK=/root/junz/android-ndk-r9b
TOOLCHAIN=/tmp/ffmpeg
SYSROOT=$TOOLCHAIN/sysroot/
$ANDROID_NDK/build/tools/make-standalone-toolchain.sh --platform=android-14 --install-dir=$TOOLCHAIN --toolchain=arm-linux-androideabi-4.6


export PATH=$TOOLCHAIN/bin:$PATH
export CC=arm-linux-androideabi-gcc
export LD=arm-linux-androideabi-ld
export AR=arm-linux-androideabi-ar

CFLAGS="-O3 -Wall -pipe -fpic -fasm \
  -finline-limit=300 -ffast-math \
  -fstrict-aliasing -Werror=strict-aliasing \
  -fmodulo-sched -fmodulo-sched-allow-regmoves \
  -Wno-psabi -Wa,--noexecstack \
  -DANDROID -DNDEBUG"

FFMPEG_FLAGS="--target-os=linux \
  --arch=arm \
  --enable-cross-compile \
  --cross-prefix=arm-linux-androideabi- \
  --enable-gpl \
  --disable-shared \
  --disable-symver \
  --disable-doc \
  --disable-ffplay \
  --enable-ffmpeg \
  --disable-ffprobe \
  --disable-ffserver \
  --disable-avdevice \
  --disable-devices \
  --enable-protocols  \
  --enable-parsers \
  --enable-demuxers \
  --disable-demuxer=sbg \
  --enable-libx264 \
  --enable-encoder=libx264 \
  --enable-nonfree \
  --enable-libfdk-aac \
  --enable-decoders \
  --enable-network \
  --enable-swscale  \
  --enable-asm \
  --enable-optimizations \
  --enable-asm \
  --enable-swresample"

function delete_one()
{
  if [ -f "$1" ];then   
    rm $1
  fi
}


for version in  armv7; do

  cd $SOURCE

  case $version in
    neon)
      EXTRA_CFLAGS="-march=armv7-a -mthumb -mfpu=neon -mfloat-abi=softfp -mvectorize-with-neon-quad"
      EXTRA_LDFLAGS="-Wl,--fix-cortex-a8"
      ;;
    armv7)
      EXTRA_CFLAGS="-march=armv7-a -mthumb -mfpu=vfpv3 -mfloat-abi=softfp"
      EXTRA_LDFLAGS="-Wl,--fix-cortex-a8"
      ;;
    vfp)
      EXTRA_CFLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=softfp"
      EXTRA_LDFLAGS=""
      ;;
    armv6)
      EXTRA_CFLAGS="-march=armv6"
      EXTRA_LDFLAGS=""
      ;;
    *)
      EXTRA_CFLAGS=""
      EXTRA_LDFLAGS=""
      ;;
  esac

  PREFIX="$TARGET/$version" && mkdir -p $PREFIX
  FFMPEG_FLAGS="$FFMPEG_FLAGS --prefix=$PREFIX"
  #export LD_LIBRARY_PATH="/root/junz/ffmpeg-2.5/external/x264/lib"
  ./configure $FFMPEG_FLAGS --extra-cflags="$CFLAGS $EXTRA_CFLAGS -I`pwd`/external/include -I`pwd`/external/include/x264" --extra-ldflags="$EXTRA_LDFLAGS -L`pwd`/external/libs/fdk-aac -L`pwd`/external/libs/x264" | tee $PREFIX/configuration.txt
  cp config.* $PREFIX
  [ $PIPESTATUS == 0 ] || exit 1

  #make clean
  make -j4 || exit 1
  make install || exit 1
  for objname in libavcodec/log2_tab.o libavformat/log2_tab.o libavformat/golomb_tab.o libswresample/log2_tab.o libswscale/log2_tab.o libavcodec/inverse.o 
  do
    delete_one $objname
  done
  
  #rm libavcodec/log2_tab.o libavformat/log2_tab.o libavformat/golomb_tab.o libswresample/log2_tab.o libswscale/log2_tab.o libavcodec/inverse.o
  $CC -lm -lz -shared --sysroot=$SYSROOT -Wl,--no-undefined -Wl,-z,noexecstack  $EXTRA_LDFLAGS compat/*.o libavutil/*.o libavutil/arm/*.o libavcodec/*.o libavcodec/arm/*.o libavcodec/neon/*.o libavformat/*.o libswresample/*.o libswresample/arm/*.o libswscale/*.o libavfilter/*.o libavfilter/libmpcodecs/*.o libpostproc/*.o -L`pwd`/external/libs/x264 -L`pwd`/external/libs/fdk-aac -lx264 -lfdk-aac -o $PREFIX/libffmpeg.so

  cp $PREFIX/libffmpeg.so $PREFIX/libffmpeg-debug.so
  arm-linux-androideabi-strip --strip-unneeded $PREFIX/libffmpeg.so

done




