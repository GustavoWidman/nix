use "../main/absolute.nu"
use "../utils/log.nu"

alias grun = go run

alias cat = bat --plain --paging=never
alias cp = cp --recursive --verbose --progress
alias mv = mv --verbose --progress
alias less = bat --plain
alias grep = rg
alias todo = rg "todo|fixme" --colors match:fg:yellow --colors match:style:bold -i
alias tree = eza -T --group-directories-first --git-ignore
alias tree! = eza -T --group-directories-first

alias rsactftool = docker run -it --rm -v $"($env.PWD):/data" rsactftool/rsactftool
alias jwt-tool = docker run -it --network "host" --rm -v $"($env.PWD):/tmp" -v $"($env.TRUE_HOME)/.jwt_tool:/root/.jwt_tool" ticarpi/jwt_tool
alias ubuntinho = docker run --rm -it -v $"($env.PWD):/home/shared" amd64/ubuntu:18.04 /bin/bash -c "cd /home/shared && HOME=/home/shared /bin/bash"

alias python3 = uv run python3
alias python = uv run python

alias penelope = penelope.py
alias fg = job unfreeze

alias multiplex = zellij options --default-shell nu

alias "docker ps" = docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{ if gt (len .Ports) 33 }}{{printf \"%.30s...\" .Ports}}{{ else }}{{ .Ports }}{{ end }}\t{{.Status}}"

alias "submodule pull" = git submodule update --recursive --remote
def --env devshell [] {
    if ("NIX_BUILD_TOP" in $env) or ("IN_NIX_SHELL" in $env) {
        error make -u {
			msg: $"(ansi red)nix_shell::already_activated(ansi reset)\nAlready inside a nix shell\nExit the current nix shell first \(using \"bye\", \"quit\" or \"q\"\), then try again"
		}
    } else {
        let nupath = absolute nu
        nom develop -c env $'SHELL=($nupath)' $nupath
    }
}
alias dev = devshell
alias quit = exit
alias bye = exit
alias ":q" = exit # le vim enjoyer
alias q = exit
alias dns = /usr/bin/env q # re-alias "q" (the DNS query tool) to something else

alias c = clear
alias ":c" = clear # le vim enjoyer part 2

# let's give this a try, shall we?
alias nano = hx
alias nano! = ^nano
alias code = zed
alias code! = ^code

alias "cargo hot" = watchexec -e rs -w src -w Cargo.toml -w Cargo.lock -r cargo run

alias "sudo su" = sudo (absolute nu)

def --env get-env [name] { $env | get $name }
def --env set-env [name, value] { load-env { $name: $value } }
def --env unset-env [name] { hide-env $name }

def pubkey [path] {
	ssh-keygen -f $path -y
}

# Moves a revision to after the target and rebases
def "jj move" [
    --from (-f): string
    --to (-t): string
] {
    jj new $to
    jj squash -f $from -t @
    jj rebase -s $"roots\(@-.. & ~@\)" -d @
}

def --env gitzip [output?: string, --dir (-C): string] {
    if (($output | path type) != "dir") {
        print "gitzip only works with dirs"
        return 1
    }

    let target = (if ($dir == null) {
        $output
    } else {
        $dir
    })

    let name = ($output | default ($target | path basename))
    let zipname = if ($name | str ends-with ".zip") { $name } else { $name + ".zip" }

    if ($zipname | path exists) {
        print $"delete ($zipname) first" # todo offer to delete with a y/N prompt
        return
    }

    git -C $target ls-files --cached --others --exclude-standard
        | lines
        | each {$"($target)/($in)"}
        | str join "\n"
        | ^zip $zipname -@
}

def psub [] {
  let tmp = (mktemp -t | str trim)

  $in | save --raw -f $tmp

  return $tmp
}

def --wrapped javar [...args] {
	if ($args | length) == 0 {
		print "Usage: javar <filename.java>"
        return 1
	}

	let filename = $args.0
	let base_name = ($filename | str replace ".java" "")

	if not ("./dist" | path exists) {
		mkdir "./dist"
	}

	javac -d ./dist -h ./dist -s ./dist $"($base_name).java"
	let other_args = $args | skip 1

	java -cp ./dist $"($base_name)" ...$other_args
}

def --wrapped crun [...args] {
	if ($args | length) == 0 {
		print "Usage: crun <filename.c>"
        return 1
	}

	let file = $args.0
	let base_name = ($file | str replace ".c" "")
	let other_args = $args | skip 1

	if not ("./dist" | path exists) {
		mkdir "./dist"
	}

	gcc -o ./dist/($base_name) $"($base_name).c" -lm
	# if exit code is not 0, then return
	if ($env.LAST_EXIT_CODE | default 0) != 0 {
		print "Compilation failed"
		return $env.LAST_EXIT_CODE
	}

	chmod +x ./dist/($base_name)

	./dist/($base_name) ...$other_args
}

def "from env" []: string -> record {
    lines
        | split column '#'
        | get column0
        | where {($in | str length) > 0}
        | parse "{key}={value}"
        | update value {str trim -c '"'}
        | transpose -r -d
}

# Retrieve the output of the last command.
def _ []: nothing -> any {
    $env.last?
}

# Create a directory and cd into it.
def --env mc [path: path]: nothing -> nothing {
    mkdir $path
    cd $path
}

# Create a directory, cd into it and initialize version control.
def --env mcg [path: path]: nothing -> nothing {
    mkdir $path
    cd $path
    jj git init --colocate
}

def --env source-bash [
    script_path: string  # Path to the bash script to source
] {
    let script_dir = ($script_path | path dirname)
    let script_name = ($script_path | path basename)

    let env_out = ^bash -c $"
        cd '($script_dir)'
        env
        echo '<ENV_CAPTURE_EVAL_FENCE>'
        source ./($script_name)
        echo '<ENV_CAPTURE_EVAL_FENCE>'
        env -0"
    | split row '<ENV_CAPTURE_EVAL_FENCE>'
    | {
        before: ($in | first | str trim | lines)
        after: ($in | last | str trim | split row (char --integer 0))
    }

    $env_out.after
    | where { |line| $line not-in $env_out.before }
    | parse "{key}={value}"
    | transpose --header-row --as-record
    | if $in == [] { {} } else { $in }
    | load-env
}

def net? [] {
    let result = ^ping -c 1 -t 1 1.1.1.1 | complete

    if $result.exit_code == 0 {
        let latency = $result.stdout
            | lines
            | get 1
            | split row "time="
            | get 1
            | split row " "
            | str join ""
            | into duration

        log info $"network is (ansi green)up(ansi reset). latency: (ansi purple)($latency)(ansi reset)"
    } else {
        log error $"network is (ansi red)down(ansi reset). ping failed with exit code (ansi purple)($result.exit_code)(ansi reset)"
    }
}

def dns? [] {
    let local = timeit --output {
        ^dig +short +time=1 +tries=1 google.com @127.0.0.1 | complete
    }

    if $local.output.exit_code == 0 {
        log info $"dns is (ansi green)fully up(ansi reset). local resolver responded in (ansi purple)($local.time)(ansi reset)"
        return
    }

    let cf = timeit --output {
        ^dig +short +time=1 +tries=1 google.com @1.1.1.1 | complete
    }

    if $cf.output.exit_code == 0 {
        log warn $"dns is (ansi yellow)partially up(ansi reset). local resolver failed, but cloudflare responded in (ansi purple)($cf.time)(ansi reset)"
        return
    }

    let dhcp_dns = do {
        let line = (
            ^ipconfig getpacket en0
            | lines
            | where { |l| $l | str contains "domain_name_server (ip_mult):" }
            | get -o 0
        )

        if ($line == null) {
            log error --exit $"could not find domain_name_server in DHCP packet for en0"
        }

        let servers = (
            $line
            | str replace --all --regex '[^0-9.]+' ' '
            | split row ' '
            | each { |s| $s | str trim }
            | where { |s| ($s | is-not-empty) and ($s =~ '^\d{1,3}(\.\d{1,3}){3}$') }
        )

        if ($servers | is-empty) {
            log warn $"domain_name_server was present for en0, but no IPv4 DNS servers parsed: ($line)"
        }

        $servers
    } | first

    let dhcp = timeit --output {
        ^dig +short +time=1 +tries=1 google.com @($dhcp_dns) | complete
    }

    if $dhcp.output.exit_code == 0 {
        log warn $"dns is (ansi yellow)partially up(ansi reset). local resolver AND cloudflare failed \(hinting at a captive network environment), but dhcp-provided server (ansi blue)($dhcp_dns) responded in (ansi purple)($dhcp.time)(ansi reset)"
        return
    } else {
        log error $"dns is (ansi red)fully down(ansi reset). local resolver, cloudflare, and dhcp-provided server (ansi blue)($dhcp_dns)(ansi reset) all failed"
        return
    }
}
