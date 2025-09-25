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

def get_branch [commit_list: list] {
    let branches = $commit_list
        | reverse
        | each { get 3 }
        | flatten
    let current_branch = $branches
        | where remote == "origin"

    if ($current_branch | is-empty) {
        # try to get any remote (not just origin)
        if ($branches | is-not-empty) {
            return ($branches
                | first
                | get name)
        }

        # if all else fails, fallback to current commit ID instead
        return ($commit_list
            | first
            | get 2)
    } else {
        return ($current_branch
            | first
            | get name)
    }
}

def get_status [commit_list: list] {
    let is_empty = $commit_list
        | first
        | get 0

    if $is_empty {
        return "green" # clean
    }

    let has_commit_msg = $commit_list
        | first
        | get 1
        | is-not-empty

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

    let commit_list: list = try {
        jj --quiet -R $jjdir --color never --ignore-working-copy log --no-graph -r 'heads(::@- & ancestors(coalesce(remote_bookmarks(), bookmarks())) & ::)::' -T 'empty ++ "\n" ++ description.first_line() ++ "\n" ++ commit_id.short(8) ++ "\n" ++ change_id ++ "\n" ++ json(remote_bookmarks) ++ "\n"' err> /dev/null
            | lines
            | chunks 5
            | where ($it.3 != "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz")
            | group-by { get 3 }
            | values
            | each {|group|
                let empty = ($group | each { get 0 | into bool } ) | all {}
                let merged_branches = ($group | each { get 4 | from json} | flatten)
                let description = ($group | where { get 1 | is-not-empty } | get -o 0 | get -o 1)
                let commit_id = if ($group | length) > 1 { "???" } else { $group | first | get 2 }

                [
                    $empty,
                    $description,
                    $commit_id,
                    $merged_branches
                ]
            }
    }

    if ($commit_list | is-empty) {
        return $" in (ansi red)???(ansi reset) (ansi green)(ansi reset)"
    }

    let branch = get_branch $commit_list
    let status = get_status $commit_list
    let unpushed_commits = $commit_list
        | where {|c|
            ($c
                | get 1
                | is-not-empty
            ) and not (
            $c
                | get 0
            ) and not (
            $c
                | get 3
                | any {|e| $e.remote == "origin" }
            ) and not (
            $c
                | get 3
                | any {|e| $e.name != $branch }
            )
        }
        | length
    let unpushed_commits_str = if ($unpushed_commits > 0) {
        let superscript = $unpushed_commits
            | into string
            | str replace -a "0" "⁰"
            | str replace -a "1" "¹"
            | str replace -a "2" "²"
            | str replace -a "3" "³"
            | str replace -a "4" "⁴"
            | str replace -a "5" "⁵"
            | str replace -a "6" "⁶"
            | str replace -a "7" "⁷"
            | str replace -a "8" "⁸"
            | str replace -a "9" "⁹"
        let tugged = $commit_list
            | where { get 1 | is-not-empty }
            | each { get 3 }
            | reverse
            | skip
            | each { where {|el| $el.remote == "git" and $el.name == $branch } }
            | each { is-not-empty }
            | any {}

        let unpushed_color = if ($tugged) { "blue" } else { "yellow" }

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

def nuenv_prompt [] {
    if (("NU_ENV" in $env) and ($env.NU_ENV != null)) {
        $" using (ansi purple)($env.NU_ENV.name)(ansi reset)"
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

def venv_activateable [ls_results] {
    let venvs = $ls_results
		| where type == dir and name =~ "(?i)env"
		| get name
		| where (
			$env.pwd
				| path join $it bin activate.nu
				| path exists
		)

	if (($venvs | is-not-empty) and not ("VIRTUAL_ENV_PROMPT" in $env)) {
	    return $"(ansi green_bold)⁺(ansi reset)"
	} else {
	    return ""
	}
}

def nuenv_activateable [ls_results] {
    let nu_files = $ls_results
        | where {|el| ($el | get type) == "file" }
        | par-each { get name | path parse }
        | where {|el| ($el | get extension) == "nu" }

    if (($nu_files | is-not-empty) and not (("NU_ENV" in $env) and ($env.NU_ENV != null))) {
        return $"(ansi purple_bold)⁺(ansi reset)"
    } else {
        return ""
    }
}

def nix_shell_activateable [ls_results] {
    let nix_flakes = $ls_results
        | where name == "flake.nix"

    if (($nix_flakes | is-not-empty) and (open ($nix_flakes | first | get name) | str contains "devShells") and (not (("NIX_BUILD_TOP" in $env) or ("IN_NIX_SHELL" in $env)))) {
        return $"(ansi cyan_bold)⁺(ansi reset)"
    } else {
        return ""
    }
}

def activateables [] {
    let ls_results = ls -a err> /dev/null
    let venv = venv_activateable $ls_results
    let nuenv = nuenv_activateable $ls_results
    let nix = nix_shell_activateable $ls_results

    let concat = $'(venv_activateable $ls_results)(nuenv_activateable $ls_results)(nix_shell_activateable $ls_results)'

    if ($concat | is-not-empty) {
        return $"($concat)"
    } else {
        return ""
    }
}


export-env {
    let USER_COLOR = if (is-admin) { $'(ansi red)' } else { $'(ansi $env.USER_COLOR)' }
    let user_host = $"($USER_COLOR)(whoami)(ansi reset)@($USER_COLOR)($env.HOSTNAME)(ansi reset)"

    $env.PROMPT_COMMAND_RIGHT = ""
    $env.PROMPT_COMMAND = {|| $"(ansi reset)╭─ ($user_host)(activateables)(get-cwd)(jj_stats)(venv_prompt)(nix_shell_prompt)(nuenv_prompt)
╰─"}
    $env.PROMPT_INDICATOR = $"(ansi reset)(ansi white_bold)(if (is-admin) { "#" } else { "$" })(ansi reset) "
}
