alias lsusb = cyme --lsusb
alias unmount = diskutil unmount
alias tailscale = /Applications/Tailscale.app/Contents/MacOS/Tailscale
alias finder = /usr/bin/open

def --wrapped mount [source: string, directory: path, ...args] {
	diskutil mount -mountPoint $directory $source ...$args
}

def dnswipe [] {
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder
    sudo killall dnsproxy
}
