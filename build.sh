#!/usr/bin/env bash
set -e

# ==============================================================================
# Pixel 5 ("redfin" / "redbull") Halium 11 & Docker Kernel Build Script
# Target: Linux 4.19 (LineageOS 18.1 / Android 11)
# ==============================================================================

WORKSPACE="$(pwd)"
CLANG_DIR="$WORKSPACE/clang"
KERNEL_DIR="$WORKSPACE/kernel"
OUT_DIR="$KERNEL_DIR/out"

echo "=== [1/6] Installing Build Dependencies ==="
if command -v apt-get &> /dev/null; then
    sudo apt-get update
    sudo apt-get install -y \
        bc bison flex libssl-dev libelf-dev \
        git curl zip lz4 python3 python-is-python3 ccache \
        gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi libncurses5 libtinfo5 \
        cpio binutils make
fi

echo "=== [2/6] Downloading Toolchain & Kernel Source ==="
if [ ! -d "$CLANG_DIR" ]; then
    git clone --depth=1 https://github.com/kdrag0n/proton-clang.git "$CLANG_DIR"
fi

if [ ! -d "$KERNEL_DIR" ]; then
    git clone --depth=1 -b lineage-18.1 https://github.com/LineageOS/android_kernel_google_redbull.git "$KERNEL_DIR"
fi

echo "=== [3/6] Patching Defconfig for Docker, Halium & Stock Vermagic ==="
cd "$KERNEL_DIR"
DEFCONFIG="arch/arm64/configs/redbull_defconfig"

# 1. Enable PID Namespaces
sed -i 's/# CONFIG_PID_NS is not set/CONFIG_PID_NS=y/' $DEFCONFIG

# 2. Enable Fair Group Scheduling
sed -i 's/# CONFIG_FAIR_GROUP_SCHED is not set/CONFIG_FAIR_GROUP_SCHED=y/' $DEFCONFIG

# 3. Disable LTO & CFI for standalone Clang compilation
sed -i 's/CONFIG_LTO_CLANG=y/# CONFIG_LTO_CLANG is not set/' $DEFCONFIG
sed -i 's/CONFIG_CFI_CLANG=y/# CONFIG_CFI_CLANG is not set/' $DEFCONFIG
echo "CONFIG_LTO_NONE=y" >> $DEFCONFIG

# 4. Enforce exact Google stock vermagic matching
sed -i 's/CONFIG_LOCALVERSION_AUTO=y/# CONFIG_LOCALVERSION_AUTO is not set/' $DEFCONFIG
if grep -q "CONFIG_LOCALVERSION=" $DEFCONFIG; then
    sed -i 's/CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="-g85b17737b5f2-ab7508408"/' $DEFCONFIG
else
    echo 'CONFIG_LOCALVERSION="-g85b17737b5f2-ab7508408"' >> $DEFCONFIG
fi

# 5. Append Docker, Halium & Built-in Storage/Power configurations
cat "$WORKSPACE/configs/docker_halium.config" >> $DEFCONFIG

echo "=== [4/6] Compiling Kernel (Image.lz4) ==="
export PATH="$CLANG_DIR/bin:$PATH"

make O=out ARCH=arm64 \
    LLVM=1 \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
    redbull_defconfig

make O=out ARCH=arm64 \
    LLVM=1 \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
    KCFLAGS="-w" \
    Image.lz4 -j$(nproc --all)

echo "=== [5/6] Building Fastboot boot.img (Header v3) ==="
cd "$WORKSPACE"

if [ ! -d "mkbootimg_tools" ]; then
    git clone --depth=1 https://android.googlesource.com/platform/system/tools/mkbootimg mkbootimg_tools
fi

if [ ! -d "avb_tools" ]; then
    git clone --depth=1 https://android.googlesource.com/platform/external/avb avb_tools
fi

python3 mkbootimg_tools/mkbootimg.py \
    --header_version 3 \
    --os_version 11.0.0 \
    --os_patch_level 2021-10 \
    --kernel "$OUT_DIR/arch/arm64/boot/Image.lz4" \
    --ramdisk "$WORKSPACE/configs/stock_ramdisk.lz4" \
    -o boot-raw.img

python3 avb_tools/avbtool.py add_hash_footer \
    --image boot-raw.img \
    --partition_size 100663296 \
    --partition_name boot \
    --hash_algorithm sha256

mv boot-raw.img "$WORKSPACE/boot-halium11-docker-redfin.img"

echo "=== [6/6] Build Complete! ==="
echo "Output image: $WORKSPACE/boot-halium11-docker-redfin.img"
ls -lh "$WORKSPACE/boot-halium11-docker-redfin.img"
