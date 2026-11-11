# The current directory and each of its parents, nearest first.
export def ancestors [] {
    let parts = $env.PWD | path split
    seq ($parts | length) (-1) 1 | each {|n| $parts | first $n | path join }
}

# `name` inside each directory of the input list. `path join` would join the list into one path.
def under [name: string]: list<string> -> list<string> {
    $in | str replace -r '/?$' $"/($name)"
}

# Whether the current directory or one of its parents holds any of `names`.
export def in-tree-of [names: list<string>] {
    let dirs = ancestors
    true in ($names | each {|name| $dirs | under $name } | flatten | path exists)
}

# The nearest directory, from the current one up, that holds `name`, or "" when none does.
export def nearest-with [name: string] {
    let dirs = ancestors
    $dirs | zip ($dirs | under $name | path exists) | where $it.1 | get -o 0.0 | default ""
}
