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

export def --env "activate" [
    --quiet (-q)
] {
	use ($nu.default-config-dir | path join config/utils/hooks.nu)

    let nu_files = ls -a err> /dev/null
        | where {|el| ($el | get type) == "file" }
        | par-each { get name | path parse }
        | where {|el| ($el | get extension) == "nu" }
        | par-each {|el|
            let path = (pwd | path join $"($el.stem).($el.extension)")
            {
                stem: $el.stem
                hash: (open $path | hash sha256),
                path: $path
            }
        }

    if ( $nu_files | is-empty ) {
		error make -u {
			msg: $"(ansi red)nu-activate::no_nu_files(ansi reset)\nCould not find any (ansi purple).nu(ansi reset) files in the current directory\nCreate a (ansi purple).nu(ansi reset) file first, then try again"
		}
    }

    let env_hash = $nu_files
        | get hash
        | str join "\n"
        | hash sha256

	if (("NU_ENV" in $env) and $env.NU_ENV != null) {
    	if ($env_hash == ($env.NU_ENV | get hash)) {
    		error make -u {
    			msg: $"(ansi red)nu-activate::already_activated(ansi reset)\nthese nu files have already been activated.\ndeactivate the current nu environment first, then try again if you think this is an error."
    		}
    	} else {
            let choice = match $quiet {
                true => "y",
                false => (input -n 1 -s (log warn --return-instead $"you already have a nu environment activated, but this one is different. activate? [(ansi green)y(ansi reset)/(ansi red)N(ansi reset)]: "))
            }
            if not $quiet { print "" }
            if ($choice | str downcase) == "y" {
                deactivate --quiet=$quiet
            } else {
                log warn "exiting without doing anything..." --exit
            }
        }
	}

	if ( ($nu_files | length) == 1 ) {
		let file = ($nu_files | first)

		hooks run-hooked $'overlay use -p ($file.path) as ($file.stem); $env.NU_ENV = { hash: "($env_hash)" name: "($file.stem)" activated: [ "($file.stem)" ] }'

		if not $quiet {
    		log success $"acivated nu environment succesfully"
    		log info $"to deactivate, please use (ansi purple)nu deactivate(ansi reset)"
		}
	} else {
		let name = input (log warn --return-instead "more than one nu file is available, please choose a name for this env: ")

		for $file in ($nu_files | get stem) {
		    hooks run-hooked $'overlay use -p ($file.path) as ($file.stem); $env.NU_ENV = { hash: "($env_hash)" name: "($file.stem)" activated: [ "($file.stem)" ] }'
		}

		if not $quiet {
    		log success $"acivated nu environment succesfully"
    		log info $"to deactivate, please use (ansi purple)nu deactivate(ansi reset)"
		}
	}
}

export def --env "deactivate" [
    --quiet (-q)
] {
    use ($nu.default-config-dir | path join config/utils/hooks.nu)
   	if ((not ("NU_ENV" in $env)) or $env.NU_ENV == null) {
  		error make -u {
     			msg: $"(ansi red)nu-deactivate::not_activated(ansi reset)\nNo nu files have been activated.\nActivate a nu environment first using (ansi purple)nu activate(ansi reset), then try again."
  		}
	}

	for $file in ($env.NU_ENV | get activated) {
		hooks run-hooked $"overlay hide --keep-env \($env | transpose | get column0\) ($file); $env.NU_ENV = null"
	}

	if not $quiet { log success $"nu environment deactivated succesfully" }
}
