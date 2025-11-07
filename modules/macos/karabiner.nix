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
    # "t"
    "u"
    "v"
    "w"
    "x"
    "y"
    # "z"
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
              shell_command = "${pkgs.aerospace}/bin/aerospace workspace-back-and-forth";
              # shell_command = "${pkgs.rift}/bin/rift-cli execute workspace last";
            }
          ];
          type = "basic";
        }
      ];
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
