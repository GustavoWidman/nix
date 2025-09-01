def get-cwd [] {
    $" in (ansi blue)((do { pwd }) | str replace $env.HOME '~')(ansi reset)"
}

def find-jj-dir [pwd?: string] {
    mut current_dir = if ($pwd | is-empty) {
        pwd
    } else {
        $pwd
    }

    loop {
        let jj_path = ($current_dir | path join ".jj")

        if ($jj_path | path exists) {
            return ($jj_path | path dirname)
        }

        let parent = ($current_dir | path dirname)
        if $parent == $current_dir {
            return ""
        }
        $current_dir = $parent
    }
}

def get_branch [jj_out: list<string>] {
    let current_branch = $jj_out | get 3 | from json

    if ($current_branch | is-empty) {
        let fallback_branch = $jj_out | get 7 | from json
        if ($fallback_branch | is-empty) {
            $jj_out | get 2 # commit ID
        } else {
            $fallback_branch | first | get name
        }
    } else {
        $current_branch | first | get name
    }
}

def get_status [jj_out: list<string>] {
    let is_empty = $jj_out | get 0 | into bool

    if $is_empty {
        return "green" # clean
    }

    let has_commit_msg = $jj_out | get 1 | is-not-empty

    if $has_commit_msg {
        return "yellow" # staged
    }

    return "red" # dirty
}

def jj_stats [] {
    let jjdir = find-jj-dir | str trim
    if $jjdir == "" {
        return ""
    }

    let jj_out = try {
        jj --quiet -R $jjdir --color never --ignore-working-copy log --no-graph -r @ -r 'heads(::@- & bookmarks())' -T 'empty ++ "\n" ++ description.first_line() ++ "\n" ++ commit_id.short(8) ++ "\n" ++ json(bookmarks) ++ "\n"' err> /dev/null | lines
    }

    let branch = get_branch $jj_out
    let status = get_status $jj_out

	return $" in (ansi red)($branch)(ansi reset) (ansi $status)(ansi reset)"
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
    $env.PROMPT_COMMAND = {|| $"(ansi reset)╭─ ($user_host)(get-cwd)(jj_stats)(venv_prompt)(nix_shell_prompt)
╰─"}
    $env.PROMPT_INDICATOR = $"(ansi reset)(ansi white_bold)(if (is-admin) { "#" } else { "$" })(ansi reset) "
}
