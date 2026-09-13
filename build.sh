#!/usr/bin/env bash
set -e

echo "=== 1. Installing Build Dependencies ==="
sudo apt-get update
sudo apt-get install -y bc bison flex libssl-dev libelf-dev \
  git curl zip lz4 python3 python-is-python3 ccache \
  gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi libncurses5 libtinfo5 \
  cpio binutils || true

WORKSPACE="$(pwd)"

echo "=== 2. Downloading Proton-Clang Compiler ==="
if [ ! -d "clang" ]; then
  git clone --depth=1 https://github.com/kdrag0n/proton-clang.git clang
fi

echo "=== 3. Cloning LineageOS 23.2 Pixel 5 Kernel ==="
if [ ! -d "kernel" ]; then
  git clone https://github.com/LineageOS/android_kernel_google_redbull.git -b lineage-23.2 --depth=1 kernel
fi

echo "=== 4. Patching Defconfig & DTS for Docker Support ==="
cd kernel
DEFCONFIG="arch/arm64/configs/redbull_defconfig"

git checkout arch/arm64/configs/redbull_defconfig arch/arm64/boot/dts/google/lito-redfin-dev.dtsi 2>/dev/null || true

sed -i 's/# CONFIG_PID_NS is not set/CONFIG_PID_NS=y/' $DEFCONFIG
sed -i 's/# CONFIG_FAIR_GROUP_SCHED is not set/CONFIG_FAIR_GROUP_SCHED=y/' $DEFCONFIG
sed -i 's/CONFIG_LTO_CLANG=y/# CONFIG_LTO_CLANG is not set/' $DEFCONFIG
sed -i 's/CONFIG_CFI_CLANG=y/# CONFIG_CFI_CLANG is not set/' $DEFCONFIG
echo "CONFIG_LTO_NONE=y" >> $DEFCONFIG
sed -i 's/CONFIG_LOCALVERSION_AUTO=y/# CONFIG_LOCALVERSION_AUTO is not set/' $DEFCONFIG

cat << 'EOF' >> $DEFCONFIG

# --- Container & Docker Support ---
CONFIG_USER_NS=y
CONFIG_CFS_BANDWIDTH=y
CONFIG_CGROUP_PIDS=y
CONFIG_CGROUP_DEVICE=y
CONFIG_BLK_DEV_THROTTLING=y
CONFIG_POSIX_MQUEUE=y

# Networking & Netfilter for Docker
CONFIG_BRIDGE_NETFILTER=y
CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y
CONFIG_NETFILTER_XT_MATCH_IPVS=y
CONFIG_NETFILTER_XT_MARK=y
CONFIG_IP_NF_RAW=y
CONFIG_IP_NF_TARGET_REDIRECT=y
CONFIG_IP6_NF_TARGET_MASQUERADE=y
CONFIG_MACVLAN=y
CONFIG_IPVLAN=y
CONFIG_VXLAN=y
EOF

sed -i '/\/delete-node\/ disp_pins;/d' arch/arm64/boot/dts/google/lito-redfin-dev.dtsi

echo "=== 5. Compiling Kernel & Matching Modules ==="
export PATH="$WORKSPACE/clang/bin:$PATH"
make O=out ARCH=arm64 \
  LLVM=1 \
  CROSS_COMPILE=aarch64-linux-gnu- \
  CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
  redbull_defconfig

make O=out ARCH=arm64 \
  LLVM=1 \
  CROSS_COMPILE=aarch64-linux-gnu- \
  CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
  Image.lz4 modules -j$(nproc --all)

mkdir -p "$WORKSPACE/modules_out"
make O=out ARCH=arm64 \
  LLVM=1 \
  CROSS_COMPILE=aarch64-linux-gnu- \
  CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
  INSTALL_MOD_PATH="$WORKSPACE/modules_out" \
  modules_install

cd "$WORKSPACE"

echo "=== 6. Packaging with AnyKernel3 (with Modules) ==="
if [ ! -d "anykernel" ]; then
  git clone https://github.com/osm0sis/AnyKernel3.git --depth=1 anykernel
fi
cd anykernel
sed -i 's/device.name1=.*/device.name1=redfin/' anykernel.sh
sed -i 's/device.name2=.*/device.name2=bramble/' anykernel.sh
sed -i 's/do.modules=0/do.modules=1/' anykernel.sh
sed -i 's/do.systemless=1/do.systemless=1/' anykernel.sh

cp "$WORKSPACE/kernel/out/arch/arm64/boot/Image.lz4" .

mkdir -p modules/vendor/lib/modules
find "$WORKSPACE/modules_out" -name "*.ko" -exec cp {} modules/vendor/lib/modules/ \;
echo "Copied $(ls modules/vendor/lib/modules | wc -l) modules to AnyKernel3"

zip -r9 "$WORKSPACE/AnyKernel3-LineageOS23.2-Docker-redfin.zip" * -x .git README.md *placeholder
cd "$WORKSPACE"

echo "=== 7. Building 96MB AVB-Signed boot.img ==="
if [ ! -f "stock_boot.img" ]; then
  curl -sL https://mirrorbits.lineageos.org/full/redfin/20260907/boot.img -o stock_boot.img
fi

if [ ! -d "mkbootimg_tools" ]; then
  git clone --depth=1 https://android.googlesource.com/platform/system/tools/mkbootimg mkbootimg_tools
fi
if [ ! -d "avb_tools" ]; then
  git clone --depth=1 https://android.googlesource.com/platform/external/avb avb_tools
fi

python3 mkbootimg_tools/unpack_bootimg.py --boot_img stock_boot.img --out stock_unpacked

python3 mkbootimg_tools/mkbootimg.py \
  --header_version 3 \
  --os_version 16.0.0 \
  --os_patch_level 2026-08 \
  --kernel "$WORKSPACE/kernel/out/arch/arm64/boot/Image.lz4" \
  --ramdisk stock_unpacked/ramdisk \
  -o boot-docker-raw.img

python3 avb_tools/avbtool.py add_hash_footer \
  --image boot-docker-raw.img \
  --partition_size 100663296 \
  --partition_name boot \
  --hash_algorithm sha256 \
  --salt c9cfcce701396e09844a736f351a4499e64a067948657e4bcbf3b49884e19691

mv boot-docker-raw.img "$WORKSPACE/boot-docker-redfin.img"

echo ""
echo "=========================================================="
echo " BUILD FINISHED SUCCESSFULLY!"
echo " Artifacts ready in your Codespace workspace:"
ls -lh "$WORKSPACE/AnyKernel3-LineageOS23.2-Docker-redfin.zip"
ls -lh "$WORKSPACE/boot-docker-redfin.img"
echo " Right-click either file in the file explorer to Download!"
echo "=========================================================="
