#!/system/bin/sh
# Configures bare-metal Arch Linux ARM (aarch64 glibc) chroot + Android root bridge
# + Snapdragon 8 Gen 1 (SM8450 / Cortex-X2) makepkg.conf + Claude Code, agy, Happy, and Termux:X11 gui.
# Prerequisites: Termux installed, proot-distro install -n archlinux agners/archlinuxarm:latest
set -e

PREFIX="/data/data/com.termux/files/usr"
ARCH_DIR="$PREFIX/var/lib/proot-distro/containers/archlinux/rootfs"
TERMUX_UID=$(stat -c %u /data/data/com.termux)
CTX=$(stat -c %C "$PREFIX")

mkdir -p "$PREFIX/tmp"
chown "$TERMUX_UID:$TERMUX_UID" "$PREFIX/tmp"
chcon "$CTX" "$PREFIX/tmp"

# 1. Bare-metal kernel chroot launcher
cat << 'CHROOT_EOF' > "$PREFIX/bin/arch-root"
#!/data/data/com.termux/files/usr/bin/bash
PREFIX="/data/data/com.termux/files/usr"
ARCH_DIR="$PREFIX/var/lib/proot-distro/containers/archlinux/rootfs"
CMD="$*"
exec su -c "
  unset LD_PRELOAD
  mkdir -p $ARCH_DIR/dev $ARCH_DIR/dev/pts $ARCH_DIR/dev/shm $ARCH_DIR/proc $ARCH_DIR/sys $ARCH_DIR/sdcard $ARCH_DIR/tmp
  mountpoint -q $ARCH_DIR/proc || mount -t proc proc $ARCH_DIR/proc
  mountpoint -q $ARCH_DIR/sys || mount -t sysfs sysfs $ARCH_DIR/sys
  mountpoint -q $ARCH_DIR/dev || mount -o bind /dev $ARCH_DIR/dev
  mountpoint -q $ARCH_DIR/dev/pts || mount -o bind /dev/pts $ARCH_DIR/dev/pts
  mountpoint -q $ARCH_DIR/dev/shm || mount -t tmpfs -o size=512M tmpfs $ARCH_DIR/dev/shm
  mountpoint -q $ARCH_DIR/sdcard || mount -o bind /sdcard $ARCH_DIR/sdcard
  mountpoint -q $ARCH_DIR/tmp || mount -o bind $PREFIX/tmp $ARCH_DIR/tmp
  export PATH=/usr/local/sbin:/usr/local/bin:/usr/bin:/bin:/sbin:/root/.local/bin
  export HOME=/root
  export TERM=xterm-256color
  export CLAUDE_CODE_DISABLE_MOUSE=1
  if [ -z \"\$CMD\" ]; then
    exec chroot $ARCH_DIR /bin/bash -l
  else
    exec chroot $ARCH_DIR /bin/bash -lc \"\$CMD\"
  fi
"
CHROOT_EOF

# 2. Android root namespace bridge inside Arch
cat << 'AND_EOF' > "$ARCH_DIR/usr/local/bin/android-sh"
#!/bin/bash
exec nsenter -t 1 -m -- /system/bin/sh -c "export PATH=/system/bin:/system/xbin:/product/bin:/apex/com.android.runtime/bin:/apex/com.android.art/bin:/data/data/com.termux/files/usr/bin; $*"
AND_EOF
chmod 755 "$ARCH_DIR/usr/local/bin/android-sh"

for cmd in getprop setprop pm am cmd dumpsys screencap input uiautomator service logcat magisk settings wm; do
  cat << EOF > "$ARCH_DIR/usr/local/bin/$cmd"
#!/bin/bash
exec /usr/local/bin/android-sh $cmd "\$@"
EOF
  chmod 755 "$ARCH_DIR/usr/local/bin/$cmd"
done

# 3. Snapdragon 8 Gen 1 (SM8450 / Cortex-X2) compiler flags & chroot pacman fix
sed -i 's/^CheckSpace/#CheckSpace/' "$ARCH_DIR/etc/pacman.conf"
sed -i 's/^CFLAGS=.*/CFLAGS="-march=armv8.5-a+crypto+sha3+sm4+dotprod+fp16+fp16fml+i8mm+pauth+bti -mtune=cortex-x2 -O3 -pipe -fno-plt -fexceptions"/' "$ARCH_DIR/etc/makepkg.conf"
sed -i 's/^#MAKEFLAGS=.*/MAKEFLAGS="-j8"/' "$ARCH_DIR/etc/makepkg.conf"

# 4. Termux wrappers for claude, happy, agy, and gui (Termux:X11)
for tool in claude happy; do
  cat << EOF > "$PREFIX/bin/$tool"
#!/data/data/com.termux/files/usr/bin/bash
exec /data/data/com.termux/files/usr/bin/arch-root /usr/bin/$tool "\$@"
EOF
done

cat << 'EOF' > "$PREFIX/bin/agy"
#!/data/data/com.termux/files/usr/bin/bash
exec /data/data/com.termux/files/usr/bin/arch-root /root/.local/bin/agy "$@"
EOF

cat << 'GUI_EOF' > "$PREFIX/bin/gui"
#!/data/data/com.termux/files/usr/bin/bash
pkill -f "termux.x11" 2>/dev/null || true
export XDG_RUNTIME_DIR="${TMPDIR:-/data/data/com.termux/files/usr/tmp}"
export TMPDIR="${TMPDIR:-/data/data/com.termux/files/usr/tmp}"
termux-x11 :0 -ac >/dev/null 2>&1 &
sleep 1
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1
exec /data/data/com.termux/files/usr/bin/arch-root "export DISPLAY=:0; export XDG_RUNTIME_DIR=/tmp/runtime-root; mkdir -p /tmp/runtime-root; exec xfce4-terminal --maximize"
GUI_EOF

for f in arch-root claude happy agy gui; do
  chown "$TERMUX_UID:$TERMUX_UID" "$PREFIX/bin/$f"
  chmod 755 "$PREFIX/bin/$f"
  chcon "$CTX" "$PREFIX/bin/$f"
done

echo "AI chroot launchers and Android root bridge configured."
