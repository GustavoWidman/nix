def nudo-completer [place: record] {
    let spans = $place.command | skip 1 | prepend "sudo"

    ^carapace $spans.0 nushell ...$spans
        | from json
}

@complete "nudo-completer"
export def --wrapped --env main [...rest] {
    let args = $rest | str join " "
    sudo nu -c $args
}
