const cache_file = "/tmp/nushell_cache.nuon"
const null_cache_records = {
	true_home: null,
	hostname: null,
	tempdir: null
}

export def --env get_cache [] {
	if "CACHE_RECORDS" in $env and $env.CACHE_RECORDS != $null_cache_records {
		return $env.CACHE_RECORDS
	}

	def empty_cache [] {
		$null_cache_records | save -f $cache_file
		$null_cache_records
	}

	match ($cache_file | path exists) {
		true => {
    		try {
    			let cache = open $cache_file
    			$env.CACHE_RECORDS = $cache
    			$cache
    		} catch {
    			empty_cache
    		}
		},
		false => { empty_cache }
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

	match ($cache.true_home == null) {
		true => {
    		let true_home = match ($env.OS == "Darwin") {
    			# may god have mercy on my soul what the fuck is this :sob:
    			true => {
     			dscl . -list /Users UniqueID
        				| ^awk '$2 >= 501 { print $1 }'
        				| ^head -n 1
        				| ^dscl . -read /Users/($in) NFSHomeDirectory
        				| ^awk '{ print $2 }'
        				| str trim
    			},
    			false => {
     			^grep '/home/' /etc/passwd
        				| each {|str| $str | ^cut -d: -f6 | str trim}
        				| where {|str| not ($str =~ "build")}
        				| first
    			}
            };

 			save_to_cache true_home $true_home

 			$true_home
        },
	    _ => $cache.true_home
    };
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
			match ($env.OS == "Darwin") {
				true => (do { hostname -s }),
				false => (do { cat /etc/hostname })
			}
		}

		save_to_cache hostname $hostname

		$hostname
	}
}

export def --env get_tempdir [] {
    let cache = get_cache

    if $cache.tempdir != null {
        $cache.tempdir
    } else {
        let tempdir = match ($env.OS == "Darwin") {
            true => (getconf DARWIN_USER_TEMP_DIR),
            false => "/tmp"
        }

        save_to_cache tempdir $tempdir

        $tempdir
    }
}
