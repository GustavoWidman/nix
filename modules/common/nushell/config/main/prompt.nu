def get-cwd [] {
    $" in (ansi blue)((do { pwd }) | str replace $env.HOME '~')(ansi reset)"
}

def git_status_color [gstat_output: list<any>] {
	if ($gstat_output | where key starts-with idx | get value | math sum) > 0 {
		# any staged changes
		"yellow"
	} else if ($gstat_output | where key starts-with wt | get value | math sum) > 0 {
		# fully dirty
		"red"
	} else {
		# no staged and no dirty (fully clean)
		"green"
	}
}

def git_branch [] {
	let gstat_output = do { gstat | transpose key value }

	let repository = ($gstat_output | where key == repo_name | get value | first)
	if $repository == "no_repository" {
		return ""
	}

	let branch = ($gstat_output | where key == branch | get value | first)
	if $branch == "no_branch" or $branch == "" {
		return ""
	}

	let status_color = git_status_color $gstat_output

	return $" on (ansi red)($branch) (ansi $status_color)(ansi reset)"
}

def venv_prompt [] {
    if "VIRTUAL_ENV_PROMPT" in $env {
        $" using (ansi green)(($env.VIRTUAL_ENV_PROMPT))(ansi reset)"
    } else {
        ""
    }
}

export-env {
	let USER_COLOR = if (is-admin) { $'(ansi red)' } else { $'(ansi $env.USER_COLOR)' }
	let user_host = $"($USER_COLOR)(whoami)(ansi reset)@($USER_COLOR)($env.HOSTNAME)(ansi reset)"

	$env.PROMPT_COMMAND_RIGHT = ""
	$env.PROMPT_COMMAND = {|| $"(ansi reset)╭─ ($user_host)(get-cwd)(git_branch)(venv_prompt)
╰─"}
	$env.PROMPT_INDICATOR = $"(ansi reset)(ansi white_bold)(if (is-admin) { "#" } else { "$" })(ansi reset) "
}

