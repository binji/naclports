#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../../build_tools/common.sh

export DEPS_LIBS="-lpng12 -lSDL_mixer -lSDL_ttf -lSDL -lppapi_cpp -lSDLmain -lppapi_cpp -lnacl_io -lppapi_gles2 -lRegal -lstdc++ -lppapi -lpthread -llua -lm -lnosys"
export LIBTOOLFLAGS="--preserve-dup-deps"

PUBLISH_DIR="${NACL_PACKAGES_PUBLISH}/${PACKAGE_NAME}"
TAR_DIR="${PUBLISH_DIR}/.tar"

CustomConfigureStep() {
  MakeDir ${PUBLISH_DIR}

  export EXTRA_CONFIGURE_ARGS="--bindir=${PUBLISH_DIR} --datarootdir=${TAR_DIR}"
  DefaultConfigureStep
}

CustomInstallStep() {

  DefaultInstallStep

  ChangeDir ${TAR_DIR}
  tar cf ${PUBLISH_DIR}/pushover.tar .
  cp ${START_DIR}/pushover.html ${PUBLISH_DIR}
  cd ${PUBLISH_DIR}
  rm -rf ${TAR_DIR}
  python ${NACL_SDK_ROOT}/tools/create_nmf.py \
      ${NACL_CREATE_NMF_FLAGS} \
      pushover*${NACL_EXEEXT} \
      -s . \
      -o pushover.nmf
}

CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  CustomConfigureStep
  DefaultBuildStep
  DefaultTranslateStep
  DefaultValidateStep
  CustomInstallStep
}

CustomPackageInstall
exit 0
