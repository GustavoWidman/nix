{
  system.defaults.NSGlobalDomain = {
    NSDocumentSaveNewDocumentsToCloud = false;
  };

  system.defaults.LaunchServices = {
    LSQuarantine = false;
  };

  system.defaults.CustomSystemPreferences."com.apple.AdLib" = {
    allowApplePersonalizedAdvertising = false;
    allowIdentifierForAdvertising = false;
    forceLimitAdTracking = true;
    personalizedAdsMigrated = false;
  };

  system.defaults.NSGlobalDomain = {
    _HIHideMenuBar = false; # Only hide menubar on fullscreen.

    AppleInterfaceStyle = "Dark";

    AppleScrollerPagingBehavior = true; # Jump to the spot that was pressed in the scrollbar.
    AppleShowScrollBars = "WhenScrolling";

    NSWindowShouldDragOnGesture = true; # CMD+CTRL click to drag window.

    AppleWindowTabbingMode = "always"; # Always prefer tabs for new windows.
    AppleKeyboardUIMode = 3; # Full keyboard access.
    ApplePressAndHoldEnabled = false; # No ligatures when you press and hold a key, just repeat it.

    NSScrollAnimationEnabled = true;
    NSWindowResizeTime = 0.003;

    "com.apple.keyboard.fnState" = true;
    "com.apple.trackpad.scaling" = 1.5; # Faster mouse speed.

    # InitialKeyRepeat = 10; # N * 15ms to start repeating, so about 150ms to start repeating.
    # KeyRepeat = 1; # N * 15ms, so 15ms between each keypress, about 66 presses per second. Very slow but it doesn't go faster than this.

    NSAutomaticCapitalizationEnabled = false;
    NSAutomaticDashSubstitutionEnabled = false;
    NSAutomaticInlinePredictionEnabled = false;
    NSAutomaticPeriodSubstitutionEnabled = false;
    NSAutomaticQuoteSubstitutionEnabled = false;

    NSNavPanelExpandedStateForSaveMode = true; # Expand save panel by default.
    PMPrintingExpandedStateForPrint = true; # Expand print panel by default.

    AppleSpacesSwitchOnActivate = false; # Do not switch workspaces implicitly.
  };

  system.defaults.CustomSystemPreferences."com.apple.dock".workspaces-auto-swoosh = false; # Read `AppleSpacesSwitchOnActivate`.

  system.defaults.CustomSystemPreferences."com.apple.CoreBrightness" = {
    "Keyboard Dim Time" = 60;
    KeyboardBacklight.KeyboardBacklightIdleDimTime = 60;
  };

  system.defaults.CustomSystemPreferences."com.apple.AppleMultitouchTrackpad" = {
    # Smooth clicking.
    FirstClickThreshold = 0;
    SecondClickThreshold = 0;
  };

  system.defaults.CustomSystemPreferences."com.apple.Accessibility".ReduceMotionEnabled = 1;
  system.defaults.universalaccess.reduceMotion = true;

  system.defaults.WindowManager = {
    AppWindowGroupingBehavior = false; # Show them one at a a time.
  };
}
