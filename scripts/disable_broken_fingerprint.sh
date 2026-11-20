#!/system/bin/sh
# Installs a reversible Magisk module to stop a failing Xperia 1 IV (pdx223)
# fingerprint HAL service from crash-looping, draining battery, and freezing Settings.
set -e

MOD="/data/adb/modules/disable_broken_fingerprint"
rm -rf "$MOD"
mkdir -p "$MOD"

cat << 'EOF' > "$MOD/module.prop"
id=disable_broken_fingerprint
name=Disable Broken Fingerprint HAL (Xperia 1 IV)
version=v1.0
versionCode=1
author=mihai2mn
description=Stops the fingerprint biometric HAL service on boot to prevent crash-loops, idle battery drain, and Settings/SystemUI hangs on Xperia 1 IV units with a failed side fingerprint flex cable.
EOF

cat << 'EOF' > "$MOD/service.sh"
#!/system/bin/sh
# Wait briefly for init to settle, then stop any running fingerprint HAL services.
sleep 5
for svc in $(getprop | grep -E '^\[init\.svc\..*(fingerprint|fps_hal|fpc|egistec|goodix)' | sed -E 's/^\[init\.svc\.([^\]]+)\].*/\1/'); do
    stop "$svc" 2>/dev/null || true
done
EOF

chmod 755 "$MOD/service.sh"
sh "$MOD/service.sh"
echo "disable_broken_fingerprint Magisk module installed and applied."
echo "Remove or disable it in Magisk if you replace the fingerprint flex cable."
