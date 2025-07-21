use ($nu.default-config-dir | path join config/main/absolute.nu)

alias grun = go run

alias cat = bat --plain --paging=never
alias cp = cp --recursive --verbose --progress
alias mv = mv --verbose --progress
alias less = bat --plain

alias rsactftool = docker run -it --rm -v $"($env.PWD):/data" rsactftool/rsactftool
alias jwt-tool = docker run -it --network "host" --rm -v $"($env.PWD):/tmp" -v $"($env.TRUE_HOME)/.jwt_tool:/root/.jwt_tool" ticarpi/jwt_tool
alias ubuntinho = docker run --rm -it -v $"($env.PWD):/home/shared" amd64/ubuntu:18.04 /bin/bash -c "cd /home/shared && HOME=/home/shared /bin/bash"

alias python3 = uv run python3
alias python = uv run python

alias revshell = uv run penelope
alias fg = job unfreeze

alias multiplex = zellij options --default-shell nu

alias "sudo su" = sudo (absolute nu)

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
