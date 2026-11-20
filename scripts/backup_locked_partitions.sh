#!/system/bin/sh
# Pre-unlock factory partition & key backup script for Sony Xperia 1 IV (pdx223)
# Run as uid=0 (via DirtyFrag / GhostLock temporary root) BEFORE fastboot oem unlock.
set -e

OUT="/sdcard/xperia_locked_backup"
mkdir -p "$OUT"

getprop > "$OUT/build_props.txt"
cat /proc/partitions > "$OUT/proc_partitions.txt"
ls -la /dev/block/bootdevice/by-name/ > "$OUT/by_name_links.txt"

PARTITIONS="TA LTALabel persist xflkeystore xflkeystorebak fsg fsc modemst1 modemst2 ssd devinfo ddr spunvm storsec cdt keystore secdata uefivarstore connsec tzsc tzxflattest_a tzxflattest_b qweslicstore_a qweslicstore_b keymaster_a keymaster_b tz_a tz_b abl_a abl_b uefisecapp_a uefisecapp_b boot_a boot_b dtbo_a dtbo_b vbmeta_a vbmeta_b vbmeta_system_a vbmeta_system_b vendor_boot_a vendor_boot_b"

for p in $PARTITIONS; do
  if [ -e "/dev/block/bootdevice/by-name/$p" ]; then
    echo "Dumping $p..."
    dd if="/dev/block/bootdevice/by-name/$p" of="$OUT/${p}.img" bs=4096 2>/dev/null
  fi
done

tar -czf "$OUT/mnt_vendor_persist_files.tar.gz" -C /mnt/vendor/persist . 2>/dev/null || true
cd "$OUT"
sha256sum *.img *.tar.gz *.txt > SHA256SUMS.txt
echo "Backup complete in $OUT. Pull to PC and verify with: sha256sum -c SHA256SUMS.txt"
