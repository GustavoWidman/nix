#!/usr/bin/env nu

def --wrapped sync [...arguments] {
 (sudo rsync
    -e 'ssh -i /etc/ssh/ssh_host_ed25519_key'
    --archive
    --compress

    --delete --recursive --force
    --delete-excluded

    --human-readable
    --delay-updates
    ...$arguments)
}

# Rebuild a NixOS / Darwin config.
def main --wrapped [
  host: string = ""     # The host to build.
  --remote (-r)         # Whether if this is a remote host. The config will be built on this host if it is.
  --ip (-i): string     # The IP address of the host to build.
  --first (-f)          # Whether if this is the first time building this host.
  ...arguments          # The arguments to pass to `nh {os,darwin} switch` and `nix` (separated by --).
]: nothing -> nothing {
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
  let remote_ip = if ($ip | is-empty) { $"root@($host)" } else { $"root@($ip)" }
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
    ^sudo agenix -r -i /etc/ssh/ssh_host_ed25519_key
  }

  if $remote {
    git ls-files
    | sync --files-from - ./ $"($remote_ip):nix"

    sudo ssh -tt $remote_ip -i /etc/ssh/ssh_host_ed25519_key $"
      cd nix
      ./rebuild.nu ($host) (if $first { "--first" } else { "" }) ($arguments | str join ' ')
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
    NH_BYPASS_ROOT_CHECK=true NH_NO_CHECKS=true nh darwin switch . ...$nh_flags -- ...$nix_flags

    # if not (xcode-select --install e>| str contains "Command line tools are already installed") {
    #   darwin-shadow-xcode-popup
    # }

    # darwin-set-zshrc
  } else {
    NH_BYPASS_ROOT_CHECK=true NH_NO_CHECKS=true nh os switch . ...$nh_flags -- ...$nix_flags
  }
}
