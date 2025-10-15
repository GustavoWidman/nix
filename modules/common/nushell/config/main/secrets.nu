def all-secrets [] {
    (nix eval --impure --expr "builtins.attrNames (import ./secrets.nix)" --json | from json)
}

def existing-secrets [] {
    all-secrets | where { path exists }
}

export def "edit" [path: path@all-secrets] {
    sudo agenix -i /etc/ssh/ssh_host_ed25519_key -e $path
}

export def "cat" [path: path@existing-secrets] {
    sudo age -d -i /etc/ssh/ssh_host_ed25519_key $path
}

export def "rekey" [] {
    sudo agenix -r -i /etc/ssh/ssh_host_ed25519_key
}
