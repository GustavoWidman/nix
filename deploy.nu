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

def log [
    level: string
    message: string
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

    $in | rsync ...$rsync_opts --rsh $ssh_cmd --files-from - $source $destination
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
        log error $"failed to sync configuration: ($in)"
        exit 1
    }
}

def ensure-host-key [
    hostname: string
    remote: string
    --key (-k): path
] {
    let existing_key = (
        nix eval
            --extra-experimental-features nix-command
            --impure
            --expr
            $"\(import ./keys.nix\).($hostname) or null"
    )

    if $existing_key == "null" {
        let pubkey = if ($remote | is-not-empty) {
            ssh-exec $remote "cat /etc/ssh/ssh_host_ed25519_key.pub" --key $key --return-output
        } else {
            open -r /etc/ssh/ssh_host_ed25519_key.pub
        }

        log info $"adding host key: (ansi $LOG_COLORS.cmd)($pubkey | str substring 0..50)...(ansi reset)"

        mut keys_content = open ./keys.nix
        | lines
        | insert 2 $'    ($hostname) = "($pubkey)";'

        let os = (["linux" "darwin"] | input list (log info "choose machine os" --return-instead))
        let os_line = ($keys_content
            | enumerate
            | where item =~ $os
            | first
            | get index
        ) + 1
        $keys_content = $keys_content
        | insert $os_line $'    keys.($hostname)'

        let type = (["server" "desktop"] | input list (log info "choose machine type" --return-instead))
        let type_line = ($keys_content
            | enumerate
            | where item =~ $type
            | first
            | get index
        ) + 1
        $keys_content = $keys_content
        | insert $type_line $'    keys.($hostname)'

        let is_dev = (input -n 1 (log info $"is this machine a dev environment? [(ansi green)y(ansi reset)/(ansi red)N(ansi reset)]: " --return-instead))
        if ($is_dev | str downcase) == "y" {
            let dev_line = ($keys_content
                | enumerate
                | where item =~ dev
                | first
                | get index
            ) + 1
            $keys_content = $keys_content
            | insert $dev_line $'    keys.($hostname)'
        }

        let is_admin = (input -n 1 (log info $"is this machine an admin? [(ansi green)y(ansi reset)/(ansi red)N(ansi reset)]: " --return-instead))
        if ($is_admin | str downcase) == "y" {
            let admin_line = ($keys_content
                | enumerate
                | where item =~ admins
                | first
                | get index
            ) + 1
            $keys_content = $keys_content
            | insert $admin_line $'    keys.($hostname)'
        }

        $keys_content
        | str join "\n"
        | save -f ./keys.nix

        nixfmt ./keys.nix
        sudo agenix -r -i /etc/ssh/ssh_host_ed25519_key
        log warn "host key added. please configure secrets and rerun."
        exit 0
    }
}

def rebuild-remote [
    hostname: string
    remote: string

    --key (-k): path
    --boot (-b)                  # Use boot instead of switch
    --dry-run (-d)               # Perform dry run
    --initial (-i)               # Initial setup for new host
] {
    sync-nix-config $remote --key $key

    let rebuild_args = [
        $hostname
        (if $initial { "--initial" } else { "" })
        (if $boot { "--boot" } else { "" })
        (if $dry_run { "--dry-run" } else { "" })
    ] | where {|x| $x != ""} | str join " "

    let rebuild_cmd = $"IN_REMOTE=true ./deploy.nu ($rebuild_args)"

    let remote_cmd = if $initial {
        log info "initial setup on remote host needed, please be patient..."
        [
            "nix-channel --add https://nixos.org/channels/nixpkgs-unstable"
            "nix-channel --update"
            $'NIX_CONFIG="experimental-features = nix-command flakes" NH_BYPASS_ROOT_CHECK=true nix-shell -p nushell -p nh --run "cd .nix && ($rebuild_cmd)"'
            "rm -rf ~/.nix"
        ] | str join " && "
    } else {
        [
            "cd .nix"
            $rebuild_cmd
        ] | str join " \n "
    }

    log info "executing rebuild on remote host"
    ssh-exec $remote $remote_cmd --key $key

    return
}

def rebuild-local [
    hostname: string
    --boot (-b)                 # Use boot instead of switch
    --dry-run (-d)              # Perform dry run
    --initial (-i)              # Initial setup for new host
] {
    let system = (uname | get kernel-name)
    let action = if ($boot or $initial) { "boot" } else { "switch" }

    let nh_flags = [
        "--hostname" $hostname
    ]

    mut nix_flags = [
        "--option" "accept-flake-config" "true"
    ]

    if $initial {
        $nix_flags = ($nix_flags | append [
            "--extra-experimental-features" "flakes"
            "--extra-experimental-features" "pipe-operators"
            "--extra-experimental-features" "nix-command"
        ])
    }

    if $dry_run {
        $nix_flags = ($nix_flags | append ["--option" "eval-cache" "false"])
        log warn "running in dry-run mode, ignoring nix eval-cache"
    }

    try {
        if $system == "Darwin" {
            nh darwin switch . ...$nh_flags -- ...$nix_flags
        } else {
            nh os $action . ...$nh_flags -- ...$nix_flags
            if $initial {
                log warn "initial build complete. please reboot the system."
            }
        }
        log success "rebuild completed successfully"
    } catch {
        log error $"rebuild failed: ($in)"
        exit 1
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

        if ($response | str downcase) != "y" {
            log info "operation cancelled"
            exit 0
        }
    }
}

# Rebuild a NixOS / Darwin config.
def main --env [
    hostname?: string           # Target hostname (defaults to current)

    --boot (-b)                 # Boot instead of switch (NixOS only)
    --dry-run (-d)              # Sets "eval-cache" to false, skipping nix's eval cache and running "dry"
    --initial (-i)              # Initial setup for new host
    --update (-u)               # Update flake inputs before rebuild

    # Remote options
    --remote (-r): string       # Remote host address or hostname
    --key (-k): path            # SSH identity file for remote access

    # Advanced options
    --no-git                    # Skip git operations
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

        ensure-host-key $target $remote --key $key
        rebuild-remote $target $remote --key $key --boot=$boot --dry-run=$dry_run --initial=$initial
    } else {
        if not $in_remote {
            log info $"starting local rebuild for (ansi $LOG_COLORS.host)($target)(ansi reset)"
        }

        rebuild-local $target --boot=$boot --dry-run=$dry_run --initial=$initial
    }
}

def host-status [
    hostname: string
] {
    (ping -c 1 -t 1 $hostname | complete | get exit_code) == 0
}

def discover-hosts [] {
    if not ("./hosts" | path exists) {
        log error "hosts directory './hosts' not found"
        exit 1
    }

    let hosts = ls ./hosts
    | where type == dir
    | get name
    | path basename

    let hostname = hostname

    log info "found the following remotes:"

    $hosts
    | par-each {|host|
        {
            name: $host
            remote: ($host != $hostname)
            alive: (($host == $hostname) or (host-status $host))
        }
    }
    | sort-by name
    | sort-by remote
}

def "main all" --env [
    --boot (-b)                 # Boot instead of switch (for NixOS rebuilds only)
    --dry-run (-d)              # Sets "eval-cache" to false, skipping nix's eval cache and running "dry"
    --update (-u)               # Update flake inputs before any rebuilds

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

            rebuild-remote $host.name $host.name --boot=$boot --dry-run=$dry_run
        } else {
            log info $"starting local rebuild for (ansi $LOG_COLORS.host)($host.name)(ansi reset)"

            rebuild-local $host.name --boot=$boot --dry-run=$dry_run
        }
    }
}
