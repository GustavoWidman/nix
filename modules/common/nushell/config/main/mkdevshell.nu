const patches = [
    "rust"
]

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

    let msg = $'[(ansi $color)($prefix)(ansi reset)] ($message
        | str trim -l
        | lines
        | each { str trim -l }
        | str join $"\n (ansi white)|(ansi reset)  ")'

    if $return_instead {
        return $msg
    }

    if $exit {
        error make -u {
            msg: $msg
        }
    }

    match $no_newline {
        true => (print -n $msg)
        false => (print $msg)
    }
}

def check-replace [] {
    return (match (ls | where name == flake.nix | is-not-empty) {
        true => {
            let choice = input -n 1 -s (log warn --return-instead $"
            there already seems to be a `(ansi cyan)flake.nix(ansi reset)` file in the current directory.
            are you sure you want to continue and replace it? \((ansi green)y(ansi reset)/(ansi red)n(ansi reset)\): ")
            print "" # newline

            match (($choice | str downcase) != "y") {
                true => {
                    match (($choice | str downcase) != "n") {
                        true => {log warn "invalid choice, exiting..."}
                        false => {log info "exiting without making any changes..."}
                    }
                    return false
                }
                false => true # continue
            };
        },
        false => true # return ok
	})
}

# Prompts if a .envrc file should be created as well
def envrc [] {
    let choice = input -n 1 -s (log info --return-instead $"would you like to create a `(ansi cyan).envrc(ansi reset)` file as well? \((ansi green)y(ansi reset)/(ansi red)n(ansi reset)\): ")
    print "" # newline
    if ($choice | str downcase) != "y" {
        match (($choice | str downcase) != "n") {
            true => (log warn $"invalid choice, skipping `(ansi cyan).envrc(ansi reset)` creation...")
            false => (log info $"skipping `(ansi cyan).envrc(ansi reset)` creation...")
        }
        return
    };

    "use flake >/dev/null 2>&1" | save -f .envrc

    git add -A err> /dev/null
    nix flake update
}

def patch [type] {
    let choice = input -n 1 -s (log info --return-instead $"would you like to apply any patches for `(ansi cyan)($type)(ansi reset)`? \((ansi green)y(ansi reset)/(ansi red)n(ansi reset)\): ")
    print "" # newline
    if ($choice | str downcase) != "y" {
        match (($choice | str downcase) != "n") {
            true => (log warn $"invalid choice, skipping patches for `(ansi cyan)($type)(ansi reset)` flake...")
            false => (log info $"skipping patches for `(ansi cyan)($type)(ansi reset)` flake...")
        }
        return
    };

    let choice = $patches
        | input list -f (log info --return-instead $"
            Pick patches to apply to the `(ansi cyan)($type)(ansi reset)` flake: ")

    let patches = open ($nu.default-config-dir
        | path join $"config/main/templates/($type)-($choice).diff")

    $patches | ^patch --fuzz 2 flake.nix
}

# Makes a example flake.nix file in the current directory using flake-utils
export def --env utils [] {
	if not (check-replace) {
        return
	}

    cp ($nu.default-config-dir | path join config/main/templates/flake-utils.template) flake.nix

    log success $"successfully created (ansi cyan)flake.nix(ansi reset) file in the current directory.
    you can now run `(ansi cyan)dev(ansi reset)` or `(ansi cyan)devshell(ansi reset)` to enter the development shell"

    patch "flake-parts"

    envrc
}

# Makes a example flake.nix file in the current directory using flake-parts
export def --env parts [] {
    if not (check-replace) {
           return
	}

    cp -f ($nu.default-config-dir | path join config/main/templates/flake-parts.template) flake.nix

    log success $"successfully created (ansi cyan)flake.nix(ansi reset) file in the current directory.
    you can now run `(ansi cyan)dev(ansi reset)` or `(ansi cyan)devshell(ansi reset)` to enter the development shell"

    patch "flake-parts"

    envrc
}
