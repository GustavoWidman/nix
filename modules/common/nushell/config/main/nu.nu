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

export def --env "activate" [] {
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
            let choice = input -n 1 -s (log warn --return-instead $"you already have a nu environment activated, but this one is different. activate? [(ansi green)y(ansi reset)/(ansi red)N(ansi reset)]: ")
            print ""
            if ($choice | str downcase) == "y" {
                deactivate
            } else {
                log warn "exiting without doing anything..."
                exit 1
            }
        }
	}

	if ( ($nu_files | length) == 1 ) {
		let file = ($nu_files | first)

		hooks run-hooked $'overlay use ($file.path) as ($file.stem)'

		log success $"acivated nu environment succesfully"
		log info $"to deactivate, please use (ansi purple)nu deactivate(ansi reset)"

		$env.NU_ENV = {
		    hash: $env_hash
			name: $file.stem
			activated: [ $file.stem ]
		}
	} else {
		let name = input (log warn --return-instead "more than one nu file is available, please choose a name for this env: ")

		for $file in ($nu_files | get stem) {
		    hooks run-hooked $'overlay use ($file.path) as ($file.stem)'
		}

		log success $"acivated nu environment succesfully"
		log info $"to deactivate, please use (ansi purple)nu deactivate(ansi reset)"

		$env.NU_ENV = {
		    hash: $env_hash
			name: $name
			activated: ($nu_files | get stem)
		}
	}
}

export def --env "deactivate" [] {
    use ($nu.default-config-dir | path join config/utils/hooks.nu)
   	if ((not ("NU_ENV" in $env)) or $env.NU_ENV == null) {
  		error make -u {
     			msg: $"(ansi red)nu-deactivate::not_activated(ansi reset)\nNo nu files have been activated.\nActivate a nu environment first using (ansi purple)nu activate(ansi reset), then try again."
  		}
	}

	for $file in ($env.NU_ENV | get activated) {
		hooks run-hooked $'overlay hide --keep-env [ PWD NU_ENV ] ($file)'
	}

	$env.NU_ENV = null

	log success $"nu environment deactivated succesfully"
}
