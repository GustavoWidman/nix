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

def update_git_status_cache [gitdir: string cachepath: string] {
    let status_lines = (git -C $"($gitdir)" status --porcelain | lines)

    if ($status_lines | is-empty) {
        "green" | save -f $cachepath
        return "green"
    }

    let staged = ($status_lines | any {|line| ($line | str substring ..0) not-in [" ", "?"]})
    if $staged {
        "yellow" | save -f $cachepath
        return "yellow"
    }

    let unstaged = ($status_lines | any {|line| ($line | str substring 0..1) not-in [" ", "?"]})
    let untracked = ($status_lines | any {|line| $line | str starts-with "??"})

    if ($unstaged or $untracked) {
        "red" | save -f $cachepath
        return "red"
    }

    # if we reach here, everything is clean i guess (shouldn't happen realistically)
    "green" | save -f $cachepath
    return "green"
}

def update_git_status_cache_forever [gitdir: string cachepath: string] {
    loop {
        update_git_status_cache $gitdir $cachepath

        sleep 10sec
    }
}

def git_status_color [gitdir: string] {
    let $cachepath = $nu.temp-path
        | path join $"git-status-cache($gitdir | path expand | str replace -a "/" "-" | str downcase)"

    if not (job list
        | any {|job|
            ($job | get -o tag) == $"git-status-cache($gitdir | str replace -a "/" "-" | str downcase)"
        }
    ) {
        job spawn {
            update_git_status_cache_forever $gitdir $cachepath
        } -t $"git-status-cache($gitdir | str replace -a "/" "-" | str downcase)"
    }

    if ($cachepath | path exists) {
        job spawn { update_git_status_cache $gitdir $cachepath }
        return (open --raw $cachepath)
    } else {
        return (update_git_status_cache $gitdir $cachepath)
    }
}

def git_branch [] {
    let gitdir = find-git-dir | str trim
    if $gitdir == "" {
        return ""
    }

	let head = open $"($gitdir)/.git/HEAD"

	let branch = if ($head | str starts-with "ref: refs/heads/") {
        ($head | str substring 16..)
    } else {
        ($head | str substring 0..7)
    } | str trim;

	let status_color = git_status_color $gitdir

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
