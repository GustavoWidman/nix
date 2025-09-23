sudo yabai --load-sa
yabai -m signal --add event=dock_did_restart action='sudo yabai --load-sa'

yabai -m query --spaces
    | from json
    | where index > 5
    | each { yabai -m space --destroy 6 }

def setup_space [
    index: int
    name: string
    apps: list<string>
    --unmanaged (-u)
    --inverse (-i)
] {
    print $"setup space ($index) : ($name)"
    if (yabai -m query --spaces --space $index err> /dev/null | is-empty) {
        yabai -m space --create
    }

    yabai -m space $index --label $name

    if ($apps | is-empty) {
        return
    }

    let rule = if $inverse {
        $"app!=($apps | str join '|')"
    } else {
        $"app=($apps | str join '|')"
    }

    if $unmanaged {
        yabai -m rule --add $rule $"space=^($index)" "manage=off"
        yabai -m rule --apply $rule $"space=($index)" "manage=off"
    } else {
        yabai -m rule --add $rule $"space=^($index)"
        yabai -m rule --apply $rule $"space=($index)"
    }
}

def setup_app [
    apps: list<string>
    --inverse (-i)
    --unmanaged (-u)
    --sticky (-s)
] {
    let rule = if $inverse {
        $"app!=($apps | str join '|')"
    } else {
        $"app=($apps | str join '|')"
    }

    let unmanaged_rule = if $unmanaged {
        "manage=off"
    } else {
        "manage=on"
    }

    let sticky_rule = if $sticky {
        "sticky=on"
    } else {
        "sticky=off"
    }

    yabai -m rule --add $rule $unmanaged_rule $sticky_rule
    yabai -m rule --apply $rule $unmanaged_rule $sticky_rule
}

let zed = "Zed"
let ghostty = "Ghostty"
let zen = "Zen"
let whatsapp = "WhatsApp"
let discord = "Discord"
let finder = "Finder"
let preview = "Preview"
let settings = "System Settings"
let pip = "^Picture-in-"

let all_apps = [
    $zed,
    $ghostty,
    $zen,
    $whatsapp,
    $discord,
    $finder,
    $preview,
    $settings,
    $pip
]


setup_space 1 code [ $zed ]
setup_space 2 terminal [ $ghostty ] -u
setup_space 3 web [ $zen ]
setup_space 4 social [ $discord, $whatsapp ]
setup_space 5 other $all_apps -i

setup_app [ $settings $finder $preview ] -u
setup_app [ $pip ] -u -s
