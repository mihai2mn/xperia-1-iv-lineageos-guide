#!/system/bin/sh
# Wraps installed Sony Photography Pro (1.5.2.A.0.23), Videography Pro (1.4.1.A.0.23),
# and Cinema Pro (1.9.1.A.0.21) into a systemless /product/priv-app Magisk module.
set -e

MOD="/data/adb/modules/sony_camera_suite"
rm -rf "$MOD"
mkdir -p "$MOD/system/product/priv-app/PhotoPro" \
         "$MOD/system/product/priv-app/VideoPro" \
         "$MOD/system/product/priv-app/CinemaPro" \
         "$MOD/system/product/etc/permissions" \
         "$MOD/system/etc/permissions"

cat << 'EOF' > "$MOD/module.prop"
id=sony_camera_suite
name=Sony Xperia 1 IV Pro Camera Suite
version=v1.0 (PhotoPro 1.5.2, VideoPro 1.4.1, CinemaPro 1.9.1)
versionCode=1
author=mihai2mn
description=Systemlessly mounts Sony Photography Pro, Videography Pro, and Cinema Pro as privileged system apps for full hardware shutter and lock-screen support.
EOF

copy_pkg() {
  pkg="$1"
  dir="$2"
  src=$(dirname "$(pm path "$pkg" | head -n 1 | cut -d: -f2)")
  cp "$src/base.apk" "$MOD/system/product/priv-app/$dir/${dir}.apk"
  [ -d "$src/lib" ] && cp -r "$src/lib" "$MOD/system/product/priv-app/$dir/"
}

copy_pkg "com.sonymobile.photopro" "PhotoPro"
copy_pkg "jp.co.sony.mc.videopro" "VideoPro"
copy_pkg "com.sonymobile.cinemapro" "CinemaPro"

cat << 'EOF' > "$MOD/system/product/etc/permissions/privapp-permissions-sony-camera.xml"
<permissions>
    <privapp-permissions package="com.sonymobile.photopro">
        <permission name="android.permission.WRITE_SECURE_SETTINGS"/>
        <permission name="com.sonymobile.permission.SOMC_CAMERA"/>
        <permission name="com.sonymobile.permission.CAMERA_ADDON"/>
        <permission name="com.sonymobile.permission.CAMERA_STATUS_PROVIDER"/>
    </privapp-permissions>
    <privapp-permissions package="jp.co.sony.mc.videopro">
        <permission name="com.sonymobile.permission.SOMC_CAMERA"/>
        <permission name="com.sonymobile.permission.CAMERA_ADDON"/>
        <permission name="com.sonymobile.permission.CAMERA_STATUS_PROVIDER"/>
    </privapp-permissions>
    <privapp-permissions package="com.sonymobile.cinemapro">
        <permission name="com.sonymobile.permission.SOMC_CAMERA"/>
        <permission name="com.sonymobile.permission.CAMERA_ADDON"/>
        <permission name="com.sonymobile.permission.CAMERA_STATUS_PROVIDER"/>
    </privapp-permissions>
</permissions>
EOF
cp "$MOD/system/product/etc/permissions/privapp-permissions-sony-camera.xml" \
   "$MOD/system/etc/permissions/privapp-permissions-sony-camera.xml"

chmod -R 755 "$MOD/system"
find "$MOD/system" -type f -exec chmod 644 {} +

pm grant com.sonymobile.photopro android.permission.WRITE_SECURE_SETTINGS 2>/dev/null || true
echo "sony_camera_suite Magisk module created. Reboot to mount in /product/priv-app/."
