export def --env main [
    --disable-udp (-t)         # do not fetch UDP connections (TCP only)
    --disable-tcp (-u)         # do not fetch TCP connections (UDP only)
    --disable-ipv4 (-6)        # do not fetch IPv4 connections (IPv6 only)
    --disable-ipv6 (-4)        # do not fetch IPv6 connections (IPv4 only)
    --listeners (-l)           # show only listening connections
] {
    let raw_output = do -i {
        ^lsof -P -i UDP -i TCP -n
    } | complete

    if $raw_output.exit_code > 1 {
        print $"Error: Could not execute lsof. Make sure lsof is installed."
        print $"Exit code: $raw_output.exit_code"
        print $"stderr: ($raw_output.stderr)"
        return
    }

    let connections = $raw_output.stdout
        | lines
        | skip 1
        | where ($it | str trim) != ""
        | each { |line|
            let parts = $line | str replace -a -r '[\s\xFEFF]+' ' ' | split row ' '

            let ip_version = $parts.4 | str replace "IPv" "" | into int

            let $addresses = if ($parts.8 | str contains "]") {
                $parts.8
                    | split row "->"
                    | each { |addr| $addr | str replace "[" "" | split row ']:' }
            } else {
                $parts.8
                    | split row "->"
                    | each { |addr| $addr | split row ':' }
            }

            let local_addr = $addresses
                | first
                | first
                | str replace "*" (if $ip_version == 4 {"0.0.0.0"} else { "::" })
            let local_port = $addresses
                | first
                | last
                | str replace "*" "0"

            let remote_addr = if ($addresses | length) > 1 {
                $addresses
                    | last
                    | first
                    | str replace "*" (if $ip_version == 4 {"0.0.0.0"} else { "::" })
            } else { "" }
            let remote_port = if ($addresses | length) > 1 {
                $addresses
                    | last
                    | last
                    | str replace "*" "0"
            } else { "" }

            let pid = $parts.1
                | into int
            let protocol = $parts.7
                | str downcase
            let state = $parts
                | get -i 9
                | default "LISTEN"
                | str replace --regex --all "[()]+" ""

            return {
                pid: $pid
                type: $protocol
                ip_version: $ip_version
                local_address: $local_addr
                local_port: $local_port
                remote_address: $remote_addr
                remote_port: $remote_port
                state: $state
            }
        }
        | where ($it != null)  # Filter out null entries

    $connections
        | where (if $listeners { $in.state == "LISTEN" } else { true })
        | where (if $disable_ipv4 { $in.ip_version == 6 } else { true })
        | where (if $disable_ipv6 { $in.ip_version == 4 } else { true })
        | where (if $disable_udp { $in.type == "tcp" } else { true })
        | where (if $disable_tcp { $in.type == "udp" } else { true })
        | select pid type ip_version local_address local_port remote_address remote_port state
}
