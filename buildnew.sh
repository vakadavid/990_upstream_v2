#!/usr/bin/env bash
# Minimal comments in English
set -euo pipefail

abort() {
    echo "-----------------------------------------------"
    echo "Kernel compilation failed! Exiting..."
    echo "-----------------------------------------------"
    exit 1
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]
Options:
  -m, --model <model>         required, e.g. c2s, x1slte
  -k, --ksu [y/N]             include KernelSU (default ask)
  -r, --recovery [y/N]        build for recovery (sets ksu=n)
  -d, --dtbs [y/N]            build only DTBs
  --clean                     full clean rebuild (preserve out/)
  --susfs-version <version>   manually set SUSFS version (e.g. v1.5.11)
  -h, --help                  show this help
EOF
}

# defaults
CLEAN_BUILD=false
MANUAL_SUSFS_VERSION=""
KSU_OPTION=""
RECOVERY_OPTION=""
DTB_OPTION=""
MODEL=""

# parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--model) MODEL="$2"; shift 2 ;;
        -k|--ksu) KSU_OPTION="$2"; shift 2 ;;
        -r|--recovery) RECOVERY_OPTION="$2"; shift 2 ;;
        -d|--dtbs) DTB_OPTION="$2"; shift 2 ;;
        --clean) CLEAN_BUILD=true; shift ;;
        --susfs-version) MANUAL_SUSFS_VERSION="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
done

if [[ -z "$MODEL" ]]; then
    echo "Error: model is required."
    usage
    exit 1
fi

echo "Preparing build environment..."
pushd "$(dirname "$0")" > /dev/null || abort

CORES=$(grep -c processor /proc/cpuinfo || echo 4)
CLANG_DIR="$PWD/toolchain/clang_14"
PATH="$CLANG_DIR/bin:$PATH"

# fetch toolchain if missing
if [[ ! -x "$CLANG_DIR/bin/clang-14" ]]; then
    echo "Toolchain not found, downloading..."
    rm -rf "$CLANG_DIR"
    mkdir -p "$CLANG_DIR"
    pushd "$CLANG_DIR" > /dev/null
    curl -LJO "https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/tags/android-13.0.0_r13/clang-r450784d.tar.gz"
    tar xf clang-r450784d.tar.gz
    rm -f clang-r450784d.tar.gz
    popd > /dev/null
fi

MAKE_ARGS="LLVM=1 LLVM_IAS=1 ARCH=arm64 O=out"

# board map
case "$MODEL" in
    x1slte) BOARD=SRPSJ28B018KU ;;
    x1s) BOARD=SRPSI19A018KU ;;
    y2slte) BOARD=SRPSJ28A018KU ;;
    y2s) BOARD=SRPSG12A018KU ;;
    z3s) BOARD=SRPSI19B018KU ;;
    c1slte) BOARD=SRPTC30B009KU ;;
    c1s) BOARD=SRPTB27D009KU ;;
    c2slte) BOARD=SRPTC30A009KU ;;
    c2s) BOARD=SRPTB27C009KU ;;
    r8s) BOARD=SRPTF26B014KU ;;
    *) echo "Unknown model: $MODEL"; usage; exit 1 ;;
esac

# clean build option
if [[ "$CLEAN_BUILD" == true ]]; then
    echo "Performing full clean rebuild (preserving out/)..."
    # keep out/ to avoid re-downloading toolchains etc, but remove build artifacts
    rm -rf build/out/"$MODEL" build/tmp
    # leave 'out' alone
    make mrproper >/dev/null 2>&1 || true
fi

mkdir -p build/out/"$MODEL"/zip/files
mkdir -p build/out/"$MODEL"/zip/META-INF/com/google/android

if [[ "${RECOVERY_OPTION:-}" == "y" ]]; then
    RECOVERY=recovery.config
    KSU_OPTION=n
fi

if [[ -z "${KSU_OPTION:-}" ]]; then
    read -p "Include KernelSU (y/N): " KSU_OPTION
fi

if [[ "${KSU_OPTION}" == "y" ]]; then
    KSU=ksu.config
fi

if [[ "${DTB_OPTION:-}" == "y" ]]; then
    DTBS=y
fi

echo "-----------------------------------------------"
echo "Defconfig: extreme_${MODEL}_defconfig"
echo "KSU: ${KSU:-N}"
echo "Recovery: ${RECOVERY:-N}"
echo "Clean build: ${CLEAN_BUILD}"
echo "-----------------------------------------------"

# generate config
echo "Generating .config..."
make ${MAKE_ARGS} -j"$CORES" exynos9830_defconfig "${MODEL}.config" ${KSU:-} ${RECOVERY:-} || abort

if [[ -n "${DTBS:-}" ]]; then
    MAKE_ARGS="$MAKE_ARGS dtbs"
    echo "Building DTBs only mode"
else
    echo "Building kernel..."
fi

# build
echo "-----------------------------------------------"
make ${MAKE_ARGS} -j"$CORES" || abort

# detect SUSFS version (search common locations), fallback to manual param
detect_susfs_version() {
    # Try to find common macros/strings that represent version
    # Search include/linux and drivers for likely patterns
    local v
    v=$(grep -RsohE 'SUSFS_VERSION[[:space:][:punct:]]*[=:]?[[:space:]]*"?v[0-9]+(\.[0-9]+)*\+?' include/linux drivers 2>/dev/null | head -n1 || true)
    if [[ -n "$v" ]]; then
        # extract vX.Y.Z
        echo "$v" | grep -oE 'v[0-9]+(\.[0-9]+)*' || echo "unknown"
        return
    fi
    # try patterns like #define SUSFS_VERSION "v1.5.11"
    v=$(grep -RsohE '#define[[:space:]]+SUSFS_VERSION[[:space:]]+"?v[0-9]+(\.[0-9]+)*"?' include/linux drivers 2>/dev/null | head -n1 || true)
    if [[ -n "$v" ]]; then
        echo "$v" | grep -oE 'v[0-9]+(\.[0-9]+)*' || echo "unknown"
        return
    fi
    # try searching for "SUSFS" string followed by v
    v=$(grep -RsohE 'susfs[-_ ]?v[0-9]+(\.[0-9]+)*' include/linux drivers 2>/dev/null | head -n1 || true)
    if [[ -n "$v" ]]; then
        echo "$v" | grep -oE 'v[0-9]+(\.[0-9]+)*' || echo "unknown"
        return
    fi
    echo "unknown"
}

# prefer manual override
if [[ -n "$MANUAL_SUSFS_VERSION" ]]; then
    SUSFS_VERSION="$MANUAL_SUSFS_VERSION"
else
    SUSFS_VERSION=$(detect_susfs_version)
fi
echo "Detected SUSFS version: ${SUSFS_VERSION}"

# prepare artifact paths
DTB_PATH=build/out/"$MODEL"/dtb.img
DTBO_PATH=build/out/"$MODEL"/dtbo.img
KERNEL_IMAGE_SRC=out/arch/arm64/boot/Image
KERNEL_IMAGE_DST=build/out/"$MODEL"/Image
RAMDISK_SRC=out/"$MODEL"/ramdisk.cpio.gz
RAMDISK_DST=build/out/"$MODEL"/ramdisk.cpio.gz
BOOT_IMG=build/out/"$MODEL"/boot.img

# ensure kernel image exists (copy from out if needed)
if [[ ! -s "$KERNEL_IMAGE_DST" ]]; then
    if [[ -s "${KERNEL_IMAGE_SRC}" ]]; then
        echo "Copying kernel Image to build/out/${MODEL}/"
        cp "${KERNEL_IMAGE_SRC}" "${KERNEL_IMAGE_DST}"
    else
        echo "Error: kernel Image missing at ${KERNEL_IMAGE_SRC}"
        abort
    fi
fi

# Build DTB/DTBO
echo "Building exynos9830 DTB..."
./toolchain/mkdtimg cfg_create "$DTB_PATH" build/dtconfigs/exynos9830.cfg -d out/arch/arm64/boot/dts/exynos

echo "Building DTBO for ${MODEL}..."
./toolchain/mkdtimg cfg_create "$DTBO_PATH" build/dtconfigs/"${MODEL}".cfg -d out/arch/arm64/boot/dts/samsung

# Build ramdisk
echo "Building RAMDisk..."
pushd build/ramdisk > /dev/null
if ! find . ! -name . | LC_ALL=C sort | cpio -o -H newc -R root:root | gzip > ../out/"${MODEL}"/ramdisk.cpio.gz ; then
    echo "Failed to build ramdisk"
    popd > /dev/null
    abort
fi
popd > /dev/null

# final sanity checks before mkbootimg
if [[ ! -s "$KERNEL_IMAGE_DST" ]]; then
    echo "Error: kernel Image missing or empty at $KERNEL_IMAGE_DST"
    abort
fi
if [[ ! -s "$DTB_PATH" ]]; then
    echo "Error: dtb missing at $DTB_PATH"
    abort
fi
if [[ ! -s "build/out/${MODEL}/ramdisk.cpio.gz" ]]; then
    echo "Error: ramdisk missing at build/out/${MODEL}/ramdisk.cpio.gz"
    abort
fi

# create boot image
echo "Creating boot image..."
./toolchain/mkbootimg \
    --base 0x10000000 --board "$BOARD" \
    --cmdline "androidboot.hardware=exynos990 loop.max_part=7" \
    --dtb "$DTB_PATH" --dtb_offset 0x00000000 --hashtype sha1 \
    --header_version 2 --kernel "$KERNEL_IMAGE_DST" --kernel_offset 0x00008000 \
    --os_patch_level 2025-08 --os_version 15.0.0 --pagesize 2048 \
    --ramdisk "build/out/${MODEL}/ramdisk.cpio.gz" --ramdisk_offset 0x01000000 \
    --second_offset 0xF0000000 --tags_offset 0x00000100 \
    -o "$BOOT_IMG" || abort

# pack flashable zip
echo "Packing flashable zip..."
mkdir -p build/out/"$MODEL"/zip/files
cp "$BOOT_IMG" build/out/"$MODEL"/zip/files/boot.img
cp "$DTBO_PATH" build/out/"$MODEL"/zip/files/dtbo.img
cp build/update-binary build/out/"$MODEL"/zip/META-INF/com/google/android/update-binary
cp build/updater-script build/out/"$MODEL"/zip/META-INF/com/google/android/updater-script

DATE=$(date +"%d-%m-%Y")
if [[ "${KSU_OPTION}" == "y" ]]; then
    ZIP_NAME="ExtremeKRNL-Nexus-v1_${MODEL}_susfs-${SUSFS_VERSION}_UNOFFICIAL_KSU_${DATE}.zip"
else
    ZIP_NAME="ExtremeKRNL-Nexus-v1_${MODEL}_susfs-${SUSFS_VERSION}_UNOFFICIAL_${DATE}.zip"
fi

pushd build/out/"$MODEL"/zip > /dev/null
zip -r -qq ../"${ZIP_NAME}" .
popd > /dev/null

echo "-----------------------------------------------"
echo "Build completed: build/out/${MODEL}/${ZIP_NAME}"
echo "SUSFS version: ${SUSFS_VERSION}"
echo "Build finished successfully!"
echo "-----------------------------------------------"

popd > /dev/null

