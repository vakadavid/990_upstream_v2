## Build auxiliary boot.img files

MODEL=unpatched_z3s
BOARD=SRPSI19B018KU
RECOVERY_OPTION=n
KSU_OPTION=y
DTBS=n

DTB_PATH=build/out/$MODEL/dtb.img
KERNEL_PATH=build/out/$MODEL/Image
KERNEL_OFFSET=0x00008000
DTB_OFFSET=0x00000000
RAMDISK_OFFSET=0x01000000
SECOND_OFFSET=0xF0000000
TAGS_OFFSET=0x00000100
BASE=0x10000000
CMDLINE='androidboot.hardware=exynos990 loop.max_part=7'
HASHTYPE=sha1
HEADER_VERSION=2
OS_PATCH_LEVEL=2025-08
OS_VERSION=16.0.0
PAGESIZE=2048
RAMDISK=build/out/$MODEL/ramdisk.cpio.gz
OUTPUT_FILE=build/out/$MODEL/boot.img

mkdir -p build/out/$MODEL
mkdir -p build/out/$MODEL/zip
mkdir -p build/out/$MODEL/zip/files
mkdir -p build/out/$MODEL/zip/META-INF
mkdir -p build/out/$MODEL/zip/META-INF/com
mkdir -p build/out/$MODEL/zip/META-INF/com/google
mkdir -p build/out/$MODEL/zip/META-INF/com/google/android

# Copy kernel to build

cp out/arch/arm64/boot/unpatched_Image build/out/$MODEL/Image

# Build dtb
echo "Building common exynos9830 Device Tree Blob Image..."
echo "-----------------------------------------------"
./toolchain/mkdtimg cfg_create build/out/$MODEL/dtb.img build/dtconfigs/exynos9830.cfg -d out/arch/arm64/boot/dts/exynos

# Build dtbo
echo "Building Device Tree Blob Output Image for "$MODEL"..."
echo "-----------------------------------------------"
./toolchain/mkdtimg cfg_create build/out/$MODEL/dtbo.img build/dtconfigs/z3s.cfg -d out/arch/arm64/boot/dts/samsung


# Build ramdisk
echo "Building RAMDisk..."
echo "-----------------------------------------------"
pushd build/ramdisk > /dev/null
 find . ! -name . | LC_ALL=C sort | cpio -o -H newc -R root:root | gzip > ../out/$MODEL/ramdisk.cpio.gz || abort
popd > /dev/null
echo "-----------------------------------------------"

# Create boot image
echo "Creating boot image..."
echo "-----------------------------------------------"
 ./toolchain/mkbootimg --base $BASE --board $BOARD --cmdline "$CMDLINE" --dtb $DTB_PATH \
--dtb_offset $DTB_OFFSET --hashtype $HASHTYPE --header_version $HEADER_VERSION --kernel $KERNEL_PATH \
--kernel_offset $KERNEL_OFFSET --os_patch_level $OS_PATCH_LEVEL --os_version $OS_VERSION --pagesize $PAGESIZE \
--ramdisk $RAMDISK --ramdisk_offset $RAMDISK_OFFSET \
--second_offset $SECOND_OFFSET --tags_offset $TAGS_OFFSET -o $OUTPUT_FILE || abort

# Build zip
echo "Building zip..."
echo "-----------------------------------------------"

cp build/out/$MODEL/boot.img build/out/$MODEL/zip/files/boot.img
cp build/out/$MODEL/dtbo.img build/out/$MODEL/zip/files/dtbo.img
cp build/update-binary build/out/$MODEL/zip/META-INF/com/google/android/update-binary
cp build/updater-script build/out/$MODEL/zip/META-INF/com/google/android/updater-script

version=$(grep -o 'CONFIG_LOCALVERSION="[^"]*"' arch/arm64/configs/exynos9830_defconfig | cut -d '"' -f 2)
version=${version:1}
pushd build/out/$MODEL/zip > /dev/null
DATE=`date +"%d-%m-%Y_%H-%M-%S"`

if [[ "$KSU_OPTION" == "y" ]]; then
    NAME="$version"_"$MODEL"_UNOFFICIAL_UNP_KSU_"$DATE".zip
else
    NAME="$version"_"$MODEL"_UNOFFICIAL_UNP_"$DATE".zip
fi
zip -r -qq ../"$NAME" .

popd > /dev/null

echo "Build finished successfully!"