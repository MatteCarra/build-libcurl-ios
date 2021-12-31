#!/bin/bash -euo pipefail

readonly XCODE_DEV="$(xcode-select -p)"
export DEVROOT="${XCODE_DEV}/Toolchains/XcodeDefault.xctoolchain"
DFT_DIST_DIR=${HOME}/Desktop/libcurl-ios-dist
DIST_DIR=${DIST_DIR:-$DFT_DIST_DIR}

function check_curl_ver() {
echo "#include \"include/curl/curlver.h\"
#if LIBCURL_VERSION_MAJOR < 7 || LIBCURL_VERSION_MINOR < 55
#error Required curl 7.40.0+; See http://curl.haxx.se/docs/adv_20150108A.html
#error Supported minimal version is 7.55.0 for header file changes, see Issue #12 (https://github.com/sinofool/build-libcurl-ios/issues/12)
#endif"|gcc -c -o /dev/null -xc -||exit 9
}

function build_for_arch() {
  ARCH=$1
  HOST=$2
  SDK=$3
  PREFIX=$4
  DEPLOYMENT_TARGET="6.0"
  export PATH="${DEVROOT}/usr/bin/:${PATH}"
  export CFLAGS="-arch ${ARCH} -pipe -Os -gdwarf-2 -isysroot $(xcrun -sdk $SDK --show-sdk-path) -m$SDK-version-min=$DEPLOYMENT_TARGET -fembed-bitcode"
  ./configure --disable-shared --enable-static --enable-ipv6 --host="${HOST}" --prefix=${PREFIX} --with-secure-transport && make -j8 && make install
}

function build_for_current_arch() {
  ARCH=$1
  HOST=$2
  SDK=$3
  PREFIX=$4
  DEPLOYMENT_TARGET="14.0"
  export CFLAGS="-arch $ARCH -isysroot $(xcrun -sdk $SDK --show-sdk-path) -m$SDK-version-min=$DEPLOYMENT_TARGET"
  ./configure --disable-shared --enable-static --enable-ipv6 --host="${HOST}" --prefix=${PREFIX} --with-secure-transport && make -j8 && make install
}

if [ "${1:-''}" == "openssl" ]
then
  if [ ! -d ${HOME}/Desktop/openssl-ios-dist ]
  then
    echo "Please use https://github.com/sinofool/build-openssl-ios/ to build OpenSSL for iOS first"
    exit 8
  fi
  export SSL_FLAG=--with-ssl=${HOME}/Desktop/openssl-ios-dist
else
  check_curl_ver
  export SSL_FLAG="--with-secure-transport"
fi

TMP_DIR=/tmp/build_libcurl_$$

build_for_arch armv7s armv7s-apple-darwin iphoneos ${TMP_DIR}/armv7s || exit 4
build_for_arch armv7 armv7-apple-darwin iphoneos ${TMP_DIR}/armv7 || exit 5
build_for_current_arch arm64 arm-apple-darwin iphoneos ${TMP_DIR}/arm64 || exit 3
build_for_current_arch arm64 arm-apple-darwin iphonesimulator ${TMP_DIR}/arm64_sim  || exit 6

mkdir -p ${TMP_DIR}/lib/
${DEVROOT}/usr/bin/lipo \
  -arch armv7 ${TMP_DIR}/armv7/lib/libcurl.a \
  -arch armv7s ${TMP_DIR}/armv7s/lib/libcurl.a \
  -arch arm64 ${TMP_DIR}/arm64/lib/libcurl.a \
  -output ${TMP_DIR}/lib/libcurl.a -create


cp ${TMP_DIR}/arm64_sim/lib/libcurl.a ${TMP_DIR}/lib/libcurlsim.a
cp -r ${TMP_DIR}/arm64/include ${TMP_DIR}/

mkdir -p ${DIST_DIR}
cp -r ${TMP_DIR}/include ${TMP_DIR}/lib ${DIST_DIR}

