{
  power = {
    sleep = {
      computer = "never";
      display = "never";
    };
    restartAfterPowerFailure = true;
    restartAfterFreeze = true;
  };
  system.defaults.screensaver.askForPassword = false;

  networking.wakeOnLan.enable = true;

  services.openssh = {
    enable = true;
    # macOS sshd only sets the stock PATH, and nushell does not extend it
    # for non-interactive commands, so remote deploys would not find nix.
    extraConfig = ''
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      SetEnv PATH=/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
    '';
  };

  tailscale.enable = true;
}
