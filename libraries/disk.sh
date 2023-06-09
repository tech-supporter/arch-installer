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

    disk::partition "${drive}" "${uefi}"

    disk::make_boot_file_system "${drive}" "${uefi}"

    disk::make_volumes "${drive}" "${root_size}" "${swap_size}"

    disk::make_volume_file_systems "${drive}"

    disk::mount_file_systems "${drive}"

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

    if $uefi; then
        disk::partition_uefi "${drive}"
    else
        disk::partition_bios "${drive}"
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

    umount "/dev/${drive}"

    umount "/dev/systemvg/*"

# hard coding the removal of our own lvm to make re-installing work, won't remove other lvms
# wiping the drive and rebooting works but is a little too annoying for me
# would like to find a way to tell the linux kernel that it needs to rescan the drive after wiping
# maybe lvm2 needs to know?
lvremove "/dev/systemvg/rootlv" << EOF
y
EOF

lvremove "/dev/systemvg/swaplv" << EOF
y
EOF

lvremove "/dev/systemvg/homelv" << EOF
y
EOF

vgremove "systemvg" << EOF
y
EOF

pvremove "/dev/${drive}" << EOF
y
EOF

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

    disk::clear "${drive}"

gdisk "/dev/${drive}" << partition_commands
o
y
n
1
$(echo)
+1GiB
ef00
n
2
$(echo)
$(echo)
8e00
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
$(echo)
y
t
2
44
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

    partition=$(fdisk -l | awk '/^\/dev/{print $1}' | grep "${drive}" | grep "${partition_number}$")

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

    partition=$(disk::get_partition_by_number "${drive}" "1")

    echo "${partition}"
}

###################################################################################################
# gets the path to the drive's lvm partition, assumes index 2
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
function disk::get_lvm_partition()
{
    local drive="$1"
    local partition

    partition=$(disk::get_partition_by_number "${drive}" "2")

    echo "${partition}"
}

###################################################################################################
# creates the file system on the boot partition
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
function disk::make_boot_file_system()
{
    local drive="$1"
    local uefi="$2"

    local boot_partition

    boot_partition=$(disk::get_boot_partition "${drive}")

if $uefi; then
mkfs.fat -n BOOT -F32 "${boot_partition}" << mkfat
y
mkfat
else
mkfs.ext4 -L boot -O '^64bit' "${boot_partition}" << mkfs_cmds
y
mkfs_cmds
fi

}

###################################################################################################
# creates the main system physical volume, volume group, root, swap and home logical volumes
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
function disk::make_volumes()
{
    local drive="$1"
    local root_size="$2"
    local swap_size="$3"

    local lvm_partition

    lvm_partition=$(disk::get_lvm_partition "${drive}")

    pvcreate "${lvm_partition}"

    vgcreate "systemvg" "${lvm_partition}"

lvcreate -L "${root_size}G" -n "rootlv" "systemvg" << cmds
y
cmds

lvcreate -L "${swap_size}G" -n "swaplv" "systemvg" << cmds
y
cmds

lvcreate -l "+100%FREE" -n "homelv" "systemvg" << cmds
y
cmds
}

###################################################################################################
# creates the file systems and swap on the logical volumes
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
function disk::make_volume_file_systems()
{
mkfs.ext4 -L "root" "/dev/systemvg/rootlv" << cmds
y
cmds

mkfs.ext4 -L "home" "/dev/systemvg/homelv" << cmds
y
cmds

mkswap -L "swap" "/dev/systemvg/swaplv" << cmds
y
cmds

swapon -L "swap" "/dev/systemvg/swaplv" << cmds
y
cmds
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

    boot_partition=$(disk::get_boot_partition "${drive}")

    mount "/dev/systemvg/rootlv" "/mnt"
    mount "${boot_partition}" "/mnt/boot" --mkdir
    mount "/dev/systemvg/homelv" "/mnt/home" --mkdir
}
