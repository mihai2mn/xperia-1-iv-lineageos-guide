# Sony Xperia 1 IV (`pdx223` / `XQ-CT54`) — LineageOS 24.0 (Android 17), Root, Native Sony Features & Portable AI CLI Guide

A complete, battle-tested guide and collection of custom Magisk modules, SELinux fixes, and scripts for turning a **Sony Xperia 1 IV (`XQ-CT54` / `XQ-CT72` / `XQ-CT44`, Snapdragon 8 Gen 1 `SM8450` / `WAIPIO`)** into a modern **Android 17 (LineageOS 24.0)** daily driver and **portable rooted Arch Linux ARM (`aarch64` `glibc`) AI CLI workstation**—while preserving your factory keys and native Sony camera/audio features.

> **Disclaimer:** Unlocking bootloaders and flashing custom ROMs wipes `/data` and carries inherent risk. Always verify your exact model (`XQ-CT44`, `XQ-CT54`, `XQ-CT72`—US `XQ-CT62` and Japanese carrier variants are generally not officially unlockable) and back up personal data first.

---

## Table of Contents
1. [Phase 1: Pre-Unlock Factory Key & TA Partition Backup](#phase-1-pre-unlock-factory-key--ta-partition-backup)
2. [Phase 2: Bootloader Unlock, LineageOS 24.0 & Magisk](#phase-2-bootloader-unlock-lineageos-240--magisk)
3. [Phase 3: De-Googled Stack (microG v0.3.18 + PlayIntegrityFork + TrickyStore)](#phase-3-de-googled-stack-microg-v0318--playintegrityfork--trickystore)
4. [Phase 4: Native Sony Pro Camera Suite & Gyro Stabilization Fix](#phase-4-native-sony-pro-camera-suite--gyro-stabilization-fix)
5. [Phase 5: Native Sony Audio Stack (Dolby Atmos + DSEE Ultimate + Wind Filter)](#phase-5-native-sony-audio-stack-dolby-atmos--dsee-ultimate--wind-filter)
6. [Phase 6: Portable Rooted AI CLI & Bare-Metal Arch Linux ARM (`aarch64`) Node](#phase-6-portable-rooted-ai-cli--bare-metal-arch-linux-arm-aarch64-node)

---

## Phase 1: Pre-Unlock Factory Key & TA Partition Backup

Stock Android 14 on the Xperia 1 IV (`64.2.A.2.258`, kernel `5.10.218-android12-9-...`) sits below the Linux `5.10.255` / `5.10.261` security patch floors, meaning you can obtain **temporary RAM-only root (`uid=0`) while the bootloader is still locked** using:
- **DirtyFrag (`CVE-2026-43284`)** + **KernelSU Next** (deterministic, zero kernel panics)
- **GhostLock (`CVE-2026-43499`)** (`JoinChang/ghostlock-oneplus` includes a built-in `xperia1iv` offset profile for `5.10.218`)

### Why Back Up Before Unlocking?
Binary diffing `TA.img` before and after `fastboot oem unlock` confirms that unlocking deletes **TA Unit `0x1046B` (`66667`, 16 bytes)**—your device-unique Sony factory master key. Dumping `TA.img`, `persist.img`, `/mnt/vendor/persist`, keystores, and modem NVRAM *before* unlocking preserves a 100% factory snapshot.

1. Enable **USB Debugging** and **OEM Unlocking** in Developer Options.
2. Install **KernelSU Next** and **DirtyFrag**, select KernelSU Next in DirtyFrag, and run the exploit.
3. Grant `su` to **Shell** (`com.android.shell`) in KernelSU Next.
4. Run [`scripts/backup_locked_partitions.sh`](scripts/backup_locked_partitions.sh) over ADB to dump 42 critical partitions (`TA`, `persist`, `xflkeystore`, `tzxflattest_a/b`, `qweslicstore_a/b`, `modemst1/2`, `fsg`, `fsc`, stock boot/TEE stack) and verify SHA-256 checksums.

> **CRITICAL WARNING:** **Never** write `TA.img` back to `/dev/block/bootdevice/by-name/TA` while running a custom ROM. On Sony's `X_Boot` bootloader, the presence of TA Unit `0x1046B` signals a **locked** bootloader and will immediately block unsigned ROMs (`"Your device is corrupt"`). Keep `TA.img` strictly for a full return to stock Sony firmware.

---

## Phase 2: Bootloader Unlock, LineageOS 24.0 & Magisk

1. Remove all Google accounts from the phone (avoids FRP lock) and verify calls/SMS/VoLTE work on stock Android 14.
2. Get your unlock code from [Sony Open Devices](https://developer.sony.com/develop/open-devices/get-started/unlock-bootloader) using **IMEI 1** (`*#06#`).
3. Reboot to fastboot (`adb reboot bootloader`) and unlock:
   ```bash
   fastboot oem unlock 0x<YOUR_UNLOCK_CODE>
   fastboot reboot bootloader
   fastboot getvar unlocked   # should return: yes
   ```
4. Flash the official LineageOS 24.0 (`pdx223`) boot stack, reboot bootloader, then flash recovery:
   ```bash
   fastboot flash boot boot.img
   fastboot flash dtbo dtbo.img
   fastboot flash vbmeta vbmeta.img
   fastboot flash vendor_boot vendor_boot.img
   fastboot reboot bootloader
   fastboot flash recovery recovery.img
   fastboot reboot recovery
   ```
5. In **LineageOS Recovery**:
   - **Apply update → Apply from ADB** → `adb sideload copy-partitions-20220613-signed.zip` (tap **Yes** at signature warning).
   - **Advanced → Reboot to recovery**.
   - **Factory reset → Format data / factory reset**.
   - **Apply update → Apply from ADB** → `adb sideload lineage-24.0-*-nightly-pdx223-signed.zip`.
   - Tap **Yes** when prompted to reboot to recovery (switches to the newly flashed A/B slot).
   - **Apply update → Apply from ADB** → `adb sideload Magisk-v31.1.zip` (renamed from `Magisk-v31.1.apk`).
   - **Reboot system now**.
6. Once booted into Android 17, install `Magisk-v31.1.apk`, open Magisk → **Install → Direct Install (Recommended)** → reboot, and enable **Zygisk** + **DenyList** in Magisk Settings.

*(Why Magisk instead of KernelSU? Official LineageOS 24.0 for `pdx223` builds a custom inline `5.10.269-gki` kernel without `CONFIG_KSU=y` or stock GKI KMI strings, so Magisk works out-of-the-box and survives LineageOS OTAs automatically via `addon.d`.)*

---

## Phase 3: De-Googled Stack (microG v0.3.18 + PlayIntegrityFork + TrickyStore)

Official LineageOS 24.0 includes native signature spoofing restricted to microG's signing key.

1. Install official **microG Services (`com.google.android.gms` v0.3.18+)** and **microG Companion (`com.android.vending`)**, plus **F-Droid** and **Aurora Store**.
2. Use [`configs/privapp-permissions-org.microG.xml`](configs/privapp-permissions-org.microG.xml) inside `microG_Installer_Revived` (adds `DUMP`, `INTERACT_ACROSS_USERS`, and `PROVIDE_DEFAULT_ENABLED_CREDENTIAL_SERVICE` required by `v0.3.18+`) and flash via Magisk so microG mounts systemlessly into `/product/priv-app/GmsCore`.
3. In **microG Settings**, enable **Google device registration**, **Cloud Messaging** (optional), and **Play Integrity / SafetyNet**.
4. Install **PlayIntegrityFork (`v19`)** and **TrickyStore (`v1.4.1`)** via Magisk, then run `autopif4.sh` and set `DEVICE_INITIAL_SDK_INT=32` / `ro.product.first_api_level=32` in `custom.pif.prop` for `<A13` attestation.
5. Add banking/sensitive apps to **Magisk DenyList** and `/data/adb/tricky_store/target.txt`.

> **Note on microG vs. MindTheGapps:** microG passes `MEETS_BASIC_INTEGRITY` and keeps RAM usage ~600–800 MB lower with zero Google telemetry. If you require **Google Wallet NFC tap-to-pay** or apps that strictly demand `MEETS_DEVICE_INTEGRITY`, use minimal `MindTheGapps` instead.

---

## Phase 4: Native Sony Pro Camera Suite & Gyro Stabilization Fix

LineageOS 24.0 for `pdx223` already ships Sony's full `vendor.somc.hardware.camera.provider@1.0-service` HAL, `libsomc_*` BIONZ XR libraries, `SUN12BS0` lens calibrations, and `com.sony.device` stubs.

1. Install the **exact Xperia 1 IV stock APK versions** (newer Mark V/VI builds crash on the 85–125mm continuous optical zoom lens):
   - **Photography Pro:** `1.5.2.A.0.23` (`com.sonymobile.photopro`)
   - **Videography Pro:** `1.4.1.A.0.23` (`jp.co.sony.mc.videopro`)
   - **Cinema Pro:** `1.9.1.A.0.21` (`com.sonymobile.cinemapro`)
2. Run [`scripts/setup_sony_camera_module.sh`](scripts/setup_sony_camera_module.sh) to wrap all three apps and [`configs/privapp-permissions-sony-camera.xml`](configs/privapp-permissions-sony-camera.xml) into a systemless `/product/priv-app/` Magisk module (`sony_camera_suite`) so `WRITE_SECURE_SETTINGS`, `SOMC_CAMERA`, high-frequency gyro DirectChannel, and lock-screen shutter button launch work cleanly.
3. **Shaky Stabilization Fix:** If video stabilization feels shaky after flashing, restore your factory `sns_gyro_cal*` files from your pre-unlock `/mnt/vendor/persist/sensors/registry/registry/` backup (`chown system:system`, `chmod 600`) and reboot.
4. *(Optional)* For third-party camera apps (Aperture, Open Camera, GCam), install **Vector (LSPosed v2.2)** + **[Sony Camera Unlocker (`stoutput/xperia-camera-mod`)](https://github.com/stoutput/xperia-camera-mod)** to inject Sony's BIONZ XR Camera2 vendor tags. Leave Sony's own Pro apps unchecked in Vector's scope.

---

## Phase 5: Native Sony Audio Stack (Dolby Atmos + DSEE Ultimate + Wind Filter)

### 1. Native DSEE Ultimate & Intelligent Wind Filter (Already in `/vendor`!)
Inspecting `/vendor/lib64/libar-pal.so` and `/vendor/etc/audio/sku_taro/audio_effects.xml` reveals that Sony's **DSEE Ultimate (`SonyDSEE` / `libsonydseehxwrapper.so`)** and **Intelligent Wind Filter (`SonyWindNR` / `libdnnrwrapper.so`)** are already compiled into your LineageOS 24.0 vendor partition—they are just set to `:0` in `/data/vendor/audio/dsee_params_0` and `/data/vendor/audio/wind_nr_params_0`.

Run [`scripts/setup_sony_audio.sh`](scripts/setup_sony_audio.sh) to install the persistent `sony_audio_enhancements` Magisk module + `sony-audio` Termux CLI:
```bash
sony-audio status
sony-audio dsee on|off
sony-audio wind on|off
```

### 2. Dolby Atmos (Android 17 `priv_app_36` SELinux Fix)
If you flash `reiryuki`'s **Dolby Atmos Sony Xperia 5 V** Magisk module on Android 17 (`SDK 37`), `daxService` runs in the new `priv_app_36` SELinux domain and gets blocked from finding `vendor.dolby.hardware.dms::IDms`.

Run [`scripts/fix_dolby_android17_sepolicy.sh`](scripts/fix_dolby_android17_sepolicy.sh) to mirror all `priv_app` rules to `priv_app_36` in `/data/adb/modules/DolbyAtmos/sepolicy.rule`, apply them live, and restart `com.dolby.daxservice`.

---

## Phase 6: Portable Rooted AI CLI & Bare-Metal Arch Linux ARM (`aarch64`) Node

Because AI CLIs like **Claude Code**, **Antigravity CLI (`agy`)**, and **Happy (`happy`)** ship `linux-arm64` (`glibc`) binaries rather than Android-bionic binaries, we run them inside a **bare-metal kernel `chroot` of Arch Linux ARM (`aarch64` `glibc`)** (0% `proot`/`ptrace` overhead) with an `nsenter` bridge back into Android's root namespace.

1. Install **Termux**, **Termux:API** (matching GitHub release signature), **Termux:X11**, and **Tailscale**.
2. Copy [`configs/termux.properties`](configs/termux.properties) to `~/.termux/termux.properties` for a 2-row AI CLI hotkey bar (`ESC`, `/`, `@`, `TAB`, `CTRL`, `ALT`, arrows).
3. Run [`scripts/setup_ai_chroot.sh`](scripts/setup_ai_chroot.sh) to:
   - Install `agners/archlinuxarm:latest` (`aarch64` `glibc`) via `proot-distro`.
   - Tune `/etc/makepkg.conf` for **Snapdragon 8 Gen 1 (`SM8450` / `WAIPIO`, Cortex-X2/A710/A510)** using the exact kernel-exposed ISA flags (`-march=armv8.5-a+crypto+sha3+sm4+dotprod+fp16+fp16fml+i8mm+pauth+bti -mtune=cortex-x2 -O3`, avoiding unexposed SVE/BF16).
   - Create `arch-root` (bare-metal `mount --bind` + `chroot` launcher) and `android-sh` (`nsenter -t 1 -m` bridge to Android root).
   - Wrap Android root tools (`getprop`, `pm`, `am`, `cmd`, `dumpsys`, `screencap`, `input`, `uiautomator`, `magisk`, `settings`, `wm`) into `/usr/local/bin/` inside Arch + write `/root/CLAUDE.md`.
   - Install **Claude Code (`claude`)**, **Antigravity CLI (`agy`)**, and **Happy (`happy`)** inside Arch, plus Termux wrapper commands (`claude`, `agy`, `happy`, `arch-root`, `gui`).
4. **Better Mobile UX:**
   - **Termius (SSH):** Start `sshd` in Termux (`passwd` to set a password), then connect Termius via SSH to `127.0.0.1:8022` (username `u0_aXXX`).
   - **Termux:X11:** Run `gui` in Termux to launch a full-screen 120Hz `xfce4-terminal` inside the **Termux:X11** Android app.

> **SELinux Tip for Termux:** If you ever run `apt-get` or create files inside `/data/data/com.termux/files/usr` from ADB `su`, always restore Termux's SELinux MCS context (`chcon -hR "$(stat -c %C /data/data/com.termux/files/usr)" /data/data/com.termux/files/usr/bin /data/data/com.termux/files/usr/lib`), otherwise Android will deny execution with `Permission denied`.
