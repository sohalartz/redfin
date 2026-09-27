# 🚀 Google Pixel 5 ("redfin" / "redbull") Halium 11 & Docker Kernel

Custom Linux 4.19 kernel and setup instructions for running **Halium 11**, a lightweight **Debian ARM64 terminal environment**, and native **Docker** on the Google Pixel 5.

---

## 🎯 Target Specifications
* **Device:** Google Pixel 5 (`redfin`) / Pixel 4a 5G (`bramble`)
* **Base Android:** Stock Android 11 (`RQ3A.211001.001`)
* **Kernel Version:** Linux 4.19 (LineageOS 18.1 / AOSP base)
* **Compiler:** Proton-Clang (LLVM 13+)
* **Output:** Fastboot-flashable 96 MB AVB-signed `boot.img` (Header v3)

---

## ✨ Features Enabled

* **Full Docker Containerization:**
  * Process isolation: `CONFIG_NAMESPACES=y`, `CONFIG_PID_NS=y`, `CONFIG_IPC_NS=y`, `CONFIG_USER_NS=y`, `CONFIG_UTS_NS=y`, `CONFIG_NET_NS=y`
  * Resource limits: `CONFIG_CGROUPS=y`, `CONFIG_CGROUP_DEVICE=y`, `CONFIG_CGROUP_PIDS=y`, `CONFIG_MEMCG=y`, `CONFIG_MEMCG_SWAP=y`, `CONFIG_CPUSETS=y`
  * Storage driver: `CONFIG_OVERLAY_FS=y`
  * Networking: `CONFIG_BRIDGE=y`, `CONFIG_BRIDGE_NETFILTER=y`, `CONFIG_VETH=y`, `CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y`, `CONFIG_IP_NF_TARGET_MASQUERADE=y`, `CONFIG_IP_NF_NAT=y`
* **Halium 11 & Systemd Support:**
  * Automatic device node creation: `CONFIG_DEVTMPFS=y`, `CONFIG_DEVTMPFS_MOUNT=y`
  * System IPC & POSIX queues: `CONFIG_SYSVIPC=y`, `CONFIG_POSIX_MQUEUE=y`
  * Seccomp filtering: `CONFIG_SECCOMP=y`, `CONFIG_SECCOMP_FILTER=y`
* **Stock Driver & Vermagic Compatibility:**
  * Exact vermagic matching string: `4.19.160-g85b17737b5f2-ab7508408` to ensure all stock vendor drivers load cleanly without watchdog timeouts.

---

## 🛠️ How to Compile

### Option 1: Automatic via GitHub Actions (Recommended)
1. Push to `main` or trigger manually from the **Actions** tab.
2. GitHub Actions installs dependencies, clones Proton-Clang and LineageOS 18.1 kernel, patches defconfig, compiles `Image.lz4`, and packages `boot-halium11-docker-redfin.img`.
3. Download the built artifact `Pixel5-Halium11-Docker-Kernel` from the run summary.

### Option 2: Local Compilation on Ubuntu / Debian / Codespaces
Run the provided automated build script:
```bash
chmod +x build.sh
./build.sh
```
This produces `boot-halium11-docker-redfin.img` in the workspace root.

---

## 📥 Required Downloads

### 1. TWRP Recovery for Pixel 5 (`redfin`)
* **Official Page:** [https://dl.twrp.me/redfin/](https://dl.twrp.me/redfin/)
* **Direct Image Download:** [twrp-3.7.0_11-0-redfin.img](https://dl.twrp.me/redfin/twrp-3.7.0_11-0-redfin.img)
> ⚠️ **IMPORTANT:** On Google Pixel 5 (Header v3), **NEVER** run `fastboot flash boot twrp.img` or `fastboot flash recovery twrp.img`. TWRP must **always** be booted temporarily in memory using `fastboot boot twrp-3.7.0_11-0-redfin.img`.

### 2. Halium 11 (API 30) ARM64 Rootfs
* **Official Droidian Nightly Releases:** [https://github.com/droidian-images/droidian/releases/tag/nightly](https://github.com/droidian-images/droidian/releases/tag/nightly)
* **Direct Download Asset:** [`droidian-OFFICIAL-phosh-phone-rootfs-api30-arm64-next_20260927.zip`](https://github.com/droidian-images/droidian/releases/download/nightly/droidian-OFFICIAL-phosh-phone-rootfs-api30-arm64-next_20260927.zip)
*(Or any recent `droidian-OFFICIAL-*-rootfs-api30-arm64-*.zip` from the nightly releases page)*

---

## ⚡ Complete Installation Guide

### Step 1: Test-Boot Kernel (Zero Risk)
Put the phone into fastboot mode and live-boot the compiled kernel to test stability:
```bash
adb reboot bootloader
fastboot boot boot-halium11-docker-redfin.img
```
Once booted, verify the kernel in ADB:
```bash
adb shell uname -a
```
If it boots normally without rebooting, proceed to flash permanently:
```bash
adb reboot bootloader
fastboot flash boot_b boot-halium11-docker-redfin.img
```
*(Replace `boot_b` with your active slot: `boot_a` or `boot_b`)*

---

### Step 2: Boot TWRP Recovery
With the phone in fastboot mode, live-boot TWRP:
```bash
fastboot boot twrp-3.7.0_11-0-redfin.img
```
The phone will boot directly into the TWRP graphical touch recovery.

---

### Step 3: Format Data Partition
Android uses hardware-backed file-based encryption (`fscrypt`) which prevents Linux from mounting `/data` (`userdata`).
1. In TWRP, go to: **Wipe** > **Format Data**.
2. Type `yes` and confirm.
3. Go to **Advanced** > **ADB Sideload**, and swipe to start sideload mode.

---

### Step 4: Sideload Halium 11 Rootfs
From your computer terminal, sideload the downloaded rootfs zip:
```bash
adb sideload droidian-OFFICIAL-phosh-phone-rootfs-api30-arm64-next_20260927.zip
```
TWRP will unpack the rootfs into `/data/rootfs.img`.
Once sideloading finishes, select **Reboot System** in TWRP.

---

### Step 5: Connect to Linux via USB-C
When Halium 11 boots, it exposes a USB Ethernet RNDIS interface:
1. Connect via SSH:
   ```bash
   ssh droidian@192.168.2.15
   ```
   *(Default password: `1234` or root access via `sudo -i`)*

---

### Step 6: Configure Fullscreen OLED Terminal (No Desktop)
Since we want a terminal-only environment without the Phosh UI:
```bash
# 1. Stop and disable heavy graphical desktop services
sudo systemctl stop phosh
sudo systemctl disable phosh

# 2. Install lightweight Wayland kiosk and GPU terminal (foot)
sudo apt update
sudo apt install -y cage foot

# 3. Create a systemd service to launch foot in fullscreen kiosk mode on the 90Hz OLED
sudo nano /etc/systemd/system/terminal-kiosk.service
```

Add the following service configuration:
```ini
[Unit]
Description=Fullscreen Terminal Kiosk
After=systemd-user-sessions.service

[Service]
User=droidian
Environment=XDG_RUNTIME_DIR=/run/user/10000
Environment=WLR_RENDERER=gles2
ExecStart=/usr/bin/cage -s -- /usr/bin/foot --fullscreen
Restart=always

[Install]
WantedBy=graphical.target
```
Enable the terminal kiosk:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now terminal-kiosk
```

---

### Step 7: Connect Wi-Fi & Install Docker

1. **Connect Wi-Fi:**
   ```bash
   nmcli dev wifi list
   nmcli dev wifi connect "YOUR_SSID" password "YOUR_PASSWORD"
   ```

2. **Install Docker:**
   ```bash
   sudo apt update
   sudo apt install -y docker.io containerd
   sudo systemctl enable --now docker
   sudo usermod -aG docker droidian
   ```

3. **Verify Native Docker:**
   ```bash
   docker run --rm hello-world
   docker run -it --rm alpine sh
   ```
