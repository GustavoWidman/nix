export def clean-scan [
	file: string,
	outfile: string,
	--force (-f),
	--super-clean (-s),
] {
	if not ($file | path exists) {
		print "File not found: $file"
		return 1
	}

	jq -r 'select(.type == "response") | "\(.status) \(.url)"' $file
		| parse "{code} {url}"
		| sort-by code url
		| group-by code
		| transpose code table
		| each { |entry|
				mut items_formatted = ($entry.table | each { |item|
					if $super_clean {
						return $"($item.url)"
					} else {
						return $"[($item.code)] ($item.url)" # Format as "[STATUS] URL"
					}
				})

				if $super_clean {
					return $items_formatted
				} else {
					return ($items_formatted | append "")
				}
			}
		| flatten      # Flatten the list of lists into a single list of strings
    	| str join "\n" # Join all strings with newlines to form the final output
		| if $force { save --raw --force $outfile } else { save --raw $outfile }
}

export def stop [] {
	print $"(ansi reset)(ansi light_gray)[(ansi reset)(ansi green_bold)+(ansi reset)(ansi light_gray)](ansi reset)(ansi white_dimmed) Stopping HackingClub services..."

	let openvpn_alive = ^ps -ax -o pid= -o command=  | parse "{pid} {cmd}" | where cmd == $"openvpn ($env.TRUE_HOME | path join 'Cybersec/hackingclub/hackingclub.ovpn')"
	let ports = ports -lt

	# grant sudo grace period
	if not ($openvpn_alive | is-empty) {
		print $"(ansi reset)(ansi light_gray)[(ansi reset)(ansi yellow_bold)?(ansi reset)(ansi light_gray)](ansi reset)(ansi white) Killing (ansi reset)(ansi purple)OpenVPN(ansi reset)(ansi white) process...(ansi reset)(ansi red_bold)"
		let pid = $openvpn_alive
			| first
			| get pid
			| into int

		sudo kill $pid
	}

	let fileserver_pid = $ports | where local_port == 6969
	if not ($fileserver_pid | is-empty) {
		print $"(ansi reset)(ansi light_gray)[(ansi reset)(ansi yellow_bold)?(ansi reset)(ansi light_gray)](ansi reset)(ansi white) Killing (ansi reset)(ansi cyan)Python File Server(ansi reset)(ansi white) process..."
		kill ($fileserver_pid | first | get pid | into int)
	}

	let mitmweb_pids = $ports | where local_port == 8080 or local_port == 8081
	if not ($mitmweb_pids | is-empty) {
		print $"(ansi reset)(ansi light_gray)[(ansi reset)(ansi yellow_bold)?(ansi reset)(ansi light_gray)](ansi reset)(ansi white) Killing (ansi reset)(ansi green)MITMWeb(ansi reset)(ansi white) process..."
		for $pid in $mitmweb_pids {
			kill ($pid | get pid | into int)
		}
	}
}

export def main [] {
	print $"(ansi light_gray)[(ansi reset)(ansi green_bold)+(ansi reset)(ansi light_gray)](ansi reset)(ansi white_dimmed) Starting hackingclub services...(ansi reset)(ansi red_bold)"
	let openvpn_alive = ^ps -ax -o pid= -o command=  | parse "{pid} {cmd}" | where cmd == $"openvpn ($env.TRUE_HOME | path join 'Cybersec/hackingclub/hackingclub.ovpn')"
	let ports = ports -lt

	# grant sudo grace period
	sudo cat /dev/null

	if not ($openvpn_alive | is-empty) {
		print $"(ansi reset)(ansi light_gray)[(ansi reset)(ansi yellow_bold)?(ansi reset)(ansi light_gray)] (ansi reset)(ansi purple)OpenVPN(ansi reset)(ansi white) is already running, terminating the program.(ansi reset)"
		let pid = $openvpn_alive
			| first
			| get pid
			| into int

		sudo kill $pid
	}

	let openvpn = job spawn {
		sudo openvpn ($env.TRUE_HOME | path join "Cybersec/hackingclub/hackingclub.ovpn")
	}
	# wait for openvpn to start by checking if we have 10.0.71.220 as one of our IPs
	print --no-newline $"(ansi reset)(ansi light_gray)[(ansi reset)(ansi green_bold)+(ansi reset)(ansi light_gray)](ansi reset)(ansi white_dimmed) Waiting for (ansi reset)(ansi purple)OpenVPN(ansi reset)(ansi white_dimmed) to start.."
	while not (^ip addr | str contains "10.0.71.220") {
		print --no-newline $"."
		sleep 1sec
	}
	print $"\n(ansi reset)(ansi light_gray)[(ansi reset)(ansi green_bold)+(ansi reset)(ansi light_gray)] (ansi reset)(ansi purple)OpenVPN(ansi reset)(ansi white_dimmed) started with job ID (ansi reset)(ansi cyan)($openvpn)(ansi reset)(ansi white_dimmed).(ansi reset)"

	let fileserver_pid = $ports | where local_port == 6969
	if not ($fileserver_pid | is-empty) {
		print $"(ansi reset)(ansi light_gray)[(ansi reset)(ansi yellow_bold)?(ansi reset)(ansi light_gray)] (ansi reset)(ansi cyan)Python File Server(ansi reset)(ansi white) is already running on (ansi reset)(ansi cyan):6969(ansi reset)(ansi white), terminating the program.(ansi reset)"
		kill ($fileserver_pid | first | get pid | into int)
	}
	let fileserver = job spawn {
		^python3 -m http.server 6969 -d ($env.TRUE_HOME | path join "Cybersec/hackingclub")
	}
	print --no-newline $"(ansi reset)(ansi light_gray)[(ansi reset)(ansi green_bold)+(ansi reset)(ansi light_gray)](ansi reset)(ansi white_dimmed) Waiting for (ansi reset)(ansi blue)Python File Server(ansi reset)(ansi white_dimmed) to start.."
	while not (^curl -s http://localhost:6969 | str contains "Directory listing for /") {
		print --no-newline "."
		sleep 1sec
	}

	print $"\n(ansi reset)(ansi light_gray)[(ansi reset)(ansi green_bold)+(ansi reset)(ansi light_gray)] (ansi reset)(ansi blue)Python File Server(ansi reset)(ansi white_dimmed) started at (ansi reset)(ansi cyan):6969(ansi reset)(ansi white_dimmed) with job ID (ansi reset)(ansi cyan)($fileserver)(ansi reset)(ansi white_dimmed).(ansi reset)"

	let mitmweb_pids = $ports | where local_port == 8080 or local_port == 8081
	if not ($mitmweb_pids | is-empty) {
		print $"(ansi reset)(ansi light_gray)[(ansi reset)(ansi yellow_bold)?(ansi reset)(ansi light_gray)] (ansi reset)(ansi green)MITMWeb(ansi reset)(ansi white) is already running on (ansi reset)(ansi cyan):8081(ansi reset)(ansi white) \(proxy on (ansi reset)(ansi cyan):8080(ansi reset)(ansi white)\), terminating the program.(ansi reset)"
		for $pid in $mitmweb_pids {
			kill ($pid | get pid | into int)
		}
	}
	let mitmweb = job spawn {
		^mitmweb --no-web-open-browser --web-host 127.0.0.1 --set web_password='$argon2i$v=19$m=4096,t=3,p=1$c29tZXNhbHQ$b0Mhzuq+CHtGUgKwz97/ag4dPF03LuLqtrfaE+LoMcM'
	}

	print --no-newline $"(ansi reset)(ansi light_gray)[(ansi reset)(ansi green_bold)+(ansi reset)(ansi light_gray)](ansi reset)(ansi white_dimmed) Waiting for (ansi reset)(ansi green)MITMWeb(ansi reset)(ansi white_dimmed) to start.."
	while not (^curl -s http://127.0.0.1:8081 | str contains "mitmproxy") {
		print --no-newline "."
		sleep 1sec
	}

	print $"\n(ansi reset)(ansi light_gray)[(ansi reset)(ansi green_bold)+(ansi reset)(ansi light_gray)] (ansi reset)(ansi green)MITMWeb(ansi reset)(ansi white_dimmed) started at (ansi reset)(ansi cyan):8080(ansi reset)(ansi white) \(proxy on (ansi reset)(ansi cyan):8080(ansi reset)(ansi white_dimmed)\) with job ID (ansi reset)(ansi cyan)($mitmweb)(ansi reset)(ansi white_dimmed).(ansi reset)"


	print $"(ansi reset)(ansi light_gray)[(ansi reset)(ansi yellow_bold)?(ansi reset)(ansi light_gray)](ansi reset)(ansi white) Open VSCode on HackingClub Workspace?"
	if (["No", "Yes"] | input list) == "Yes" {
		^code ($env.TRUE_HOME | path join "Cybersec/hackingclub")
	}

	let $penenlope_pid = $ports | where local_port == 4444
	if not ($penenlope_pid | is-empty) {
		print $"(ansi reset)(ansi light_gray)[(ansi reset)(ansi yellow_bold)?(ansi reset)(ansi light_gray)] (ansi reset)(ansi red)Penelope(ansi reset)(ansi white_dimmed) is already running on (ansi reset)(ansi cyan):4444(ansi reset)(ansi white_dimmed), terminating the program.(ansi reset)"
		kill ($penenlope_pid | first | get pid | into int)
	}

	^penelope

	job kill $openvpn
	job kill $fileserver
	job kill $mitmweb

	hackingclub stop

	print $"(ansi reset)(ansi light_gray)[(ansi reset)(ansi green_bold)+(ansi reset)(ansi light_gray)](ansi reset)(ansi white_dimmed) HackingClub services stopped successfully."
}