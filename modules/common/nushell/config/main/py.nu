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

	if "VIRTUAL_ENV" in $env {
		error make -u {
			msg: $"(ansi red)activate::already_activated(ansi reset)\nalready inside a virtual environment\ndeactivate the current virtual environment first, then try again"
		}
	}

    let venvs = ls -a err> /dev/null
		| where type == dir and name =~ "(?i)env"
		| get name
		| where (
			$env.pwd
				| path join $it bin activate.nu
				| path exists
		)

    if ( $venvs | is-empty ) {
		error make -u {
			msg: $"(ansi red)activate::no_virtual_envs(ansi reset)\ncould not find any virtual environments in the current directory\ncreate a virtual environment first, then try again"
		}
    }

	if ( ($venvs | length) == 1 ) {
		let venv_name = ($venvs | first)
		let venv_activation_file = ($env.pwd | path join $venv_name bin activate.nu)

		hooks run-hooked $"overlay use ($venv_activation_file); hide deactivate; alias 'py deactivate' = overlay hide --keep-env [ PWD ] activate"

		log success $"acivated python environment succesfully"
		log info $"to deactivate, please use (ansi green)py deactivate(ansi reset)"
	} else {
		log warn "the following venvs are available, please choose one to activate:"

		let choice = $venvs | input list
		let venv_activation_file = ($env.pwd | path join $choice bin activate.nu)

		hooks run-hooked $"overlay use ($venv_activation_file); hide deactivate; alias 'py deactivate' = overlay hide --keep-env [ PWD ] activate"

		log success $"acivated python environment succesfully"
		log info $"to deactivate, please use (ansi green)py deactivate(ansi reset)"
	}
}
