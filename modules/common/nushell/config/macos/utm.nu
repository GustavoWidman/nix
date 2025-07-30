export def kali [] {
	utm attach "602A8088-52AA-4C99-A962-FDF9D8C2D32E" "Kali"
}

export def "kali status" [] {
	utm status "602A8088-52AA-4C99-A962-FDF9D8C2D32E" "Kali"
}

export def "kali stop" [] {
	utm stop "602A8088-52AA-4C99-A962-FDF9D8C2D32E" "Kali"
}

export def "kali start" [] {
	utm start "602A8088-52AA-4C99-A962-FDF9D8C2D32E" "Kali"
}

export def start [id: string, name?: string] {
	if (pgrep -lf UTM | is-empty) {
		job spawn { ^utm }
		sleep 1sec
	}

	if (^utmctl status $id | str contains "stopped") {
		print $"Starting ($name) VM."

		^utmctl start $id

		print --no-newline $"Waiting for ($name) VM to start."

		let $ip_file = ($nu.temp-path | path join $"($id)_($name).ip")

		do { ^nc -lnp 4444 e> /dev/null | save --raw --force $ip_file }

		let $ip = open --raw $ip_file | str trim

		loop {
			if (^timeout 1 nc $ip 22 | str contains "SSH") {
				break
			} else {
				sleep 1sec
				print --no-newline "."
			}
		}

		print $"\n($name) VM is up and running!"

		return $ip
	} else {
		print $"($name) VM is already running."

		let $ip_path = ($nu.temp-path | path join $"($id)_($name).ip")
		if not ($ip_path | path exists) {
			print $"No IP address found for ($name) VM. VM is running but unable to connect."
			return
		}

		let $ip = open --raw $ip_path | str trim
		if ($ip | is-empty) {
			print $"No IP address found for ($name) VM. VM is running but unable to connect."
		} else {
			return $ip
		}
	}
}

export def stop [id: string, name?: string] {
	if (pgrep -lf UTM | is-empty) {
		job spawn { ^utm }
		sleep 1sec
	}

	if (^utmctl status $id | str contains "stopped") {
		print $"($name) VM is already stopped."
	} else {
		let $ip_file = ($nu.temp-path | path join $"($id)_($name).ip")
		if not ($ip_file | path exists) {
			print $"No IP address found for ($name) VM. VM is running but unable to connect."
			return
		}

		let $ip = open --raw $ip_file | str trim
		if ($ip | is-empty) {
			print $"No IP address found for ($name) VM. VM is running but unable to connect."
			return
		}

		^ssh $ip "poweroff"
		print --no-newline $"Stopping ($name) VM."

		loop {
			if (^utmctl status $id | str contains "stopped") {
				print $"\n($name) VM has been stopped!"
				break
			} else {
				sleep 1sec
				print --no-newline "."
			}
		}

		rm -f $ip_file
	}
}

export def attach [id: string, name?: string] {
	if (pgrep -lf UTM | is-empty) {
		job spawn { ^utm }
		sleep 1sec
	}

	let ip = utm start $id $name

	with-env { TERM: "xterm-256color" } { ^ssh $ip }

	print $"Shutdown ($name) VM?"
	if ([false, true] | input list) {
		utm stop $id $name
	}
}

export def status [id: string, name?: string] {
	if (pgrep -lf UTM | is-empty) {
		job spawn { ^utm }
		sleep 1sec
	}

	if (^utmctl status $id | str contains "stopped") {
		print $"($name) VM is stopped."
	} else {
		print $"($name) VM is running."

		let $ip_path = ($nu.temp-path | path join $"($id)_($name).ip")
		if not ($ip_path | path exists) {
			print $"No IP address found for ($name) VM. VM is running but unable to connect."
			return
		}

		let $ip = open --raw $ip_path | str trim
		if ($ip | is-empty) {
			print $"No IP address found for ($name) VM. VM is running but unable to connect."
		} else {
			print $"($name) VM IP: ($ip)"
		}
	}
}
