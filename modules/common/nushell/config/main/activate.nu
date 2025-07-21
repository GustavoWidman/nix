export def --env main [] {
	use ($nu.default-config-dir | path join config/utils/hooks.nu)

	if "VIRTUAL_ENV" in $env {
		error make -u {
			msg: $"(ansi red)activate::already_activated(ansi reset)\nAlready inside a virtual environment\nDeactivate the current virtual environment first, then try again"
		}
	}

    let venvs = ls -a
		| where type == dir and name =~ "(?i)env"
		| get name
		| where (
			$env.pwd
				| path join $it bin activate.nu
				| path exists
		)

    if ( $venvs | is-empty ) {
		error make -u {
			msg: $"(ansi red)activate::no_virtual_envs(ansi reset)\nCould not find any virtual environments in the current directory\nCreate a virtual environment first, then try again"
		}
    }

	if ( ($venvs | length) == 1 ) {
		let venv_name = ($venvs | first)
		let venv_activation_file = ($env.pwd | path join $venv_name bin activate.nu)

		hooks run-hooked $"overlay use ($venv_activation_file)"
	} else {
		print "The following venvs are available, please choose one to activate:"

		let choice = $venvs | input list
		let venv_activation_file = ($env.pwd | path join $choice bin activate.nu)

		hooks run-hooked $"overlay use ($venv_activation_file)"
	}
}