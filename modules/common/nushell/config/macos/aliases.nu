alias lsusb = cyme --lsusb
alias unmount = diskutil unmount
alias umount = diskutil unmount
alias tailscale = /Applications/Tailscale.app/Contents/MacOS/Tailscale

def --wrapped mount [source: string, directory: path, ...args] {
	diskutil mount -mountPoint $directory $source ...$args
}
