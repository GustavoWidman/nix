alias lsusb = cyme --lsusb
alias unmount = diskutil unmount
alias finder = /usr/bin/open

const tailscale_app = "/Applications/Tailscale.app/Contents/MacOS/Tailscale"

def --wrapped tailscale [...args] {
	if ($tailscale_app | path exists) {
		run-external $tailscale_app ...$args
	} else {
		^tailscale ...$args
	}
}

def --wrapped mount [source: string, directory: path, ...args] {
	diskutil mount -mountPoint $directory $source ...$args
}

def dnswipe [] {
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder
    sudo killall dnsproxy
}
