#!/bin/bash

#=================================================
# COMMON VARIABLES
#=================================================

nodejs_version=22

#=================================================
# PERSONAL HELPERS
#=================================================

# Add swap if needed
myynh_add_swap() {
	# Remove existing SWAP
		ynh_del_swap_fixed
	# Retrieve RAM needed in G
		local ram_needed_full=$(ynh_read_manifest "integration.ram.build")
		local ram_needed_value=${ram_needed_full::-1}
		local ram_needed_unit=${ram_needed_full: -1}
		if [ $ram_needed_unit = "M" ]
		then
			ram_needed_G=$(($ram_needed_value/1024))
		else
			ram_needed_G=$(($ram_needed_value))
		fi
	# Retrieve free RAM in G
		local ram_free_G=$(($(ynh_get_ram --free)/1024))
	# Check and add right amount of SWAP if needed
		local swap_needed_M=0
		if [ $ram_free_G -lt $ram_needed_G ]
		then
			swap_needed_M=$((($ram_needed_G-$ram_free_G)*1024))
		fi
		if [ $swap_needed_M -gt 0 ]
		then
			ynh_print_info "Adding $swap_needed_M Mb to swap..."
			ynh_add_swap_fixed --size=$swap_needed_M
		fi
	# Recheck free RAM in G
		local ram_free_G=$(($(ynh_get_ram --free)/1024))
		if [ $ram_free_G -lt $ram_needed_G ]
		then
			# Remove existing SWAP
				ynh_del_swap_fixed
			# Terminate install/upgarde script
				ynh_die "There is no enough free memory on your system ($ram_needed_G GB are needed to build successfully $app). You need to either add RAM or manually add swap to your system."
		fi
}

# Add swap
#
# usage: ynh_add_swap --size=SWAP in Mb
# | arg: -s, --size= - Amount of SWAP to add in Mb.
ynh_add_swap_fixed() {
	if systemd-detect-virt --container --quiet; then
		ynh_print_warn "You are inside a container/VM. swap will not be added, but that can cause troubles for the app $app. Please make sure you have enough RAM available."
		return
	fi

	# Declare an array to define the options of this helper.
	declare -Ar args_array=([s]=size=)
	local size
	# Manage arguments with getopts
	ynh_handle_getopts_args "$@"

	local swap_max_size=$((size * 1024))

	local free_space=$(df --output=avail / | sed 1d)
	# Because we don't want to fill the disk with a swap file, divide by 2 the available space.
	local usable_space=$((free_space / 2))

	SD_CARD_CAN_SWAP=${SD_CARD_CAN_SWAP:-0}

	# Swap on SD card only if it's is specified
	if ynh_is_main_device_a_sd_card && [ "$SD_CARD_CAN_SWAP" == "0" ]; then
		ynh_print_warn "The main mountpoint of your system '/' is on an SD card, swap will not be added to prevent some damage of this one, but that can cause troubles for the app $app. If you still want activate the swap, you can relaunch the command preceded by 'SD_CARD_CAN_SWAP=1'"
		return
	fi

	# Compare the available space with the size of the swap.
	# And set a acceptable size from the request
	if [ $usable_space -ge $swap_max_size ]; then
		local swap_size=$swap_max_size
	elif [ $usable_space -ge $((swap_max_size / 2)) ]; then
		local swap_size=$((swap_max_size / 2))
	elif [ $usable_space -ge $((swap_max_size / 3)) ]; then
		local swap_size=$((swap_max_size / 3))
	elif [ $usable_space -ge $((swap_max_size / 4)) ]; then
		local swap_size=$((swap_max_size / 4))
	else
		echo "Not enough space left for a swap file" >&2
		local swap_size=0
	fi

	# If there's enough space for a swap, and no existing swap here
	if [ $swap_size -ne 0 ] && [ ! -e "/swap_$app" ]; then
		# Create file
		truncate -s 0 "/swap_$app"

		# try to set the No_COW attribute on the swapfile with chattr (depending of the filesystem type)
		if grep -qs ' / .*btrfs' /proc/mounts; then
			chattr +C "/swap_$app"
		fi

		# Preallocate space for the swap file, fallocate may sometime not be used, use dd instead in this case
		if ! fallocate -l ${swap_size}K "/swap_$app"; then
			dd if=/dev/zero of="/swap_$app" bs=1024 count=${swap_size}
		fi
		chmod 0600 "/swap_$app"
		# Create the swap
		mkswap "/swap_$app"
		# And activate it
		swapon "/swap_$app"
		# Then add an entry in fstab to load this swap at each boot.
		echo -e "/swap_$app swap swap defaults 0 0 #Swap added by $app" >> /etc/fstab
	fi
}

ynh_del_swap_fixed() {
	# If there a swap at this place
	if [ -e "/swap_$app" ]; then
		# Clean the fstab
		sed -i "/#Swap added by $app/d" /etc/fstab
		# Desactive the swap file if active
		if grep -qs "/swap_$app" /proc/swaps; then
			swapoff "/swap_$app"
		fi
		# And remove it
		rm "/swap_$app"
	fi
}



#=================================================
# EXPERIMENTAL HELPERS
#=================================================

#=================================================
# FUTURE OFFICIAL HELPERS
#=================================================
