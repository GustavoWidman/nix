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

def log [
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

def format_time [seconds: float] {
    let mins = ($seconds / 60 | math floor)
    let secs = ($seconds mod 60 | math round)

    if $mins > 0 {
        $"($mins)m ($secs)s"
    } else {
        $"($secs)s"
    }
}

export def main [
    path: string,
    out?: string
] {
    let out = (match ($out | is-empty) {
        true => ($path | path parse | get stem | $"($in).mp4")
        false => $out
    })

    log info $"compressing (ansi blue)($path)(ansi reset) -> (ansi green)($out)(ansi reset)"

    let duration = (ffprobe
        -v error
        -show_entries format=duration
        -of default=noprint_wrappers=1:nokey=1
        ($path | path expand))
    | into float

    let start_time = (date now)

    # Run ffmpeg with progress output
    (ffmpeg -i ($path | path expand)
        -c:v libx264
        -tag:v avc1
        -movflags faststart
        -crf 28
        -preset slower
        -tune stillimage
        -c:a aac -b:a 128k
        -progress pipe:1
        -loglevel error
        -hide_banner
        ($out | path expand))
    | lines
    | each { |line|
        if ($line | str contains "out_time_ms=") {
            let time_str = ($line | split row "=" | get 1)
            try {
                let time_ms = ($time_str | into int)
                let time_sec = ($time_ms / 1000000)
                let percent = (($time_sec / $duration) * 100 | math round)

                # Calculate ETA
                let elapsed = ((date now) - $start_time | into int) / 1_000_000_000
                let speed = if $elapsed > 0 { $time_sec / $elapsed } else { 0 }
                let remaining_video = $duration - $time_sec
                let eta_seconds = if $speed > 0 { $remaining_video / $speed } else { 0 }
                let eta_str = (format_time $eta_seconds)

                log info --redraw -n $"progress: (ansi purple)($percent)%(ansi reset) [(ansi yellow)($time_sec | math round -p 1)s(ansi reset) / ($duration | math round -p 1)s] ETA: (ansi cyan)($eta_str)(ansi reset)"
            }
        }
    }

    print "" # newline
    log success $"saved to: (ansi purple)($out)(ansi reset)"

    # Show file size comparison
    let old_size = (ls ($path | path expand) | get size | first)
    let new_size = (ls ($out | path expand) | get size | first)
    let reduction = ((1 - ($new_size / $old_size)) * 100 | math round)

    log info $"($old_size) → ($new_size) \((ansi green)($reduction)% smaller(ansi reset)\)"
}
