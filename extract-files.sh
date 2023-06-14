#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2020 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

ONLY_COMMON=
ONLY_TARGET=
KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        --only-common )
                ONLY_COMMON=true
                ;;
        --only-target )
                ONLY_TARGET=true
                ;;
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case "${1}" in
        odm/lib64/libgf_hal_G6.so)
            sed -i "s|ro.boot.flash.locked|vendor.flash.locked\x00|" "${2}"
            ;;
        odm/lib64/libgf_hal_G3.so)
            sed -i "s|ro.boot.flash.locked|vendor.flash.locked\x00|" "${2}"
            ;;
        odm/lib64/libgf_hal_G5.so)
            sed -i "s|ro.boot.flash.locked|vendor.flash.locked\x00|" "${2}"
            ;;
        odm/lib64/libui.so)
            patchelf --replace-needed "android.hardware.graphics.common-V1-ndk_platform.so" "android.hardware.graphics.common-V1-ndk.so" "${2}"
            ;;
        product/etc/sysconfig/com.android.hotwordenrollment.common.util.xml)
            sed -i "s|my_product|product|" "${2}"
            ;;
        vendor/lib64/vendor.qti.hardware.camera.postproc@1.0-service-impl.so)
            "${SIGSCAN}" -p "AB 0B 00 94" -P "1F 20 03 D5" -f "${2}"
            ;;
    esac
}

if [ -z "${ONLY_TARGET}" ]; then
    # Initialize the helper for common device
    setup_vendor "${DEVICE_COMMON}" "${VENDOR}" "${ANDROID_ROOT}" true "${CLEAN_VENDOR}"

    extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
fi

if [ -z "${ONLY_COMMON}" ] && [ -s "${MY_DIR}/../${DEVICE}/proprietary-files.txt" ]; then
    # Reinitialize the helper for device
    source "${MY_DIR}/../${DEVICE}/extract-files.sh"
    setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

    extract "${MY_DIR}/../${DEVICE}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
fi

"${MY_DIR}/setup-makefiles.sh"
