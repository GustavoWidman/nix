export def main [--all (-a)] {
    let diskutil_output = (diskutil list | complete | get stdout)

    # Parse the diskutil output into structured data
    let parsed_disks = parse_diskutil_output $diskutil_output

    # Filter based on --all flag
    let filtered_disks = if $all {
        $parsed_disks
    } else {
        # Only show physical disks and mounted disk images, exclude synthesized
        $parsed_disks | where type == "physical"
    }

    # Format and display the output
    print (format_lsblk_output $filtered_disks)
}

def parse_diskutil_output [output: string] {
    let lines = ($output | lines)
    mut disks = []
    mut current_disk = {name: "", type: "", size: ""}
    mut current_partitions = []
    mut has_current_disk = false

    for line in $lines {
        if ($line | str contains "(") and ($line | str contains "):") {
            # This is a disk header line
            if $has_current_disk {
                # Save previous disk
                $disks = ($disks | append {
                    name: $current_disk.name
                    type: $current_disk.type
                    size: $current_disk.size
                    partitions: $current_partitions
                })
            }

            # Parse new disk header
            let disk_match = ($line | parse "/dev/{name} ({info}):")
            if ($disk_match | length) > 0 {
                let disk_info = $disk_match.0
                let info_parts = ($disk_info.info | split row ", ")

                $current_disk.name = $disk_info.name
                $current_disk.type = (if ($info_parts | any {|x| $x == "physical"}) { "physical" }
                          else if ($info_parts | any {|x| $x == "synthesized"}) { "synthesized" }
                          else if ($info_parts | any {|x| $x == "disk image"}) { "disk image" }
                          else { "unknown" })
				$current_disk.size = ""

                $current_partitions = []
                $has_current_disk = true
            }
        } else if ($line | str starts-with "   ") and ($line | str contains ":") {
            # This is a partition line
            let clean_line = ($line | str trim)
            if ($clean_line | str starts-with "#:") {
                # Skip header line
                continue
            }

            # Parse partition line format: "   1:             Apple_APFS Container disk3         994.7 GB   disk0s2"
            let parts = ($clean_line | split row -r '\s+') | reverse
            if ($parts | length) >= 5 {
                let partition_num = ($parts | last | str replace ":" "")
				let type_name = "part"
				let size = (($parts.2 | str replace "*" "" | str replace "+" "" | str replace ".0" "") + ($parts.1 | str substring 0..0))
                let identifier = $parts.0

                $current_partitions = ($current_partitions | append {
                    num: $partition_num
                    type: $type_name
                    size: $size
                    identifier: $identifier
                })

                # Update disk size from first partition if it's a scheme
                if $partition_num == "0" and ($current_disk.size == "") {
                    $current_disk = ($current_disk | upsert size $size)
                }
            }
        }
    }

    # Don't forget the last disk
    if $has_current_disk {
        $disks = ($disks | append {
            name: $current_disk.name
            type: $current_disk.type
            size: $current_disk.size
            partitions: $current_partitions
        })
    }

    return $disks
}

def format_lsblk_output [disks: list] {
    # Print header
	mut output = $"('NAME' | fill -a l -c ' ' -w 11) ('MAJ:MIN' | fill -a l -c ' ' -w 8) ('RM' | fill -a l -c ' ' -w 4)('SIZE' | fill -a r -c ' ' -w 6) ('RO' | fill -a l -c ' ' -w 2) ('TYPE' | fill -a l -c ' ' -w 4) ('MOUNTPOINTS' | fill -a l -c ' ' -w 12)"

	let disk_lines = ($disks | enumerate | par-each -k {|item|
		let idx = $item.index
		let disk = $item.item
		let disk_name = $disk.name
		let disk_size = ($disk.size | str replace " " "")
		let disk_type = (match $disk.type {
			"physical" => "disk"
			"disk image" => "loop"
			"synthesized" => "disk"
			_ => "disk"
		})

		# Create disk line
		let maj_min = get_maj_min $disk_name
		let disk_line = $"($disk_name | fill -a l -c ' ' -w 13) ($maj_min | fill -a l -c ' ' -w 7) 0 ($disk_size | fill -a r -c ' ' -w 7)  0 ($disk_type | fill -a l -c ' ' -w 5)"

		# Create partition lines
		let partition_lines = ($disk.partitions | where num != "0" | enumerate | par-each -k {|part_item|
			let partition = $part_item.item
			let part_name = $partition.identifier
			let part_size = ($partition.size | str replace " " "")
			let part_maj_min = get_maj_min $part_name
			let mount_point = get_mount_point $part_name
			let prefix = if ($part_item.index + 1) == ($disk.partitions | where num != "0" | length) { "└─" } else { "├─" }

			$"($prefix)($part_name | fill -a l -c ' ' -w 11) ($part_maj_min | fill -a l -c ' ' -w 7) 0 ($part_size | fill -a r -c ' ' -w 7)  0 part ($mount_point)"
		})

		{
			index: $idx
			lines: ([$disk_line] | append $partition_lines)
		}
	} | sort-by index | each {|item| $item.lines} | flatten)

	$output += ($disk_lines | str join "\n" | if ($disk_lines | length) > 0 { $"\n($in)" } else { "" })

	return $output
}

def get_maj_min [device: string] {
    # Extract disk number and partition number to create MAJ:MIN
    let matches = ($device | parse -r 'disk(\d+)(?:s(\d+))?')
    if ($matches | length) > 0 {
        let disk_num = $matches.0.capture0
        let part_num = if ($matches.0.capture1 | is-empty) { "0" } else { $matches.0.capture1 }
        return $"($disk_num):($part_num)"
    }
    return "0:0"
}

def get_mount_point [device: string] {
    # Try to get mount point using diskutil info
    let mount_info = (diskutil info $device | complete)
    if $mount_info.exit_code == 0 {
        let mount_lines = ($mount_info.stdout | lines | where {|line| $line | str contains "Mount Point:"})
        if ($mount_lines | length) > 0 {
            let mount_point = ($mount_lines.0 | str replace "Mount Point:" "" | str trim)
            if $mount_point != "Not applicable (no file system)" and $mount_point != "" {
                return $mount_point
            }
        }
    }
    return ""
}