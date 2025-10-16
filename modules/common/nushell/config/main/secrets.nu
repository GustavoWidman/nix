def all-secrets [] {
    (nix eval --impure --expr "builtins.attrNames (import ./secrets.nix)" --json | from json)
}

def existing-secrets [] {
    all-secrets | where { path exists }
}

export def --env "edit" [
    path: path@all-secrets
    --editor (-e): string # The editor to use when editing the file. Default to `$env.EDITOR`
] {
    let editor = match ($editor | is-empty) {
        true => $env.EDITOR,
        false => $editor
    };

    let home = match ($env.OS == "Darwin") {
        true => "/var/root",
        false => "/root"
    }

    with-env { HOME: $home, EDITOR: $editor } { sudo agenix -i /etc/ssh/ssh_host_ed25519_key -e $path }
}

export def "cat" [path: path@existing-secrets] {
    sudo age -d -i /etc/ssh/ssh_host_ed25519_key $path
}

export def "rekey" [] {
    let home = match ($env.OS == "Darwin") {
        true => "/var/root",
        false => "/root"
    }

    with-env { HOME: $home } { sudo agenix -r -i /etc/ssh/ssh_host_ed25519_key }
}
