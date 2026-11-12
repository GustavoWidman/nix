#!/usr/bin/env nu

const LOG_COLORS = {
    info: "blue"
    success: "green"
    warn: "yellow"
    error: "red"
    debug: "dark_gray"
    host: "magenta_bold"
    path: "cyan"
    cmd: "white_dimmed"
}

# Override stale cache settings left by an older system generation.
const CLEAN_SUBSTITUTERS = "https://cache.nixos.org https://nix-community.cachix.org https://r3dlust.cachix.org https://install.determinate.systems"
const CLEAN_TRUSTED_PUBLIC_KEYS = "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= r3dlust.cachix.org-1:/R3S8pW/nr7kOBJKcGPsZ0zCepvldTUEgbrqa4O3cW0="

def log [
    level: string
    message: string
    --exit (-e)
    --no-newline (-n)
    --return-instead
] {
    let color = ($LOG_COLORS | get $level)
    let prefix = match $level {
        "info" => "›"
        "success" => "✓"
        "warn" => "⚠"
        "error" => "✗"
        "debug" => "•"
        _ => "›"
    }

    let msg = $"[(ansi $color)($prefix)(ansi reset)] ($message)"

    if $return_instead {
        return $msg
    }

    if $exit {
        error make -u {
            msg: $msg
        }
    }

    if $no_newline {
        print -n $msg
    } else {
        print $msg
    }
}

def ssh-exec [
    host: string
    command: string
    --key: path             # SSH identity file path
    --return-output (-r)    # Return command output instead of streaming
] {
    mut ssh_opts = [
        "-tt"
        "-o" "StrictHostKeyChecking=no"
        "-o" "ConnectTimeout=10"
    ]

    let ssh_cmd = if ($key | is-not-empty) {
        let expanded_key = ($key | path expand)
        if not ($expanded_key | path exists) {
            log error $"ssh key not found: (ansi $LOG_COLORS.path)($expanded_key)(ansi reset)"
            exit 1
        }
        $ssh_opts = $ssh_opts | append [
            "-i" $expanded_key
        ]
    }

    if $return_output {
        return (ssh ...$ssh_opts $host $command)
    } else {
        ssh ...$ssh_opts $host $command
    }
}

def rsync-files [
    source: path
    destination: string
    --key (-k): path            # SSH identity file path
] {
    let rsync_opts = [
        "--archive"
        "--compress"
        "--delete"
        "--recursive"
        "--force"
        "--delete-excluded"
        "--delete-missing-args"
        "--human-readable"
        "--delay-updates"
        "--no-owner"
        "--no-group"
        "--info=progress2"
    ]

    let ssh_cmd = $"ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10(
        if ($key | is-not-empty) {
            $' -i ($key | path expand)'
        } else {
            ''
    })"

    # macOS ships openrsync, which lacks options above; use GNU rsync from nixpkgs there.
    let rsync_path = "sh -c 'if rsync --version 2>/dev/null | grep -q openrsync; then exec nix --extra-experimental-features \"nix-command flakes\" shell nixpkgs#rsync -c rsync \"$@\"; fi; exec rsync \"$@\"' rsync"

    $in | rsync ...$rsync_opts --rsh $ssh_cmd --rsync-path $rsync_path --files-from - $source $destination
}

def sync-nix-config [
    host: string
    --key (-k): path
] {
    log info $"syncing Nix configuration to (ansi $LOG_COLORS.host)($host)(ansi reset)"

    try {
        git ls-files
        | xargs dirname
        | ^sort -u
        | rsync-files "./" $"($host):.nix" -k $key
    } catch {
        log error -e $"failed to sync configuration: ($in.rendered)"
    }
}

def notify [
    hostname: string
    action: string
] {
    let system = (uname | get kernel-name)
    if $system == "Darwin" {
        try {
            terminal-notifier -title "nix" -message $"build complete for ($hostname), applying ($action)..." -sound default
        } catch {
            log debug "terminal-notifier not available, skipping notification"
        }
    }
}

def rebuild-remote [
    hostname: string
    remote: string

    --key (-k): path
    --boot (-b)                  # Use boot instead of switch
    --dry-run (-d)               # Perform dry run
    --clean-substituters         # Ignore stale substituters from the current system
] {
    sync-nix-config $remote --key $key

    let action = if $boot { "boot" } else { "switch" }

    let rebuild_args = [
        $hostname
        (if $boot { "--boot" } else { "" })
        (if $dry_run { "--dry-run" } else { "" })
        (if $clean_substituters { "--clean-substituters" } else { "" })
    ] | where {|x| $x != ""} | str join " "

    # build
    let build_remote_cmd = [
        "cd .nix"
        $"IN_REMOTE=true ./deploy.nu ($rebuild_args) --build-only"
    ] | str join " \n "

    log info "executing build on remote host"
    ssh-exec $remote $build_remote_cmd --key $key

    # notify locally
    notify $hostname $action

    # apply
    let apply_remote_cmd = [
        "cd .nix"
        $"IN_REMOTE=true ./deploy.nu ($rebuild_args) --apply-only"
    ] | str join " \n "

    log info "applying configuration on remote host"
    ssh-exec $remote $apply_remote_cmd --key $key
}

def rebuild-local [
    hostname: string
    --boot (-b)                 # Use boot instead of switch
    --dry-run (-d)              # Perform dry run
    --clean-substituters        # Ignore stale substituters from the current system
    --build-only                # Only build, don't apply
    --apply-only                # Only apply, don't build
] {
    let system = (uname | get kernel-name)
    let action = if $boot { "boot" } else { "switch" }

    let nh_flags = [
        "--quiet"
        "--hostname" $hostname
    ]

    mut nix_flags = [
        "--extra-experimental-features" "pipe-operators"
        "--option" "accept-flake-config" "true"
    ]

    if $clean_substituters {
        $nix_flags = ($nix_flags | append [
            "--option" "substituters" $CLEAN_SUBSTITUTERS
            "--option" "extra-substituters" ""
            "--option" "trusted-public-keys" $CLEAN_TRUSTED_PUBLIC_KEYS
            "--option" "extra-trusted-public-keys" ""
        ])
    }

    if $dry_run {
        $nix_flags = ($nix_flags | append ["--option" "eval-cache" "false"])
        log warn "running in dry-run mode, ignoring nix eval-cache"
    }

    try {
        if not $apply_only {
            log info "building configuration"
            if $system == "Darwin" {
                nh darwin build . ...$nh_flags -- ...$nix_flags
            } else {
                nh os build . ...$nh_flags -- ...$nix_flags
            }
            log success "build completed"
        }

        if not $build_only and not $apply_only {
            notify $hostname $action
        }

        if not $build_only {
            log info $"applying configuration \(($action)\)"
            if $system == "Darwin" {
                nh darwin switch . ...$nh_flags -- ...$nix_flags
            } else {
                nh os $action . ...$nh_flags -- ...$nix_flags
            }
            log success "rebuild completed successfully"
        }
    } catch {
        log error -e $"rebuild failed, please check logs."
    }
}

def validate-hostname [
    hostname: string
    --remote (-r)
] {
    if not $remote and $hostname != (hostname) {
        log warn $"building for hostname '(ansi $LOG_COLORS.host)($hostname)(ansi reset)' on system '(ansi $LOG_COLORS.host)(hostname)(ansi reset)'"

        let response = (input -n 1 $"continue? [(ansi green)y(ansi reset)/(ansi red)N(ansi reset)]: ")
        print ""

        if ($response | str lowercase) != "y" {
            log info -e "operation cancelled"
        }
    }
}

def hostnames [] {
    ls ./hosts
    | where type == dir
    | get name
    | path basename
}

# Rebuild a NixOS / Darwin config.
export def main --env [
    hostname?: string@hostnames # Target hostname (defaults to current)

    --boot (-b)                     # Boot instead of switch (NixOS only)
    --dry-run (-d)                  # Sets "eval-cache" to false in nix options
    --update (-u)                   # Update flake inputs before rebuild
    --clean-substituters             # Ignore stale substituters from the current system

    # Remote options
    --remote (-r): string@hostnames # Remote host address or hostname
    --key (-k): path                # SSH identity file for remote access

    # Advanced options
    --no-git                        # Skip git operations
    --build-only                    # Only build, don't apply
    --apply-only                    # Only apply, don't build
]: nothing -> nothing {
    let in_remote = ("IN_REMOTE" in $env)

    if not $in_remote and not $no_git {
        log debug "staging git changes"
        git add -A
    }

    if $update {
        log info "updating flake inputs"
        nix flake update
    }

    let target = if ($hostname | is-empty) {
        if ($remote | is-not-empty) {
            $remote
        } else {
            hostname
        }
    } else {
        $hostname
    }

    if ($remote | is-empty) {
        validate-hostname $target --remote=($remote | is-not-empty)
    }

    if ($remote | is-not-empty) {
        log info $"starting remote rebuild for (ansi $LOG_COLORS.host)($target)(ansi reset)(if ($target != $remote) { $' at (ansi $LOG_COLORS.host)($remote)(ansi reset)' } else { '' })"

        rebuild-remote $target $remote --key $key --boot=$boot --dry-run=$dry_run --clean-substituters=$clean_substituters
    } else {
        if not $in_remote {
            log info $"starting local rebuild for (ansi $LOG_COLORS.host)($target)(ansi reset)"
        }

        rebuild-local $target --boot=$boot --dry-run=$dry_run --clean-substituters=$clean_substituters --build-only=$build_only --apply-only=$apply_only
    }
}

def host-status [
    hostname: string
] {
    (ping -c 1 -t 1 $hostname | complete | get exit_code) == 0
}

def discover-hosts [] {
    if not ("./hosts" | path exists) {
        log error -e "hosts directory './hosts' not found"
    }

    let hosts = ls ./hosts
    | where type == dir
    | get name
    | path basename

    let hostname = hostname

    log info "found the following remotes:"

    $hosts
    | each {|host|
        {
            name: $host
            remote: ($host != $hostname)
            alive: (($host == $hostname) or (host-status $host))
        }
    }
    | sort-by name
    | sort-by remote
}

export def all --env [
    --boot (-b)                 # Boot instead of switch (for NixOS rebuilds only)
    --dry-run (-d)              # Sets "eval-cache" to false, skipping nix's eval cache and running "dry"
    --update (-u)               # Update flake inputs before any rebuilds
    --clean-substituters        # Ignore stale substituters from the current system

    # Advanced options
    --continue-on-error         # Continue with other hosts if one fails
    --no-git                    # Skip git operations
]: nothing -> nothing {
    if not $no_git {
        log debug "staging git changes"
        git add -A
    }

    if $update {
        log info "updating flake inputs"
        nix flake update
    }

    let hosts = discover-hosts
    | each {|host|
        let host_color = if $host.remote { "blue_bold" } else { "magenta_bold" }

        if $host.alive {
            log success $"  | (ansi $host_color)($host.name)(ansi reset)"
        } else {
            log error $"  | (ansi $host_color)($host.name)(ansi reset)"
        }

        $host
    }
    | where alive == true



    for host in $hosts {
        if $host.remote {
            log info $"starting remote rebuild for (ansi $LOG_COLORS.host)($host.name)(ansi reset)"

            rebuild-remote $host.name $host.name --boot=$boot --dry-run=$dry_run --clean-substituters=$clean_substituters
        } else {
            log info $"starting local rebuild for (ansi $LOG_COLORS.host)($host.name)(ansi reset)"

            rebuild-local $host.name --boot=$boot --dry-run=$dry_run --clean-substituters=$clean_substituters
        }
    }
}
