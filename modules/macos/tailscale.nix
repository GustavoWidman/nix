# nix-darwin runs tailscaled but never signs it in. this daemon does, with the
# fleet's auth key, the way services.tailscale.authKeyFile does on nixos: once
# at load, only while tailscaled reports it needs a login, and quietly giving
# up after a few tries. a mac already on the tailnet is left alone.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    escapeShellArgs
    getExe
    getExe'
    mkIf
    ;

  tailscale = getExe' config.services.tailscale.package "tailscale";
  jq = getExe pkgs.jq;
  key = config.secrets.tailscale-key.path;
  log = "/var/log/tailscale-autoconnect.log";

  autoconnect = pkgs.writeShellScript "tailscale-autoconnect" ''
    state() {
      ${tailscale} status --json --peers=false 2>/dev/null | ${jq} -r '.BackendState // empty' 2>/dev/null
    }

    # tailscaled starts alongside this daemon: give it two minutes to answer
    current=
    for ((second = 0; second < 120; second++)); do
      current=$(state)
      [ -n "$current" ] && [ "$current" != NoState ] && break
      sleep 1
    done

    if [ "$current" != NeedsLogin ]; then
      echo "tailscaled is ''${current:-not answering}, nothing to do"
      exit 0
    fi

    # agenix decrypts the key at boot too
    for ((second = 0; second < 120; second++)); do
      [ -r ${key} ] && break
      sleep 1
    done

    delay=10
    for attempt in 1 2 3 4 5; do
      if ${tailscale} up --auth-key=file:${key} --timeout=60s ${escapeShellArgs config.tailscale.up-flags}; then
        echo "joined the tailnet"
        exit 0
      fi

      [ "$attempt" = 5 ] || [ "$(state)" != NeedsLogin ] && break
      echo "attempt $attempt failed, retrying in ''${delay}s"
      sleep "$delay"
      delay=$((delay * 2))
    done

    [ "$(state)" = NeedsLogin ] && echo "could not join the tailnet, giving up"
    exit 0
  '';
in
{
  launchd.daemons.tailscale-autoconnect = mkIf config.services.tailscale.enable {
    command = "${autoconnect}";
    serviceConfig = {
      RunAtLoad = true;
      StandardOutPath = log;
      StandardErrorPath = log;
    };
  };
}
