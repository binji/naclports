#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../../build_tools/common.sh

# Beneath a Steel Sky (floppy version)
readonly BASS_FLOPPY_URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/scummvm_games/bass/BASS-Floppy-1.3.zip
readonly BASS_FLOPPY_NAME=BASS-Floppy-1.3

readonly LURE_URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/scummvm_games/lure/lure-1.1.zip
readonly LURE_NAME=lure-1.1

EXECUTABLES=scummvm

SCUMMVM_EXAMPLE_DIR=${NACL_SRC}/examples/games/scummvm

ConfigureStep() {
  # NOTE: We can't use the DefaultConfigureStep, because the scummvm
  # configure script is hand-rolled, and won't accept additional arguments.
  Banner "Configuring ${PACKAGE_NAME}"
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  # without this setting *make* will not show the full command lines
  export VERBOSE_BUILD=1
  export RANLIB=${NACLRANLIB}
  export PKG_CONFIG_PATH=${NACLPORTS_LIBDIR}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACLPORTS_LIBDIR}
  export CFLAGS=${NACLPORTS_CFLAGS}
  export CXXFLAGS=${NACLPORTS_CXXFLAGS}
  export LDFLAGS=${NACLPORTS_LDFLAGS}
  export PATH="${NACL_BIN_PATH}:${PATH}"
  export PATH="${NACLPORTS_PREFIX_BIN}:${PATH}"
  local SRC_DIR=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}
  if [ ! -f "${NACL_CONFIGURE_PATH:-${SRC_DIR}/configure}" ]; then
    echo "No configure script found"
    return
  fi
  local DEFAULT_BUILD_DIR=${SRC_DIR}/${NACL_BUILD_SUBDIR}
  local BUILD_DIR=${NACL_BUILD_DIR:-${DEFAULT_BUILD_DIR}}
  MakeDir ${BUILD_DIR}
  ChangeDir ${BUILD_DIR}
  echo "Directory: $(pwd)"

  local conf_host=${NACL_CROSS_PREFIX}
  if [ "${NACL_ARCH}" = "pnacl" ]; then
    conf_host="pnacl"
  elif [ "${NACL_ARCH}" = "arm" ]; then
    conf_host="nacl-arm"
  else
    conf_host="nacl-x86"
  fi
  export DEFINES=
  export DEFINES="$DEFINES -DNACL -DSYSTEM_NOT_SUPPORTING_D_TYPE=1"
  export LIBS=
  export LIBS="$LIBS -Wl,--whole-archive"
  export LIBS="$LIBS -lvorbisfile -lvorbis -logg"
  export LIBS="$LIBS -lnacl_io -ltar"
  export LIBS="$LIBS -lppapi -lppapi_cpp -lppapi_cpp_private"
  export LIBS="$LIBS -Wl,--no-whole-archive"

  # NOTE: disabled mt32emu because it using inline assembly that won't
  #     validate.
  ../configure \
    --host=${conf_host} \
    --libdir=${NACLPORTS_LIBDIR} \
    --disable-flac \
    --disable-zlib \
    --disable-mt32emu \
    --disable-timidity \
    --disable-all-engines \
    --enable-engine=lure \
    --enable-engine=sky
}

InstallStep() {
  SRC_DIR=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  SCUMMVM_DIR=runimage/usr/local/share/scummvm
  ChangeDir ${SRC_DIR}

  mkdir -p ${SCUMMVM_DIR}
  cp gui/themes/scummclassic.zip \
     dists/engine-data/sky.cpt \
     gui/themes/scummmodern.zip \
     gui/themes/translations.dat \
     dists/engine-data/lure.dat \
     dists/pred.dic \
     ${SCUMMVM_DIR}

  cp `find gui/themes/fonts/ -type f` ${SCUMMVM_DIR}

  Banner "Creating tarballs"
  cd runimage
  tar cf ../runimage.tar ./
  cd ..

  #Beneath a Steel Sky (Floppy version)
  BASS_DIR=bass/usr/local/share/scummvm/${BASS_FLOPPY_NAME}
  mkdir -p ${BASS_DIR}
  cp -r ${NACL_PACKAGES_REPOSITORY}/${BASS_FLOPPY_NAME}/* ${BASS_DIR}
  cd bass
  tar cf ../bass.tar ./
  cd ..

  #Lure of the temptress
  LURE_DIR=lure/usr/local/share/scummvm
  mkdir -p ${LURE_DIR}
  cp -r ${NACL_PACKAGES_REPOSITORY}/${LURE_NAME}/* ${LURE_DIR}
  cd lure
  tar cf ../lure.tar ./
  cd ..

  Banner "Publishing to ${PUBLISH_DIR}"
  MakeDir ${PUBLISH_DIR}
  local ASSEMBLY_DIR=${PUBLISH_DIR}/scummvm

  MakeDir ${ASSEMBLY_DIR}

  cp ${START_DIR}/packaged_app/* ${ASSEMBLY_DIR}
  cp ${SRC_DIR}/*.tar ${ASSEMBLY_DIR}
  if [ "${NACL_DEBUG}" = "1" ]; then
    cp ${SRC_DIR}/${NACL_BUILD_SUBDIR}/scummvm \
        ${ASSEMBLY_DIR}/scummvm_${NACL_ARCH}${NACL_EXEEXT}
  else
    ${NACLSTRIP} ${SRC_DIR}/${NACL_BUILD_SUBDIR}/scummvm \
        -o ${ASSEMBLY_DIR}/scummvm_${NACL_ARCH}${NACL_EXEEXT}
  fi

  python ${NACL_SDK_ROOT}/tools/create_nmf.py \
      ${NACL_CREATE_NMF_FLAGS} \
      ${ASSEMBLY_DIR}/scummvm_*${NACL_EXEEXT} \
      -s ${ASSEMBLY_DIR} \
      -o ${ASSEMBLY_DIR}/scummvm.nmf

  if [ "${NACL_ARCH}" = "pnacl" ]; then
    sed -i.bak 's/x-nacl/x-pnacl/' ${ASSEMBLY_DIR}/index.html
  fi

  ChangeDir ${PUBLISH_DIR}
  LogExecute zip -r scummvm-1.2.1.zip scummvm
}

CustomCheck() {
  # verify sha1 checksum for tarball
  if ${SHA1CHECK} <$1 &>/dev/null; then
    return 0
  else
    return 1
  fi
}

DownloadZipStep() {
  cd ${NACL_PACKAGES_TARBALLS}
  # if matching zip already exists, don't download again
  if ! CustomCheck $3; then
    Fetch $1 $2.zip
    if ! CustomCheck $3 ; then
       Banner "${PACKAGE_NAME} failed checksum!"
       exit -1
    fi
  fi
}

ExtractGameZipStep() {
  Banner "Unzipping ${PACKAGE_NAME}.zip"
  ChangeDir ${NACL_PACKAGES_REPOSITORY}
  Remove ${PACKAGE_DIR}
  unzip -d ${PACKAGE_DIR} ${NACL_PACKAGES_TARBALLS}/${PACKAGE_NAME}.zip
}

GameGetStep() {
  PACKAGE_NAME_TEMP=${PACKAGE_NAME}
  PACKAGE_DIR_TEMP=${PACKAGE_DIR}
  PACKAGE_NAME=$2
  PACKAGE_DIR=$2
  SHA1=${SCUMMVM_EXAMPLE_DIR}/$2/$2.sha1
  DownloadZipStep $1 $2 ${SHA1}
  ExtractGameZipStep
  PACKAGE_NAME=${PACKAGE_NAME_TEMP}
  PACKAGE_DIR=${PACKAGE_DIR_TEMP}
}

PackageInstall() {
  GameGetStep ${BASS_FLOPPY_URL} ${BASS_FLOPPY_NAME}
  GameGetStep ${LURE_URL} ${LURE_NAME}
  DefaultPackageInstall
}

PackageInstall
exit 0
