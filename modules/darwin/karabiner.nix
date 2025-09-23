{ pkgs, lib, ... }:
let
  inherit (lib.strings)
    toJSON
    ;

  isBuiltIn = {
    type = "device_if";
    identifiers = [
      {
        is_built_in_keyboard = true;
      }
    ];
  };

  makeManipulator = key: {
    from.key_code = key;
    from.modifiers.mandatory = [ "option" ];

    to = [ { key_code = key; } ];
    type = "basic";
    conditions = [ isBuiltIn ];
  };
  makeOptionDisableManipulators = keys: map makeManipulator keys;

  makeFocusSpace = key: {
    from.key_code = key;
    from.modifiers.mandatory = [ "option" ];

    to = [
      { shell_command = "${pkgs.yabai}/bin/yabai -m space --focus ${key}"; }
    ];
    type = "basic";
  };
  makeMoveSpace = key: {
    from.key_code = key;
    from.modifiers.mandatory = [
      "option"
      "shift"
    ];

    to = [ { shell_command = "${pkgs.yabai}/bin/yabai -m window --space ${key} --focus"; } ];
    type = "basic";
  };

  letters = [
    "a"
    "b"
    "c"
    "d"
    "e"
    # "f"
    "g"
    # "h"
    "i"
    # "j"
    # "k"
    # "l"
    "m"
    "n"
    "o"
    "p"
    "q"
    "r"
    "s"
    "t"
    "u"
    "v"
    "w"
    "x"
    "y"
    "z"
  ];
  numbers = [
    "1"
    "2"
    "3"
    "4"
    "5"
    "6"
    "7"
    "8"
    "9"
    "0"
  ];
  punctuation = [
    "hyphen"
    "equal_sign"
    "open_bracket"
    "close_bracket"
    "backslash"
    "semicolon"
    "quote"
    "grave_accent_and_tilde"
    "comma"
    "period"
    "slash"
  ];

  allStandardKeys = letters ++ punctuation;

  simple_modifications = [
    {
      from.key_code = "caps_lock";

      to = [ { key_code = "escape"; } ];
    }

    {
      from.key_code = "escape";

      to = [ { key_code = "caps_lock"; } ];
    }
  ];

  complex_modifications.rules = [
    {
      description = "Disable alt+key combos";
      manipulators = makeOptionDisableManipulators allStandardKeys;
    }
    {
      description = "Yabai Binds";
      manipulators = [
        {
          from.key_code = "tab";
          from.modifiers.mandatory = [ "command" ];

          to = [
            {
              shell_command = "${pkgs.yabai}/bin/yabai -m space --focus recent";
            }
          ];
          type = "basic";
        }
        {
          from.key_code = "tab";
          from.modifiers.mandatory = [
            "option"
          ];

          to = [
            {
              shell_command = "${pkgs.yabai}/bin/yabai -m space --focus next";
            }
          ];
          type = "basic";
        }
        {
          from.key_code = "tab";
          from.modifiers.mandatory = [
            "option"
            "shift"
          ];

          to = [
            {
              shell_command = "${pkgs.yabai}/bin/yabai -m space --focus prev";
            }
          ];
          type = "basic";
        }
      ]
      ++ (map makeFocusSpace numbers)
      ++ (map makeMoveSpace numbers);
    }
  ];
in
{
  homebrew.casks = [ "karabiner-elements" ];

  home-manager.sharedModules = [
    {
      xdg.configFile."karabiner/karabiner.json".text = toJSON {
        global.show_in_menu_bar = false;

        profiles = [
          {
            inherit complex_modifications;

            name = "Default";
            selected = true;

            virtual_hid_keyboard.keyboard_type_v2 = "ansi";

            devices = [
              {
                inherit simple_modifications;

                identifiers.is_keyboard = true;
              }
            ];
          }
        ];
      };
    }
  ];
}
