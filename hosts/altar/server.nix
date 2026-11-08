{
  power = {
    sleep = {
      computer = "never";
      display = "never";
    };
    restartAfterPowerFailure = true;
    restartAfterFreeze = true;
  };

  networking.wakeOnLan.enable = true;

  services.openssh = {
    enable = true;
    extraConfig = ''
      PasswordAuthentication no
      KbdInteractiveAuthentication no
    '';
  };

  services.tailscale.enable = true;
}
