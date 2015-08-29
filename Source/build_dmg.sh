#!/bin/sh

# build_dmg.sh
# DiskArbitrator
#
# Created by Aaron Burghardt on 2/6/10.
# Copyright 2010 . All rights reserved.

SRC_PRODUCT="$1"
SRC_PRODUCT_PATH="${BUILT_PRODUCTS_DIR}/${SRC_PRODUCT}.app"
SRC_PRODUCT_CONTENTS="${SRC_PRODUCT_PATH}/Contents"
SRC_PRODUCT_RESOURCES="${SRC_PRODUCT_CONTENTS}/Resources"
SRC_PRODUCT_VERSION=`/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "${SRC_PRODUCT_CONTENTS}/Info.plist"`

echo "Building DMG for ${SRC_PRODUCT} ${SRC_PRODUCT_VERSION}"

DMG_DST_PATH="${BUILT_PRODUCTS_DIR}/${SRC_PRODUCT}-${SRC_PRODUCT_VERSION}.dmg"

DMG_SRC_DIR="${CONFIGURATION_TEMP_DIR}/${SRC_PRODUCT}-${SRC_PRODUCT_VERSION}"

if [ -e "$DMG_DST_PATH" ] ; then
	rm -rf "$DMG_DST_PATH" || exit 1
fi

mkdir -p "${DMG_SRC_DIR}"
cp -LR "${SRC_PRODUCT_PATH}" "${DMG_SRC_DIR}"
cp "${SRC_PRODUCT_PATH}/Contents/Resources/README.html" "${DMG_SRC_DIR}"
cp "${SRC_PRODUCT_PATH}/Contents/Resources/Release Notes.html" "${DMG_SRC_DIR}"

hdiutil create -layout NONE -srcfolder "${DMG_SRC_DIR}" "$DMG_DST_PATH"
hdiutil verify "$DMG_DST_PATH" || exit 1

rm -r "${DMG_SRC_DIR}"