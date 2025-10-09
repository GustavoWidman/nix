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
            yabai -m rule --add $app_rule $title_rule subrole="AXStandardWindow" $"space=^($index)" $manage_rule
            yabai -m rule --apply $app_rule $title_rule subrole="AXStandardWindow" $"space=($index)" $manage_rule
        } else { # only apps not empty
            yabai -m rule --add $app_rule subrole="AXStandardWindow" $"space=^($index)" $manage_rule
            yabai -m rule --apply $app_rule subrole="AXStandardWindow" $"space=($index)" $manage_rule
        }
    } else { # only titles not empty
        yabai -m rule --add $title_rule subrole="AXStandardWindow" $"space=^($index)" $manage_rule
        yabai -m rule --apply $title_rule subrole="AXStandardWindow" $"space=($index)" $manage_rule
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
let unmanaged_sticky_apps = [
    "turtlesim_node",
]
let unmanaged_apps = [
    "TextEdit",
    "iPhone Mirroring",
    "Sideloadly!",
    "System Settings" ,
    "Finder",
    "Preview"
]
let unmanaged_sticky_titles = [
    "Picture-in-picture Window",
    "Picture-in-Picture"
]
let unmanaged_titles = [
    "Save",
    "Save As",
    "Extension"
    "Settings Window",
]

let all_apps = [
    $zed,
    $ghostty,
    $zen,
    $whatsapp,
    $discord,
    ...$unmanaged_apps
    ...$unmanaged_sticky_apps
]

let all_titles = [
    ...$unmanaged_titles,
    ...$unmanaged_sticky_titles,
]

# Switch to "partially focused" applications
let partially_focused_handler = '
focused_pid=$(lsappinfo info -only pid `lsappinfo front` | cut -d= -f2)
current_space=$(yabai -m query --spaces --space | jq -r ".index")
focused_space=$(yabai -m query --windows | jq -r "map(select(.pid == $focused_pid and .\"is-sticky\" == false)) | .[0].space // empty")
if [[ -n "$focused_space" && "$current_space" != "$focused_space" ]]; then
    yabai -m space --focus "$focused_space"
fi
' | str trim | $"action=($in)"
yabai -m signal --add event=application_activated $partially_focused_handler

# float unresizeable windows by default
let unresizeable_handler = '
can_resize=$(yabai -m query --windows --window $YABAI_WINDOW_ID | jq -r ".\"can-resize\"")
if [[ $can_resize == "false" ]]; then
    yabai -m window $YABAI_WINDOW_ID toggle float
fi
' | str trim | $"action=($in)"
yabai -m signal --add event=window_created $unresizeable_handler

yabai -m rule --add app=".*" sub-layer=normal
yabai -m signal --add event=application_front_switched action="yabai -m window --sub-layer normal"

yabai -m rule --add subrole!="AXStandardWindow" manage=off

setup_space 1 code [ $zed ] []
setup_space 2 terminal [ $ghostty ] [] -u
setup_space 3 web [ $zen ] []
setup_space 4 social [ $discord ] []

let whatsapp_rule = $"
can_resize=$\(yabai -m query --windows --window $YABAI_WINDOW_ID | jq -r \".\\\"can-resize\\\"\"\)
if [[ $can_resize == \"true\" ]]; then
    yabai -m window --space 4 --focus
fi
" | str trim | $"action=($in)"
yabai -m rule --apply $"app=($whatsapp)" subrole="AXStandardWindow" "space=4"
yabai -m signal --add event=window_created $"app=($whatsapp)" $whatsapp_rule

setup_space 5 other $all_apps $all_titles -i

setup_app $unmanaged_apps -u
setup_app $unmanaged_sticky_apps -u -s

setup_title $unmanaged_titles -u
setup_title $unmanaged_sticky_titles -u -s
