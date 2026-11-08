{
  config,
  lib,
  pkgs,
  ...
}:

let
  user = config.users.users.r3dlust;

  # Case-sensitive APFS volume in the boot container, created once with
  # `diskutil apfs addVolume disk3 APFSX Dev -nomount`.
  volumeUUID = "7790E6B2-A11E-48A2-AAE2-AAA5DC3725CD";
  mountPoint = "${user.home}/GitHub";

  diskutil = "/usr/sbin/diskutil";

  setupVolume = pkgs.writeShellScript "setup-dev-volume" ''
    set -euo pipefail
    PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.findutils
        pkgs.gnugrep
      ]
    }:/usr/bin:/usr/sbin:/bin:/sbin

    uuid=${volumeUUID}
    mount_point=${lib.escapeShellArg mountPoint}
    fstab_line="UUID=$uuid $mount_point apfs rw,noatime,nobrowse,owners"

    volume_info() {
      ${diskutil} info -plist "$uuid" | /usr/bin/plutil -extract "$1" raw -o - - 2>/dev/null || true
    }

    mount_volume() {
      ${diskutil} mount -mountPoint "$mount_point" "$uuid" >/dev/null
    }

    if ! ${diskutil} info "$uuid" >/dev/null 2>&1; then
      echo "warning: APFS volume $uuid not found, $mount_point stays on the system volume" >&2
      exit 0
    fi

    # diskarbitrationd mounts the volume from fstab at boot.
    touch /etc/fstab
    if ! grep -qxF "$fstab_line" /etc/fstab; then
      { grep -vi "^UUID=$uuid " /etc/fstab || true; echo "$fstab_line"; } > /etc/fstab.new
      cat /etc/fstab.new > /etc/fstab
      rm /etc/fstab.new
    fi

    # The directory under the mount point stays root-owned, so nothing lands on
    # the system volume while the volume is unmounted.
    mkdir -p "$mount_point"
    current=$(volume_info MountPoint)
    if [ "$current" != "$mount_point" ]; then
      if [ -n "$current" ]; then
        ${diskutil} unmount "$uuid" >/dev/null
      fi
      mount_volume
    fi
    if [ "$(volume_info MountPoint)" != "$mount_point" ]; then
      echo "error: APFS volume $uuid did not mount at $mount_point" >&2
      exit 1
    fi

    if [ "$(volume_info GlobalPermissionsEnabled)" != "true" ]; then
      ${diskutil} enableOwnership "$uuid" >/dev/null
    fi
    chown ${user.name}:staff "$mount_point"

    # fseventsd reads no_log when a volume mounts and then keeps no event
    # journal for it, so the volume is remounted once after creating it.
    if [ ! -e "$mount_point/.fseventsd/no_log" ]; then
      mkdir -p "$mount_point/.fseventsd"
      touch "$mount_point/.fseventsd/no_log"
      ${diskutil} unmount "$uuid" >/dev/null
      mount_volume
      find "$mount_point/.fseventsd" -mindepth 1 ! -name no_log -delete
    fi

    touch "$mount_point/.metadata_never_index"
    if ! /usr/bin/mdutil -s "$mount_point" | grep -q 'Indexing disabled'; then
      /usr/bin/mdutil -i off "$mount_point" >/dev/null
    fi
  '';
in
{
  # Runs before launchd agents reload, so kache only starts once its store is
  # on the volume.
  system.activationScripts.preActivation.text = lib.mkAfter ''
    echo "setting up the Dev volume at ${mountPoint}..." >&2
    ${setupVolume} || echo "warning: Dev volume setup failed" >&2
  '';

  # kache restores artifacts into target directories with reflinks and
  # hardlinks, which only work within one volume.
  services.kache.settings.cache.local_store = "${mountPoint}/.kache";
}
