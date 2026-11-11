use ../utils/paths.nu nearest-with

def get-cwd [] {
    let pwd = match $env.OS {
        "Darwin" => ((do { pwd })
            | str replace $env.HOME '~'
            | str lowercase),
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

def jj_stats [jjdir: string] {
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

# A marker for each environment the current directory offers that is not active yet:
# a python venv, a .nu environment, and a nix devshell.
def activateables [] {
    let entries = ls -a err> /dev/null

    let venv = (not ("VIRTUAL_ENV_PROMPT" in $env)) and (
        $entries
            | where type == dir and name =~ "(?i)env"
            | where ($env.PWD | path join $it.name bin activate.nu | path exists)
            | is-not-empty
    )
    let nuenv = (not (("NU_ENV" in $env) and ($env.NU_ENV != null))) and (
        $entries | where type == file and name ends-with ".nu" | is-not-empty
    )
    let nix = (not (("NIX_BUILD_TOP" in $env) or ("IN_NIX_SHELL" in $env))) and (
        ("flake.nix" | path exists) and (open --raw flake.nix | str contains "devShells")
    )

    [
        (if $venv { $"(ansi green_bold)⁺(ansi reset)" })
        (if $nuenv { $"(ansi purple_bold)⁺(ansi reset)" })
        (if $nix { $"(ansi cyan_bold)⁺(ansi reset)" })
    ] | compact | str join
}

def jj_cache_file [jjdir: string] {
    $env.TMPDIR | path join $"nu-prompt-jj-($jjdir | hash md5)"
}

# The jj segment costs an external call, which is slow from the REPL. Draw the prompt with
# the segment this repo showed last, then refresh it from a background job.
def render_prompt [head: string, tail: string] {
    job list | where description == prompt-jj | each { job kill $in.id } | ignore

    let jjdir = nearest-with .jj
    if $jjdir == "" {
        return $"($head)($tail)"
    }

    let cache = jj_cache_file $jjdir
    job spawn --description prompt-jj {
        let stats = jj_stats $jjdir
        $stats | save -f $cache
        commandline set-prompt $"($head)($stats)($tail)"
    } | ignore

    let cached = if ($cache | path exists) { open --raw $cache } else { "" }
    $"($head)($cached)($tail)"
}


export-env {
    let USER_COLOR = if (is-admin) { $'(ansi red)' } else { $'(ansi $env.USER_COLOR)' }
    let user_host = $"($USER_COLOR)(whoami)(ansi reset)@($USER_COLOR)($env.HOSTNAME)(ansi reset)"

    $env.PROMPT_COMMAND_RIGHT = ""
    $env.PROMPT_COMMAND = {||
        render_prompt $"(ansi reset)╭─ ($user_host)(activateables)(get-cwd)" $"(venv_prompt)(nix_shell_prompt)(nuenv_prompt)\n╰─"
    }
    $env.PROMPT_INDICATOR = $"(ansi reset)(ansi white_bold)(if (is-admin) { "#" } else { "$" })(ansi reset) "
}
