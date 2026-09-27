# 🚀 Google Pixel 5 ("redfin" / "redbull") Halium 11 & Docker Kernel

Custom kernel build automated via GitHub Actions for running **Halium 11**, a lightweight **Debian ARM64 terminal**, and native **Docker** on the Google Pixel 5.

---

## 🎯 Target Specifications
* **Device:** Google Pixel 5 (`redfin`) / Pixel 4a 5G (`bramble`)
* **Base Android:** Stock Android 11 (`RQ3A.211001.001`)
* **Kernel Version:** Linux 4.19 (LineageOS 18.1 / AOSP base)
* **Compiler:** Proton-Clang (LLVM 13+)

---

## ✨ Features Enabled
* **Full Docker Containerization:**
  * Process isolation: `CONFIG_NAMESPACES=y`, `CONFIG_PID_NS=y`, `CONFIG_IPC_NS=y`, `CONFIG_USER_NS=y`
  * Resource limits: `CONFIG_CGROUPS=y`, `CONFIG_CGROUP_DEVICE=y`, `CONFIG_CGROUP_PIDS=y`, `CONFIG_MEMCG=y`
  * Storage driver: `CONFIG_OVERLAY_FS=y`
  * Networking: `CONFIG_BRIDGE=y`, `CONFIG_VETH=y`, `CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y`, `CONFIG_IP_NF_TARGET_MASQUERADE=y`
* **Halium 11 & Systemd Support:**
  * Automatic device node creation: `CONFIG_DEVTMPFS=y`, `CONFIG_DEVTMPFS_MOUNT=y`
  * System IPC & POSIX queues: `CONFIG_SYSVIPC=y`, `CONFIG_POSIX_MQUEUE=y`

---

## 📦 Build Artifacts
Every build produces:
1. **`boot-halium11-docker-redfin.img`**: AVB-signed, 96 MB flashable boot image with Header v3.
2. **`AnyKernel3-Halium11-Docker-redfin.zip`**: Recovery-flashable zip containing `Image.lz4` and all compiled `.ko` modules.
3. **`dtbo.img`**: Device Tree Overlay partition image.
4. **`kernel_config.txt`**: Complete compiled `.config` for audit and inspection.

---

## ⚡ How to Flash

### Method 1: Live-Boot (Zero-Risk RAM Test)
```bash
fastboot boot boot-halium11-docker-redfin.img
```

### Method 2: Permanent Fastboot Flash
```bash
fastboot flash boot_b boot-halium11-docker-redfin.img
```

### Method 3: Flash via TWRP Recovery
```bash
fastboot boot twrp.img
# In TWRP: Install -> AnyKernel3-Halium11-Docker-redfin.zip
```
