#!/system/bin/sh
# Fixes Android 17 (SDK 37) priv_app_36 SELinux denials for Dolby Atmos Magisk module
set -e

RULE="/data/adb/modules/DolbyAtmos/sepolicy.rule"
if [ ! -f "$RULE" ]; then
  echo "DolbyAtmos sepolicy.rule not found at $RULE"
  exit 1
fi

# Add priv_app_36 alongside priv_app in all rules
if ! grep -q "priv_app_36" "$RULE"; then
  sed -i 's/priv_app /priv_app priv_app_36 /g' "$RULE"
  sed -i 's/allow priv_app priv_app_36 priv_app/allow { priv_app priv_app_36 } { priv_app priv_app_36 }/g' "$RULE"
fi

# Apply key rules live
magiskpolicy --live "allow priv_app_36 default_android_hwservice hwservice_manager find"
magiskpolicy --live "allow priv_app_36 vendor_default_prop file { read open getattr map }"
magiskpolicy --live "allow priv_app_36 audio_config_prop file { read open getattr map }"
magiskpolicy --live "allow audioserver priv_app_36 fifo_file write"
magiskpolicy --live "allow hal_audio_default priv_app_36 fifo_file write"

# Restart DaxService and UI cleanly
PIDS=$(pidof com.dolby.daxservice com.dolby.daxappui2 2>/dev/null || true)
[ -n "$PIDS" ] && kill -9 $PIDS 2>/dev/null || true
echo "DolbyAtmos SELinux rules patched for Android 17 (priv_app_36) and DaxService restarted."
