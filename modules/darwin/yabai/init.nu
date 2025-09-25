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
    titles: list<string>
    --unmanaged (-u)
    --inverse (-i)
] {
    print $"setup space ($index) : ($name)"
    if (yabai -m query --spaces --space $index err> /dev/null | is-empty) {
        yabai -m space --create
    }

    yabai -m space $index --label $name

    if (($apps | is-empty) and ($titles | is-empty)) {
        return
    }
    # apps not empty or titles not empty or both

    let app_rule = $"app(if $inverse {'!'} else '')=($apps | str join '|')"
    let title_rule = $"title(if $inverse {'!'} else '')=($titles | str join '|')"

    let manage_rule = $"manage=(if $unmanaged {'off'} else {'on'})"

    if ($apps | is-not-empty) { # apps not empty
        if ($titles | is-not-empty) { # apps not empty and titles not empty
            yabai -m rule --add $app_rule $title_rule $"space=^($index)" $manage_rule
            yabai -m rule --apply $app_rule $title_rule $"space=($index)" $manage_rule
        } else { # only apps not empty
            yabai -m rule --add $app_rule $"space=^($index)" $manage_rule
            yabai -m rule --apply $app_rule $"space=($index)" $manage_rule
        }
    } else { # only titles not empty
        yabai -m rule --add $title_rule $"space=^($index)" $manage_rule
        yabai -m rule --apply $title_rule $"space=($index)" $manage_rule
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

def setup_title [
    titles: list<string>
    --inverse (-i)
    --unmanaged (-u)
    --sticky (-s)
] {
    let rule = if $inverse {
        $"title!=($titles | str join '|')"
    } else {
        $"title=($titles | str join '|')"
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
let turtlesim = "turtlesim_node"
let pip = [ "Picture-in-picture Window", "Picture-in-Picture" ]
let save = [ "Save", "Save As" ]

let all_apps = [
    $zed,
    $ghostty,
    $zen,
    $whatsapp,
    $discord,
    $finder,
    $preview,
    $settings,
    $turtlesim
]

let all_titles = [
    ...$pip,
    ...$save,
]

yabai -m rule --add app=".*" sub-layer=normal
yabai -m signal --add event=application_front_switched action="yabai -m window --sub-layer normal"

setup_space 1 code [ $zed ] []
setup_space 2 terminal [ $ghostty ] [] -u
setup_space 3 web [ $zen ] []
setup_space 4 social [ $discord, $whatsapp ] []
setup_space 5 other $all_apps $all_titles -i

setup_app [ $settings $finder $preview ] -u
setup_app [ $turtlesim ] -u -s

setup_title $pip -u -s
setup_title $save -u

# Switch to "partially focused" applications
yabai -m signal --add event=application_activated action='
focused_pid=$(lsappinfo info -only pid `lsappinfo front` | cut -d= -f2)
current_space=$(yabai -m query --spaces --space | jq -r ".index")
focused_space=$(yabai -m query --windows | jq -r "map(select(.pid == $focused_pid and .\"is-sticky\" == false)) | .[0].space // empty")
echo "focused pid: $focused_pid | current space: $current_space | focused space: $focused_space | date: $(date)" >> /tmp/yabai-debug.log
if [[ -n "$focused_space" && "$current_space" != "$focused_space" ]]; then
    yabai -m space --focus "$focused_space"
fi
'

# float unresizeable windows by default
yabai -m signal --add event=window_created action='
can_resize=$(yabai -m query --windows --window $YABAI_WINDOW_ID | jq -r ".\"can-resize\"")
if [[ $can_resize == "false" ]]; then
    yabai -m window $YABAI_WINDOW_ID toggle float
'
