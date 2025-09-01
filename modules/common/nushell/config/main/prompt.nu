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

def get_branch [commit_list: list<list<string>>] {
    let branches = $commit_list | last | get 3 | from json
    let current_branch = $branches | where remote == "origin"

    if ($current_branch | is-empty) {
        # try to get any remote (not just origin)
        if ($branches | is-not-empty) {
            return ($branches | first | get name)
        }

        # if all else fails, fallback to current commit ID instead
        return ($commit_list | first | get 2)
    } else {
        return ($current_branch | first | get name)
    }
}

def get_status [commit_list: list<list<string>>] {
    let is_empty = $commit_list | first | get 0 | into bool

    if $is_empty {
        return "green" # clean
    }

    let has_commit_msg = $commit_list | first | get 1 | is-not-empty

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

    let commit_list: list<list<string>> = try {
        jj --quiet -R $jjdir --color never --ignore-working-copy log --no-graph -r 'heads(::@- & remote_bookmarks()-+)::@' -r 'children(heads(::@- & remote_bookmarks()-)) & remote_bookmarks()' -T 'empty ++ "\n" ++ description.first_line() ++ "\n" ++ commit_id.short(8) ++ "\n" ++ json(remote_bookmarks) ++ "\n"' err> /dev/null
            | lines
            | chunks 4
            | where {|e| $e.2 != "00000000"} # ignore root commit/empty commits
    }

    if ($commit_list | is-empty) {
        return $" in (ansi red)???(ansi reset) (ansi green)(ansi reset)"
    }

    let branch = get_branch $commit_list
    let status = get_status $commit_list
    let unpushed_commits = $commit_list
        | where {|e| $e.1 | is-not-empty}
        | each {|e| $e.3 | from json | any {|e| $e.remote == "origin"}}
        | where $it == false
        | length
    let unpushed_commits_str = if ($unpushed_commits > 0) {
        let superscript = $unpushed_commits
            | into string
            | str replace "0" "⁰"
            | str replace "1" "¹"
            | str replace "2" "²"
            | str replace "3" "³"
            | str replace "4" "⁴"
            | str replace "5" "⁵"
            | str replace "6" "⁶"
            | str replace "7" "⁷"
            | str replace "8" "⁸"
            | str replace "9" "⁹"
        let tugged = $commit_list
            | each {|e| $e.3 | from json}
            | reverse
            | skip 2
            | each {|e| $e | where remote == "git"}
            | each {|e| $e | is-empty}
            | any {|e| $e == false}

        let unpushed_color = if ($tugged) {"blue"} else {"yellow"}

        $"(ansi $unpushed_color)($superscript)(ansi reset)"
    } else { "" }

	return $" in (ansi red)($branch)(ansi reset)($unpushed_commits_str) (ansi $status)(ansi reset)"
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
