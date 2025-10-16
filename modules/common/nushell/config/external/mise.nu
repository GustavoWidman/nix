def "parse vars" [] {
    $in
        | from csv --noheaders --no-infer
        | rename 'op' 'name' 'value'
}

export def --env --wrapped main [command?: string, --help, ...rest: string] {
    let commands = ["deactivate", "shell", "sh"]

    if ($command == null) {
        ^mise
    } else if ($command == "activate") {
        $env.MISE_SHELL = "nu"
    } else if ($command in $commands) {
        ^mise $command ...$rest
            | parse vars
            | update-env
    } else {
        ^mise $command ...$rest
    }
}

def --env "update-env" [] {
    for $var in $in {
        if $var.op == "set" {
            if $var.name == 'PATH' {
                $env.PATH = ($var.value | split row (char esep))
            } else {
                load-env {($var.name): $var.value}
            }
        } else if $var.op == "hide" {
            hide-env $var.name
        }
    }
}

export def --env hook [] {
    ^mise hook-env -s nu
        | parse vars
        | update-env
}
