def nudo-completer [spans: list<string>] {
    let $spans = $spans | skip 1 | prepend "sudo"

    ^carapace $spans.0 nushell ...$spans
        | from json
}

@complete "nudo-completer"
export def --wrapped --env main [...rest] {
    let args = $rest | str join " "
    sudo nu -c $args
}
