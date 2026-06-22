{
  config,
  lib,
  pkgs,
  options,
  ...
}:

with lib;

let
  usersWithPrivateKeys = filterAttrs (name: user: user.authorizedKey != null) config.users.users;

  generateActivationScripts = mapAttrs' (
    username: user:
    let
      group = user.group or (if config.isDarwin then "staff" else "users");
    in
    nameValuePair "update-ssh-keys-${username}" (
      {
        text = # sh
          ''
            # Generate public key from private key for user ${username}
            if [ ! -f "${user.authorizedKey}" ]; then
              echo "Waiting for ${user.authorizedKey} before updating ${user.home}/.ssh/authorized_keys"
              for _ in 1 2 3 4 5 6 7 8 9 10; do
                [ -f "${user.authorizedKey}" ] && break
                sleep 1
              done
            fi

            if [ ! -f "${user.authorizedKey}" ]; then
              echo "Missing ${user.authorizedKey}; cannot update ${user.home}/.ssh/authorized_keys" >&2
              exit 1
            fi

            PUBLIC_KEY=$(${pkgs.openssh}/bin/ssh-keygen -y -f "${user.authorizedKey}")

            # Ensure the .ssh directory exists
            mkdir -p "${user.home}/.ssh"

            # Update authorized_keys
            echo "$PUBLIC_KEY" > "${user.home}/.ssh/authorized_keys"
            chown ${username}:${group} "${user.home}/.ssh/authorized_keys"
            chmod 600 "${user.home}/.ssh/authorized_keys"

            # Also set correct permissions on .ssh directory
            chown ${username}:${group} "${user.home}/.ssh"
            chmod 700 "${user.home}/.ssh"
          '';
      }
      // (
        if config.isLinux then
          {
            deps = [
              "agenix"
              "users"
            ];
          }
        else if config.isDarwin then
          { }
        else
          { }
      )
    )
  ) usersWithPrivateKeys;

  generateDarwinLaunchDaemons = mapAttrs' (
    username: script:
    nameValuePair username {
      script = script.text;
      serviceConfig = {
        RunAtLoad = true;
        KeepAlive.SuccessfulExit = false;
      };
    }
  ) generateActivationScripts;

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
          # TODO remove this from here
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

  config = mkMerge [
    (mkIf (usersWithPrivateKeys != { } && config.isLinux) {
      system.activationScripts = generateActivationScripts;
    })

    (optionalAttrs (options ? launchd) (
      mkIf (usersWithPrivateKeys != { } && config.isDarwin) {
        launchd.daemons = generateDarwinLaunchDaemons;
      }
    ))
  ];
}
