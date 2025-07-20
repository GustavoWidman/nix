const cache_file = ($nu.temp-path | path join "nushell_cache.nuon")
const null_cache_records = {
	brew: null,
	true_home: null,
	hostname: null,
}

export def --env get_cache [] {
	if "CACHE_RECORDS" in $env and $env.CACHE_RECORDS != $null_cache_records {
		return $env.CACHE_RECORDS
	}

	def empty_cache [] {
		$null_cache_records | save -f $cache_file
		$null_cache_records
	}

	if ($cache_file | path exists) {
		try {
			let cache = open $cache_file
			$env.CACHE_RECORDS = $cache
			$cache
		} catch {
			empty_cache
		}
	} else {
		empty_cache
	}
}

def --env save_to_cache [key: string, value: any] {
	let cache_records = get_cache | upsert $key $value

	$cache_records | save -f $cache_file
	$env.CACHE_RECORDS = $cache_records
}


# $HOME that works for root and non-root, referring to the same place (get the $HOME of the first non-root user) uses awk from the "users" command
export def --env true_home [] {
	let cache = get_cache

	if $cache.true_home != null {
		$cache.true_home
	} else {
		let true_home = if $env.OS == "Darwin" {
			# may god have mercy on my soul what the fuck is this :sob:
			dscl . -list /Users UniqueID
				| ^awk '$2 >= 501 { print $1 }'
				| ^head -n 1
				| ^dscl . -read /Users/($in) NFSHomeDirectory
				| ^awk '{ print $2 }'
				| str trim
		} else {
			^grep -m1 '/home/' /etc/passwd
				| ^cut -d: -f6
				| str trim
		}

		save_to_cache true_home $true_home

		$true_home
	}
}

# Cache Homebrew environment variables and only update weekly
export def --env brew_env [brew_cache_max_age_days: int] {
	let cache =  get_cache

	if (
		$cache.brew != null
	) and (
		$cache.brew.modified > (date now) - ($brew_cache_max_age_days * 24 * 60 * 60sec)
	) {
		$cache.brew.env
	} else {
		let new_env = (/opt/homebrew/bin/brew shellenv csh
			| lines
			| parse --regex 'setenv (\w+) "?(.+)"?;'
			| transpose -r
			| into record)

		save_to_cache brew {
			env: $new_env,
			modified: (date now)
		}

		$new_env
	}
}

export def --env get_hostname [] {
	let cache  = get_cache

	if $cache.hostname != null {
		$cache.hostname
	} else {
		let hostname = if 'COMPUTERNAME' in $env {
			$env.COMPUTERNAME
		} else if 'HOSTNAME' in $env {
			$env.HOSTNAME
		} else {
			if $env.OS == "Darwin" {
				(do { hostname -s })
			} else {
				(do { /bin/cat /etc/hostname })
			}
		}

		save_to_cache hostname $hostname

		$hostname
	}
}