#!/system/bin/sh
# Installs persistent Magisk module + Termux CLI to enable Sony's native
# DSEE Ultimate (dsee_hx_state=1) and Intelligent Wind Filter (wind_nr_enabled=1)
# in /vendor/lib64/libar-pal.so on LineageOS 24.0 (pdx223).
set -e

MOD="/data/adb/modules/sony_audio_enhancements"
PREFIX="/data/data/com.termux/files/usr"
TERMUX_UID=$(stat -c %u /data/data/com.termux)
TERMUX_CTX=$(stat -c %C "$PREFIX")

mkdir -p "$MOD"
cat << 'EOF' > "$MOD/module.prop"
id=sony_audio_enhancements
name=Sony Xperia DSEE Ultimate & Intelligent Wind Filter
version=v1.0
versionCode=1
author=mihai2mn
description=Enables native Sony PAL Audio HAL DSEE Ultimate (dsee_hx_state=1) and Intelligent Wind Filter (wind_nr_enabled=1) on LineageOS.
EOF

cat << 'EOF' > /data/adb/sony_audio.conf
DSEE_ULTIMATE=1
WIND_FILTER=1
EOF

cat << 'EOF' > "$MOD/service.sh"
#!/system/bin/sh
while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 2; done
sleep 3
[ -f /data/adb/sony_audio.conf ] && . /data/adb/sony_audio.conf
DSEE_VAL="${DSEE_ULTIMATE:-1}"
WIND_VAL="${WIND_FILTER:-1}"
CTX_D=$(stat -c %C /data/vendor/audio/dsee_params_0 2>/dev/null || echo "u:object_r:audio_vendor_data_file:s0")
CTX_W=$(stat -c %C /data/vendor/audio/wind_nr_params_0 2>/dev/null || echo "u:object_r:audio_vendor_data_file:s0")
printf "dsee_hx_state:%s" "$DSEE_VAL" > /data/vendor/audio/dsee_params_0
printf "wind_nr_enabled:%s" "$WIND_VAL" > /data/vendor/audio/wind_nr_params_0
chown audioserver:audio /data/vendor/audio/dsee_params_0 /data/vendor/audio/wind_nr_params_0
chmod 600 /data/vendor/audio/dsee_params_0 /data/vendor/audio/wind_nr_params_0
chcon "$CTX_D" /data/vendor/audio/dsee_params_0 2>/dev/null || true
chcon "$CTX_W" /data/vendor/audio/wind_nr_params_0 2>/dev/null || true
EOF
chmod 755 "$MOD/service.sh"

cat << 'EOF' > "$PREFIX/bin/sony-audio"
#!/data/data/com.termux/files/usr/bin/bash
exec su -c '
  CONF=/data/adb/sony_audio.conf
  [ -f "$CONF" ] && . "$CONF"
  case "$1" in
    dsee)
      val=$([ "$2" = "on" -o "$2" = "1" ] && echo 1 || echo 0)
      sed -i "s/^DSEE_ULTIMATE=.*/DSEE_ULTIMATE=$val/" "$CONF"
      printf "dsee_hx_state:%s" "$val" > /data/vendor/audio/dsee_params_0
      chown audioserver:audio /data/vendor/audio/dsee_params_0 && chmod 600 /data/vendor/audio/dsee_params_0
      killall android.hardware.audio.service audioserver 2>/dev/null || true
      echo "DSEE Ultimate set to $val (audio HAL restarted)"
      ;;
    wind)
      val=$([ "$2" = "on" -o "$2" = "1" ] && echo 1 || echo 0)
      sed -i "s/^WIND_FILTER=.*/WIND_FILTER=$val/" "$CONF"
      printf "wind_nr_enabled:%s" "$val" > /data/vendor/audio/wind_nr_params_0
      chown audioserver:audio /data/vendor/audio/wind_nr_params_0 && chmod 600 /data/vendor/audio/wind_nr_params_0
      killall android.hardware.audio.service audioserver 2>/dev/null || true
      echo "Intelligent Wind Filter set to $val (audio HAL restarted)"
      ;;
    *)
      echo "DSEE Ultimate: $(cat /data/vendor/audio/dsee_params_0)"
      echo "Wind Filter:   $(cat /data/vendor/audio/wind_nr_params_0)"
      echo "Usage: sony-audio [status | dsee on|off | wind on|off]"
      ;;
  esac
' -- "$@"
EOF
chown "$TERMUX_UID:$TERMUX_UID" "$PREFIX/bin/sony-audio"
chmod 755 "$PREFIX/bin/sony-audio"
chcon "$TERMUX_CTX" "$PREFIX/bin/sony-audio"

sh "$MOD/service.sh"
killall android.hardware.audio.service audioserver 2>/dev/null || true
echo "Done! DSEE Ultimate and Intelligent Wind Filter enabled."
