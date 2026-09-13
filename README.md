# Pixel 5 (`redfin`) LineageOS 23.2 Docker Kernel Builder

Automated GitHub Actions workflow to build a custom Linux 4.19 kernel for the Google Pixel 5 with full container/Docker support.

## Features Added:
- `CONFIG_PID_NS=y` (Process ID Namespaces)
- `CONFIG_USER_NS=y` (User Namespaces)
- `CONFIG_FAIR_GROUP_SCHED=y` & `CONFIG_CFS_BANDWIDTH=y` (CPU quota)
- `CONFIG_CGROUP_DEVICE=y` (Device whitelist isolation)
- `CONFIG_CGROUP_PIDS=y` (Fork-bomb protection)
- `CONFIG_BRIDGE_NETFILTER=y` & `CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y` (Container bridge routing & port forwarding)
- `CONFIG_POSIX_MQUEUE=y`

## How to Run:
1. Go to the **Actions** tab in this GitHub repository.
2. Select **Build Pixel 5 Docker Kernel** from the left menu.
3. Click **Run workflow** -> **Run workflow**.
4. In ~8-10 minutes, download the generated artifacts (`boot-docker-redfin.img` and `AnyKernel3-LineageOS23.2-Docker-redfin.zip`).
