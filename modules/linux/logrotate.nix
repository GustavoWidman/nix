{
  services.logrotate = {
    enable = true;
    settings = {
      header = {
        rotate = 7;
        frequency = "daily";
        dateext = true;
        compress = true;
        delaycompress = true;
        notifempty = true;
        missingok = true;
      };
    };
  };
}
