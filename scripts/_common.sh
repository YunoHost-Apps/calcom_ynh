#!/bin/bash

#=================================================
# COMMON VARIABLES AND CUSTOM HELPERS
#=================================================

# Add swap if needed
myynh_add_swap() {
	# Remove existing SWAP
	ynh_del_swap
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
		ynh_add_swap --size=$swap_needed_M
	fi
	# Recheck free RAM in G
	local ram_free_G=$(($(ynh_get_ram --free)/1024))
	if [ $ram_free_G -lt $ram_needed_G ]
	then
		# Remove existing SWAP
		ynh_del_swap
		# Terminate install/upgarde script
		ynh_die "There is no enough free memory on your system ($ram_needed_G GB are needed to build successfully $app). You need to either add RAM or manually add swap to your system."
	fi
}
