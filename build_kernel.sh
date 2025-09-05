#!/bin/bash

export PLATFORM_VERSION=1
export ANDROID_MAJOR_VERSION=r 
export ARCH=arm64
export SEC_BUILD_CONF_VENDOR_BUILD_OS=13
make exynos9830-x1slte_defconfig
make
