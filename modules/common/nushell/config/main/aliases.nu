use ($nu.default-config-dir | path join config/main/absolute.nu)

alias grun = go run

alias cat = bat --plain --paging=never
alias cp = cp --recursive --verbose --progress
alias mv = mv --verbose --progress
alias less = bat --plain
alias grep = rg

alias rsactftool = docker run -it --rm -v $"($env.PWD):/data" rsactftool/rsactftool
alias jwt-tool = docker run -it --network "host" --rm -v $"($env.PWD):/tmp" -v $"($env.TRUE_HOME)/.jwt_tool:/root/.jwt_tool" ticarpi/jwt_tool
alias ubuntinho = docker run --rm -it -v $"($env.PWD):/home/shared" amd64/ubuntu:18.04 /bin/bash -c "cd /home/shared && HOME=/home/shared /bin/bash"

alias python3 = uv run python3
alias python = uv run python

alias revshell = uv run penelope
alias fg = job unfreeze

alias multiplex = zellij options --default-shell nu

alias "submodule pull" = git submodule update --recursive --remote
def --env devshell [] {
    if ("NIX_BUILD_TOP" in $env) or ("IN_NIX_SHELL" in $env) {
        error make -u {
			msg: $"(ansi red)nix_shell::already_activated(ansi reset)\nAlready inside a nix shell\nExit the current nix shell first \(using \"bye\", \"quit\" or \"q\"\), then try again"
		}
    } else {
        nom develop -c (absolute nu)
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
alias code = zeditor

alias "sudo su" = sudo (absolute nu)

alias secrekey = sudo agenix -r -i /etc/ssh/ssh_host_ed25519_key
def secredit [path] {
	sudo agenix -i /etc/ssh/ssh_host_ed25519_key -e $path
}

def --env get-env [name] { $env | get $name }
def --env set-env [name, value] { load-env { $name: $value } }
def --env unset-env [name] { hide-env $name }

def pubkey [path] {
	ssh-keygen -f $path -y
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
    | get column1
    | where {($in | str length) > 0}
    | parse "{key}={value}"
    | update value {str trim -c '"'}
    | transpose -r -d
}
