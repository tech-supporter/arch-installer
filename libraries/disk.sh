#!/usr/bin/bash

###################################################################################################
# Handles creating partitions and file systems on a drive
###################################################################################################

###################################################################################################
# partitions a drive with either uefi or bios mode boot partition
# creates files systems
# mounts file systems
#
# Globals:
#   N/A
#
# Arguments:
#   drive name
#   UEFI mode true/false
#   root partition size in GiB
#   swap partition size in GiB
#
# Output:
#   return 0 for success, 1 for failure
#
# Source:
#   N/A
#
# TODO: add more validation
###################################################################################################
function disk::format()
{
    local drive="$1"
    local uefi="$2"
    local root_size="$3"
    local swap_size="$4"

    local fdisk_output

    fdisk_output=$(fdisk -l "/dev/${drive}" 2> grep 'cannot open')
    if [[ -z ${fdisk_output} ]]; then
        return 1
    fi

    disk::partition "${drive}" "${uefi}" "${root_size}" "${swap_size}"

    disk::make_file_systems

    disk::mount_file_systems

    return 0
}

###################################################################################################
# partitions a drive with either uefi or bios mode boot partition
#
# Globals:
#   N/A
#
# Arguments:
#   drive name
#   UEFI mode true/false
#   root partition size in GiB
#   swap partition size in GiB
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function disk::partition()
{
    local drive="$1"
    local uefi="$2"
    local root_size="$3"
    local swap_size="$4"

    if $uefi; then
        disk::partition_uefi "${drive}" "${root_size}" "${swap_size}"
    else
        disk::partition_bios "${drive}" "${root_size}" "${swap_size}"
    fi
}

###################################################################################################
# clears a drive of previous partitions which can mess up the scripted partitioning commands
#
# Globals:
#   N/A
#
# Arguments:
#   drive name
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function disk::clear()
{
    local drive="$1"

    # unmount existing partitions and turn off swap spaces
    swapoff -a
    umount -R -f "/mnt"

    # remove file systems on the drive
    wipefs -a -f "/dev/${drive}"

gdisk "/dev/${drive}" << clear_commands
$(echo)
x
z
y
y
clear_commands
}

###################################################################################################
# partitions a drive with a UEFI based boot partition
#
# Globals:
#   N/A
#
# Arguments:
#   drive name
#   root partition size in GiB
#   swap partition size in GiB
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function disk::partition_uefi()
{
    local drive="$1"
    local root_size="$2"
    local swap_size="$3"

    disk::clear "${drive}"

gdisk "/dev/${drive}" << partition_commands
o
y
n
1
$(echo)
+1GiB
EF00
n
2
$(echo)
+${swap_size}GiB
8200
n
3
$(echo)
+${root_size}GiB
8300
n
4
$(echo)
$(echo)
8300
w
y
q
partition_commands
}

###################################################################################################
# partitions a drive with a standard BIOS based boot partition
#
# Globals:
#   N/A
#
# Arguments:
#   drive name
#   root partition size in GiB
#   swap partition size in GiB
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function disk::partition_bios()
{
    local drive="$1"
    local root_size="$2"
    local swap_size="$3"

    disk::clear "${drive}"

    # In Bios Mode
    # o=made bios signature which is also auto made is none found when opening this program, y to accept
    # n=new, p=partition, number=partition identifier (1-4), empty line to accept default start sector, +#Gib=size or empty to accept default size, y=confirms remove existing signature if pressent or if not no ill effects happen
fdisk "/dev/${drive}" << partition_commands
o
y
n
p
1
$(echo)
+1GiB
y
n
p
2
$(echo)
+${swap_size}GiB
y
n
p
3
$(echo)
+${root_size}GiB
y
n
p
4
$(echo)
$(echo)
t
2
82
w
y
q
partition_commands
}

###################################################################################################
# gets the path to the drive's n'th partition, starting at index 1
# the index is taken from the fdisk list command
#
# Globals:
#   N/A
#
# Arguments:
#   drive name
#   parition index number, starting at 1
#
# Output:
#   string path to partition, /dev/sdxN
#
# Source:
#   N/A
###################################################################################################
function disk::get_partition_by_number()
{
    local drive="$1"
    local partition_number="$2"
    local partition

    partition=$(fdisk -l | awk '/^\/dev/{print $1}' | grep ${drive} | grep "${partition_number}$")

    echo "${partition}"
}

###################################################################################################
# gets the path to the drive's boot partition, assumes index 1
#
# Globals:
#   N/A
#
# Arguments:
#   drive name
#
# Output:
#   string path to partition, /dev/sdx1
#
# Source:
#   N/A
###################################################################################################
function disk::get_boot_partition()
{
    local drive="$1"
    local partition

    partition=$(disk::get_partition_by_number "1")

    echo "${partition}"
}

###################################################################################################
# gets the path to the drive's swap partition, assumes index 2
#
# Globals:
#   N/A
#
# Arguments:
#   drive name
#
# Output:
#   string path to partition, /dev/sdx2
#
# Source:
#   N/A
###################################################################################################
function disk::get_swap_partition()
{
    local drive="$1"
    local partition

    partition=$(disk::get_partition_by_number "2")

    echo "${partition}"
}

###################################################################################################
# gets the path to the drive's root partition, assumes index 3
#
# Globals:
#   N/A
#
# Arguments:
#   drive name
#
# Output:
#   string path to partition, /dev/sdx3
#
# Source:
#   N/A
###################################################################################################
function disk::get_root_partition()
{
    local drive="$1"
    local partition

    partition=$(disk::get_partition_by_number "3")

    echo "${partition}"
}

###################################################################################################
# gets the path to the drive's home partition, assumes index 4
#
# Globals:
#   N/A
#
# Arguments:
#   drive name
#
# Output:
#   string path to partition, /dev/sdx4
#
# Source:
#   N/A
###################################################################################################
function disk::get_home_partition()
{
    local drive="$1"
    local partition

    partition=$(disk::get_partition_by_number "4")

    echo "${partition}"
}

###################################################################################################
# creates the file systems on the partitions and creates/enables swap
#
# Globals:
#   N/A
#
# Arguments:
#   drive name
#
# Output:
#   string path to partition, /dev/sdx4
#
# Source:
#   N/A
###################################################################################################
function disk::make_file_systems()
{
    local drive="$1"
    local uefi="$2"

    local boot_partition
    local swap_partition
    local root_partition
    local home_partition

    boot_partition=$(disk::get_boot_partition "${drive}")
    swap_partition=$(disk::get_swap_partition "${drive}")
    root_partition=$(disk::get_root_partition "${drive}")
    home_partition=$(disk::get_home_partition "${drive}")

if $uefi; then
mkfs.fat -F32 "${boot_partition}" << mkfat
y
mkfat
else
mkfs.ext4 -L boot -O '^64bit' "${boot_partition}" << mkfs_cmds
y
mkfs_cmds
fi

mkswap "${swap_partition}"
swapon "${swap_partition}"

mkfs.ext4 "${root_partition}" << mkfs_cmds
y
mkfs_cmds

mkfs.ext4 "${home_partition}" << mkfs_cmds
y
mkfs_cmds

# create the directories right away
mount "${root_partition}" "/mnt"
mkdir "/mnt/boot"
mkdir "/mnt/home"
umount "/mnt"

}

###################################################################################################
# mounts the file systems to /mnt
#
# Globals:
#   N/A
#
# Arguments:
#   drive name
#
# Output:
#   string path to partition, /dev/sdx4
#
# Source:
#   N/A
###################################################################################################
function disk::mount_file_systems()
{
    local drive="$1"

    local boot_partition
    local swap_partition
    local root_partition
    local home_partition

    boot_partition=$(disk::get_boot_partition)
    swap_partition=$(disk::get_swap_partition)
    root_partition=$(disk::get_root_partition)
    home_partition=$(disk::get_home_partition)

    mount "${root_partition}" "/mnt"
    mount "${boot_partition}" "/mnt/boot"
    mount "${home_partition}" "/mnt/home"
}
