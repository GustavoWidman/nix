def get-cwd [] {
    let pwd = match $env.OS {
        "Darwin" => ((do { pwd })
            | str replace $env.HOME '~'
            | str downcase),
        _ => ((do { pwd })
            | str replace $env.HOME '~')
    }

    $" in (ansi blue)($pwd)(ansi reset)"
}

def superscript []: string -> string {
    $in
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
}

def find-jj-dir [pwd?: string] {
    mut current_dir = match ($pwd | is-empty) {
        true => (pwd),
        false => $pwd
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
        | each { get branches }
        | flatten
    # let current_branch = $branches
    #     | where remote == "origin"

    match ($branches | is-empty) {
        # try to get any remote (not just origin)
        true => {
            if ($branches | is-not-empty) {
                return ($branches
                    | first
                    | get name)
            }
        },
        false => {
            return ($branches
                | first
                | get name)
        }
    }
}

def get_status [commit_list: list] {
    let working_changes = $commit_list
        | first

    let is_empty = $working_changes
        | get empty

    if $is_empty {
        return "green" # clean
    }

    let has_commit_msg = $working_changes
        | get description
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
        jj --quiet -R $jjdir --color never --ignore-working-copy log --no-graph -r "(first_parent(mutable()) | mutable())::@ | @" -T 'empty ++ "\n" ++ description.first_line() ++ "\n" ++ immutable ++ "\n" ++ change_id ++ "\n" ++ json(remote_bookmarks) ++ "\n"' err> /dev/null
            | lines
            | chunks 5
            | where ($it.3 != "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz")
            | each {|commit|
                ({
                    empty: ($commit | get 0 | into bool),
                    description: ($commit | get 1),
                    branches: ($commit | get 4 | from json),
                    change_id: ($commit | get 3 | str substring 0..7)
                    immutable: ($commit | get 2 | into bool)
                })
            }
    }

    if ($commit_list | is-empty) {
        return $" in (ansi red)???(ansi reset) (ansi green)(ansi reset)"
    }

    let branch = get_branch $commit_list
    let detached = if (($branch | is-empty) or (($commit_list | length) <= 1)) {
        $commit_list
            | first
            | get change_id
    }
    let status = get_status $commit_list
    let unpushed_commits = match ($detached | is-empty) {
        true => {
            let valid_commits = $commit_list
                | where {|c|
                    ($c.description | is-not-empty) and not ($c.immutable)
                }
                # maybe also add $c.empty check here (commit is not empty)

            let total = $valid_commits
                | length

            let untugged_commits = $valid_commits
                | take until {|c| $c.branches | any {|b|
                    (($b.name == $branch) and ($b.remote == "git"))
                } }
                | length

            ({
                tugged: ($total - $untugged_commits),
                untugged: $untugged_commits,
                total: $total
            })
        },
        false => ({
            tugged: 0,
            untugged: 0,
            total: 0
        })
    }
    let unpushed_commits_str = if ($unpushed_commits.total > 0) {
        if ($unpushed_commits.tugged > 0 and $unpushed_commits.untugged > 0) {
            $"(ansi blue)($unpushed_commits.tugged | into string | superscript)(ansi reset)⸍(ansi yellow)($unpushed_commits.untugged | into string | superscript)(ansi reset)"
        } else if ($unpushed_commits.untugged > 0) {
            $"(ansi yellow)($unpushed_commits.untugged | into string | superscript)(ansi reset)"
        } else {
            $"(ansi blue)($unpushed_commits.tugged | into string | superscript)(ansi reset)"
        }
    } else { "" }
    let consolidated_branch = match ($detached | is-not-empty) {
        true => $detached,
        false => $branch
    }

    return $" in (ansi red)($consolidated_branch)(ansi reset)($unpushed_commits_str) (ansi $status)(ansi reset)"
}

def venv_prompt [] {
    match ("VIRTUAL_ENV_PROMPT" in $env) {
        true => $" using (ansi green)(($env.VIRTUAL_ENV_PROMPT))(ansi reset)",
        false => ""
    }
}

def nuenv_prompt [] {
    match (("NU_ENV" in $env) and ($env.NU_ENV != null)) {
        true => $" using (ansi purple)($env.NU_ENV.name)(ansi reset)",
        false => ""
    }
}

def nix_shell_prompt [] {
    match (("IN_NIX_SHELL" in $env) and ($env.IN_NIX_SHELL | is-not-empty)) {
        true => $" in (ansi cyan)nix-shell(ansi reset)"
        false => ""
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

	match (($venvs | is-not-empty) and not ("VIRTUAL_ENV_PROMPT" in $env)) {
	    true => $"(ansi green_bold)⁺(ansi reset)",
	    false => ""
	}
}

def nuenv_activateable [ls_results] {
    let nu_files = $ls_results
        | where {|el| ($el | get type) == "file" }
        | par-each { get name | path parse }
        | where {|el| ($el | get extension) == "nu" }

    match (($nu_files | is-not-empty) and not (("NU_ENV" in $env) and ($env.NU_ENV != null))) {
        true => $"(ansi purple_bold)⁺(ansi reset)",
        false => ""
    }
}

def nix_shell_activateable [ls_results] {
    let nix_flakes = $ls_results
        | where name == "flake.nix"

    match (($nix_flakes | is-not-empty) and (open ($nix_flakes | first | get name) | str contains "devShells") and (not (("NIX_BUILD_TOP" in $env) or ("IN_NIX_SHELL" in $env)))) {
        true => $"(ansi cyan_bold)⁺(ansi reset)",
        false => ""
    }
}

def activateables [] {
    let ls_results = ls -a err> /dev/null
    let venv = venv_activateable $ls_results
    let nuenv = nuenv_activateable $ls_results
    let nix = nix_shell_activateable $ls_results

    let concat = $'(venv_activateable $ls_results)(nuenv_activateable $ls_results)(nix_shell_activateable $ls_results)'

    match ($concat | is-not-empty) {
        true => $"($concat)",
        false => ""
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
