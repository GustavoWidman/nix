# ferrisync's benchmark runs: a reflink-capable scratch volume, the LAN ports its runs listen on,
# and a root helper with fixed subcommands. Deleting this file undoes all of it on the next switch,
# except the volume's image file, which stays at /var/lib/ferrisync/bench.img until removed.
{ pkgs, ... }:
let
  image = "/var/lib/ferrisync/bench.img";
  mountPoint = "/mnt/ferrisync";
  lan = "eno1";
  subnet = "192.168.101.0/24";
  # 19876 is the server port of a research baseline (ParaSync); 45800-45899 is the range
  # ferrisync's direct data streams bind to when told to.
  ports = [
    "19876"
    "45800:45899"
  ];

  helper = pkgs.writeShellApplication {
    name = "ferrisync-bench";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      cpu=/sys/devices/system/cpu
      state=/run/ferrisync-bench

      case "''${1:-}" in
        drop-caches)
          sync
          echo 3 > /proc/sys/vm/drop_caches
          ;;
        governor)
          case "''${2:-}" in
            performance)
              if [ ! -d "$state" ]; then
                mkdir -p "$state"
                for policy in "$cpu"/cpufreq/policy*; do
                  cat "$policy/scaling_governor" > "$state/$(basename "$policy")"
                done
              fi
              for policy in "$cpu"/cpufreq/policy*; do
                echo performance > "$policy/scaling_governor"
              done
              ;;
            default)
              [ -d "$state" ] || exit 0
              for policy in "$cpu"/cpufreq/policy*; do
                cat "$state/$(basename "$policy")" > "$policy/scaling_governor"
              done
              rm -rf "$state"
              ;;
            *) echo "usage: ferrisync-bench governor performance|default" >&2; exit 2 ;;
          esac
          ;;
        *) echo "usage: ferrisync-bench drop-caches | governor performance|default" >&2; exit 2 ;;
      esac
    '';
  };
in
{
  # The root filesystem is ext4, which cannot clone extents. The image holds a btrfs filesystem
  # so a benchmark can measure clone-based writes and extent comparisons on Linux. Direct I/O on
  # the loop device keeps the page cache from holding each block twice.
  systemd.services.ferrisync-bench-volume = {
    description = "Reflink-capable volume for ferrisync benchmarks";
    wantedBy = [ "multi-user.target" ];
    before = [ "systemd-user-sessions.service" ];
    after = [ "local-fs.target" ];
    path = [
      pkgs.btrfs-progs
      pkgs.coreutils
      pkgs.util-linux
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if [ ! -e ${image} ]; then
        mkdir -p "$(dirname ${image})"
        truncate -s 200G ${image}.new
        mkfs.btrfs -q ${image}.new
        mv ${image}.new ${image}
      fi
      mkdir -p ${mountPoint}
      if ! mountpoint -q ${mountPoint}; then
        dev=$(losetup --find --show --direct-io=on ${image})
        mount -o noatime "$dev" ${mountPoint}
      fi
      chown r3dlust:users ${mountPoint}
    '';
    preStop = ''
      if mountpoint -q ${mountPoint}; then
        dev=$(findmnt -no SOURCE ${mountPoint})
        umount ${mountPoint}
        losetup -d "$dev"
      fi
    '';
  };

  # IPv4 from the LAN only; the interface also holds global IPv6 addresses, which stay closed.
  networking.firewall.extraCommands = builtins.concatStringsSep "\n" (
    map (
      port: "iptables -A nixos-fw -i ${lan} -s ${subnet} -p tcp --dport ${port} -j nixos-fw-accept"
    ) ports
  );

  environment.systemPackages = [ helper ];

  security.sudo.extraRules = [
    {
      users = [ "r3dlust" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/poweroff";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/ferrisync-bench";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
