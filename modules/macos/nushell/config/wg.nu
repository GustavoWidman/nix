export def "status" [] {
	ls /var/run/wireguard/
		| where ($it.name | str ends-with ".name")
		| get name
		| path basename
		| str replace '.name' ''
}

export def "camelsec" [environ: string, state: string] {
	let state = $state | str downcase | str trim
	let environ = $environ | str downcase | str trim

	if (($environ != "prod" and $environ != "stag") or ($state != "on" and $state != "off")) {
		print "Usage: vpn camelsec <prod|stag> <on|off>"
		return 1
	}

	let running_vpns = status

	if $state == "on" {
		if ($running_vpns | where $it == $"camelsec-($environ)" | is-empty) {
			sudo wg-quick up $"camelsec-($environ)"
		} else {
			print "VPN camelsec-($environ) is already running"
			return 0
		}
	} else {
		if ($running_vpns | where $it == $"camelsec-($environ)" | is-not-empty) {
			sudo wg-quick down $"camelsec-($environ)"
		} else {
			print "VPN camelsec-($environ) is already stopped"
			return 0
		}
	}
}


export def "vpn mullvad on" [] {
	# TODO
}