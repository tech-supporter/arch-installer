#!/usr/bin/bash

###################################################################################################
# Handles finding system related information
###################################################################################################

###################################################################################################
# Checks if the system has booted in uefi mode
#
# Globals:
#   N/A
#
# Arguments:
#   N/A
#
# Output:
#   return 0 for UEFI mode enabled, return 1 for UEFI mode disabled
#
# Source:
#   N/A
###################################################################################################
function system::uefi()
{
    local uefi_vars

    uefi_vars=$(efivar -l 2>&1)

    if ! [[ ${uefi_vars:0:13} = "efivar: error" ]]; then
        return 0
    else
        return 1
    fi
}

###################################################################################################
# get the CPU vendor, intel/amd/unknown
#
# Globals:
#   N/A
#
# Arguments:
#   N/A
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function system::cpu_vendor()
{
    local intel
    local amd
    local vendor

    intel=$(cat /proc/cpuinfo | grep 'vendor' | grep 'Intel' | uniq | wc -l)
    amd=$(cat /proc/cpuinfo | grep 'vendor' | grep 'AMD' | uniq | wc -l)

    if [[ "${intel}" == "1" ]]; then
        vendor="intel"
    elif [[ "${amd}" == "1" ]]; then
        vendor="amd"
    else
        vendor="unknown"
    fi

    echo "${vendor}"
}

###################################################################################################
# Prompt the user to enter a swap partition size in gibibytes
#
# Globals:
#   N/A
#
# Arguments:
#   N/A
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function system::memory_size()
{
    local memory_size
    local memory_raw_size

    memory_raw_size=$(awk '/^Mem/{print $2}' <(free -g))
    memory_size=$((${memory_raw_size}+1))

    echo "${memory_size}"
}

###################################################################################################
# syncs pacman repositories
#
# Globals:
#   N/A
#
# Arguments:
#   N/A
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function system::sync_repositories()
{
    pacman -Sy
}

###################################################################################################
# syncs and updates pacman repositories
#
# Globals:
#   N/A
#
# Arguments:
#   N/A
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function system::update_repositories()
{
    pacman -Syu
}

###################################################################################################
# enables access to the 32-bit pacman repository "multilib" by changing the pacman configuration
#
# Globals:
#   N/A
#
# Arguments:
#   N/A
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function system::enable_multilib()
{
    local multilib_line
    local insert_line

    multilib_line=$(grep -n '#\[multilib\]' "/etc/pacman.conf" | cut -d ':' -f1)

    if ! [[ -z "${multilib_line}" ]]; then
        include_line=$((multilib_line + 1))
        sed -i "${multilib_line}c\[multilib\]" "/etc/pacman.conf"
        sed -i "${include_line}cInclude = /etc/pacman.d/mirrorlist" "/etc/pacman.conf"
    fi
}
