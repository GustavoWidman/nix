const LOG_COLORS = {
    info: "blue"
    success: "green"
    warn: "yellow"
    error: "red"
    debug: "dark_gray"
    host: "magenta_bold"
    path: "cyan"
    cmd: "white_dimmed"
}

# Export `main` so `use .../log.nu` exposes the command as `log`.
export def main [
    level: string
    message: string
    --exit (-e)
    --no-newline (-n)
    --redraw
    --return-instead
] {
    let color = ($LOG_COLORS | get $level)
    let prefix = match $level {
        "info" => "›"
        "success" => "✓"
        "warn" => "⚠"
        "error" => "✗"
        "debug" => "•"
        _ => "›"
    }

    let msg = if not $redraw {
        $'[(ansi $color)($prefix)(ansi reset)] ($message
            | str trim -l
            | lines
            | each { str trim -l }
            | str join $"\n (ansi white)|(ansi reset)  ")'
    } else {
        $"\r[(ansi $color)($prefix)(ansi reset)] ($message)"
    }

    if $return_instead {
        return $msg
    }

    if $exit {
        error make -u {
            msg: $msg
        }
    }

    match $no_newline {
        true => (print -n $msg)
        false => (print $msg)
    }
}
