{
  unit = "postfix.service";
  # dovecot answers imap and oxi the webmail. 465 and 993 rather than 25 and
  # 143, since home and oracle cloud connections to port 25 are blocked
  probes = [
    {
      kind = "smtp";
      target = "mail.r3dlust.com:465";
      tls = true;
    }
    {
      kind = "imap";
      target = "mail.r3dlust.com:993";
      tls = true;
    }
    {
      kind = "http";
      target = "https://mail.r3dlust.com";
    }
  ];
}
