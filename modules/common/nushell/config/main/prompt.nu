def get-cwd [] {
    $" in (ansi blue)((do { pwd }) | str replace $env.HOME '~')(ansi reset)"
}

def find-git-dir [pwd?: string] {
    mut current_dir = if ($pwd | is-empty) {
        pwd
    } else {
        $pwd
    }

    loop {
        let git_path = ($current_dir | path join ".git")

        if ($git_path | path exists) {
            return ($git_path | path dirname)
        }

        let parent = ($current_dir | path dirname)
        if $parent == $current_dir {
            return ""
        }
        $current_dir = $parent
    }
}

def git_branch [] {
    let gitdir = find-git-dir | str trim
    if $gitdir == "" {
        return ""
    }

	return $" in (ansi red)repo(ansi reset)"
}

def venv_prompt [] {
    if "VIRTUAL_ENV_PROMPT" in $env {
        $" using (ansi green)(($env.VIRTUAL_ENV_PROMPT))(ansi reset)"
    } else {
        ""
    }
}

def nix_shell_prompt [] {
    if ("NIX_BUILD_TOP" in $env) or ("IN_NIX_SHELL" in $env) {
        $" in (ansi cyan)nix-shell(ansi reset)"
    } else {
        ""
    }
}

export-env {
    let USER_COLOR = if (is-admin) { $'(ansi red)' } else { $'(ansi $env.USER_COLOR)' }
    let user_host = $"($USER_COLOR)(whoami)(ansi reset)@($USER_COLOR)($env.HOSTNAME)(ansi reset)"

    $env.PROMPT_COMMAND_RIGHT = ""
    $env.PROMPT_COMMAND = {|| $"(ansi reset)╭─ ($user_host)(get-cwd)(git_branch)(venv_prompt)(nix_shell_prompt)
╰─"}
    $env.PROMPT_INDICATOR = $"(ansi reset)(ansi white_bold)(if (is-admin) { "#" } else { "$" })(ansi reset) "
}
