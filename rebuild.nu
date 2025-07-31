#!/usr/bin/env nu

def --wrapped sync [
  ...arguments
] {
  (rsync
      --archive
      --compress
      --delete --recursive --force
      --delete-excluded
      --delete-missing-args
      --human-readable
      --delay-updates
      --no-owner --no-group
      ...$arguments)
}

# Rebuild a NixOS / Darwin config.
def main --wrapped [
  host: string = ""                 # The host to build.
  --remote (-r)                     # Whether if this is a remote host. The config will be built on this host if it is.
  --addr (-a): string               # The IP address of the host to build.
  --identity (-i): string           # The SSH identity to use for the remote host.
  --first (-f)                      # Whether if this is the first time building this host.
  --dont-add-git-or-update-flake    # Whether to not add changes to git.
  ...arguments                      # The arguments to pass to `nh {os,darwin} switch` and `nix` (separated by --).
]: nothing -> nothing {
  if not ($dont_add_git_or_update_flake) {
    nix flake update
    git add -A
  }

  let host = if ($host | is-not-empty) {
    if $host != (hostname) and not $remote {
      print $"(ansi yellow_bold)warn:(ansi reset) building local configuration for hostname that does not match the local machine"
    }

    $host
  } else if $remote {
    print $"(ansi red_bold)error:(ansi reset) hostname not specified for remote build"
    exit 1
  } else {
    (hostname)
  }
  let remote_ip = if ($addr | is-empty) { $host } else { $addr }

  if (nix eval --extra-experimental-features nix-command --impure --expr $"\(import ./keys.nix\).($host) or null") == "null" {
    let host_pubkey = if $remote {
      ssh -o BatchMode=yes -o StrictHostKeyChecking=no $remote_ip "cat /etc/ssh/ssh_host_ed25519_key.pub"
    } else {
      cat /etc/ssh/ssh_host_ed25519_key.pub
    }
    print $"adding host ($host) with public key ($host_pubkey) to keys.nix"
    (awk $'NR==2{print; print "    ($host) = \"($host_pubkey)\";"; next} {print}' ./keys.nix)
      | complete
      | get stdout
      | save -f ./keys.nix

    # rekey secrets (see nushell config)
    nixfmt ./keys.nix
    sudo agenix -r -i /etc/ssh/ssh_host_ed25519_key
  }

  if $remote {
    git ls-files
      | xargs dirname
      | ^sort -u
      | sync --files-from - ./ $"($remote_ip):.nix"

    let cmd = (if $first {
      $'NIX_CONFIG="experimental-features = nix-command flakes" NH_BYPASS_ROOT_CHECK=true nix-shell -p nushell -p nh --run "./rebuild.nu ($host) --dont-add-git-or-update-flake --first"'
    } else {
      $'./rebuild.nu ($host) --dont-add-git-or-update-flake ($arguments | str join " ")'
    })
    ssh -tt $remote_ip $"
      cd .nix
      ($cmd)
      (if $first { 'rm -rf ~/.nix' } else { '' })
    "

    return
  }

  let args_split = $arguments | prepend "" | split list "--"
  let nh_flags = [
    "--hostname" $host
  ] | append ($args_split | get 0 | where { $in != "" })

  let nix_flags = [
    "--option" "accept-flake-config" "true"
    "--option" "eval-cache"          "false"
  ]
    | append (if $first { [
      "--extra-experimental-features" "pipe-operators"
      "--extra-experimental-features" "nix-command"
      "--extra-experimental-features" "flakes"
    ] } else { [] })
    | append ($args_split | get --ignore-errors 1 | default [])

  if (uname | get kernel-name) == "Darwin" {
    nh darwin switch . ...$nh_flags -- ...$nix_flags
  } else {
    if $first {
      nh os boot . ...$nh_flags -- ...$nix_flags
      print $"(ansi yellow_bold)warn:(ansi reset) first time building this host, please re"
    } else {
      nh os switch . ...$nh_flags -- ...$nix_flags
    }
  }
}
