# Jump to a directory using only keywords.
export def --env --wrapped z [...rest: string] {
    let $rest = $rest | str replace -a '~' $env.HOME
    let path = match $rest {
        [] => {$env.HOME},
        [ '-' ] => {'-'},
        [ $arg ] if ($arg | path expand | path type) == 'dir' => {$arg}
        _ => {
        zoxide query --exclude $env.PWD -- ...$rest | str trim -r -c "\n"
        }
    }
    cd $path
}

# Jump to a directory using interactive search.
export def --env --wrapped zi [...rest:string] {
    cd $'(zoxide query --interactive -- ...$rest | str trim -r -c "\n")'
}
