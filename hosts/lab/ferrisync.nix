# ferrisync's benchmark runs: the LAN ports its runs listen on, and a root helper that drops the
# page cache before a cold-cache run. Deleting this file undoes both on the next switch.
{ pkgs, ... }:
let
  lan = "ens18";
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
      case "''${1:-}" in
        drop-caches)
          sync
          echo 3 > /proc/sys/vm/drop_caches
          ;;
        *) echo "usage: ferrisync-bench drop-caches" >&2; exit 2 ;;
      esac
    '';
  };
in
{
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
          command = "/run/current-system/sw/bin/ferrisync-bench";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
