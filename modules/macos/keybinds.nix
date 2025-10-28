{
  system.defaults.CustomUserPreferences = {
    "com.apple.symbolichotkeys" = {
      AppleSymbolicHotKeys = {
        # Disable Spotlight Search (⌘Space by default)
        "64" = {
          enabled = 0;
          value = {
            parameters = [
              65535
              49
              1048576
            ];
            type = "standard";
          };
        };

        # Disable Finder Search Window (⌥⌘Space by default)
        "65" = {
          enabled = 0;
          value = {
            parameters = [
              65535
              49
              1572864
            ];
            type = "standard";
          };
        };

        # Copy picture of selected area to clipboard (⌘⇧S)
        "31" = {
          enabled = 1;
          value = {
            parameters = [
              65535
              1
              1179648
            ];
            type = "standard";
          };
        };

        # Screenshot and recording options (⌥⇧S)
        "184" = {
          enabled = 1;
          value = {
            parameters = [
              65535
              1
              655360
            ];
            type = "standard";
          };
        };
      };
    };
    "com.apple.universalaccess" = {
      # Command + L = Lock Screen
      NSUserKeyEquivalents = {
        "Lock Screen" = "@l";
      };
    };
  };
}
