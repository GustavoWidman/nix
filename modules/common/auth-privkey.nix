{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  usersWithPrivateKeys = filterAttrs (name: user: user.authorizedKey != null) config.users.users;

  generateActivationScripts = mapAttrs' (
    username: user:
    nameValuePair "update-ssh-keys-${username}" {
      text = ''
        # Generate public key from private key for user ${username}
        if [ -f "${user.authorizedKey}" ]; then
          PUBLIC_KEY=$(${pkgs.openssh}/bin/ssh-keygen -y -f "${user.authorizedKey}")

          # Ensure the .ssh directory exists
          mkdir -p "${user.home}/.ssh"

          # Update authorized_keys
          echo "$PUBLIC_KEY" > "${user.home}/.ssh/authorized_keys"
          chown ${username}:${user.group} "${user.home}/.ssh/authorized_keys"
          chmod 600 "${user.home}/.ssh/authorized_keys"

          # Also set correct permissions on .ssh directory
          chown ${username}:${user.group} "${user.home}/.ssh"
          chmod 700 "${user.home}/.ssh"
        fi
      '';
      deps = [
        "agenix"
        "users"
      ];
    }
  ) usersWithPrivateKeys;

in
{
  options = {
    users.users = mkOption {
      type = types.attrsOf (
        types.submodule {
          options.authorizedKey = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = ''
              Path to a private key file from which to generate the public key
              for SSH authorized_keys. The public key will be automatically
              generated and added to the user's authorized_keys file.
            '';
          };
          options.isMainUser = mkOption {
            type = types.bool;
            default = false;
            description = ''
              If true, this user will be considered the main user of the system.
            '';
          };
        }
      );
    };
  };

  config = mkIf (usersWithPrivateKeys != { }) {
    system.activationScripts = generateActivationScripts;
  };
}
