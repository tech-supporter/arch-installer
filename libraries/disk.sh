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
    local root_mount="$2"
    local wipe_drive="$3"
    local uefi="$4"
    local root_size="$5"
    local swap_size="$6"
    local encryption_password="$7"

    local fdisk_output

    fdisk_output=$(fdisk -l "/dev/${drive}" 2> grep 'cannot open')
    if [[ -z ${fdisk_output} ]]; then
        return 1
    fi

    disk::partition "${drive}" "${wipe_drive}" "${uefi}"

    disk::make_boot_file_system "${drive}" "${uefi}"

    disk::make_volumes "${drive}" "${root_size}" "${swap_size}"

    if [[ "${encryption_password}" == "" ]]; then
        disk::make_unencrypted_volume_file_systems "${drive}" "${root_mount}"
    else
        disk::make_encrypted_file_system_part_1 "${drive}" "${root_mount}" "${encryption_password}"
    fi

    return 0
}

###################################################################################################
# partitions a drive with either uefi or mbr boot partition
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
    local wipe_drive="$2"
    local uefi="$3"

    disk::clear "${drive}" "${wipe_drive}"

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
    local wipe_drive="$2"

    # unmount existing partitions and turn off swap spaces
    swapoff -a

    umount "/dev/${drive}"

    umount "/mnt/boot"
    umount "/mnt/home"
    umount "/mnt"

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

    # wipe entire drive with random data if needed
    if $wipe_drive; then
        disk::wipe "${drive}"
    fi

}

###################################################################################################
# Wipes the drive with random data by writing encrypted zeros to it
# Using encryption here to leverage the speed of the hardware accelerated encryption to generate
#   random data.
# Pulling directly from /dev/random would take much longer as it would hang while generating more
#   randomness.
# /dev/urandom would work but it is less "random" once it runs out of entropy.
# The encryption leaves behind meta data so we need to wipe that afterwards.
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
function disk::wipe()
{
    local drive="$1"
    local password

    # get random password
    password=$(security::generate_password "64")

    # create full disk encryption, -q to remove the YES confirm and password verification
cryptsetup -q "luksFormat" "/dev/${drive}" --type "luks2" << EOF
${password}
EOF

cryptsetup "open" "/dev/${drive}" "encrypted_disk" << EOF
${password}
EOF

    # wipe drive with 0s encrypted to make them random data
    dd "if=/dev/zero" "of=/dev/mapper/encrypted_disk" "bs=1M" "status=progress"

    # remove encrypted device
    cryptsetup "remove" "encrypted_disk"

    # write over the luks meta data left at the start of the disk
    dd "if=/dev/urandom" "of=/dev/${drive}" "bs=1M" "count=1" "status=progress"
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
#   size of root partition
#   size of swap partition
#
# Output:
#   N/A
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

    # would be really nice if I could tell it to wipe all signatures with a parameter instead of accepting prompts with 'y'
lvcreate -L "${root_size}G" -n "rootlv" "systemvg" << EOF
y
y
y
y
EOF

lvcreate -L "${swap_size}G" -n "swaplv" "systemvg" << EOF
y
y
y
y
EOF

lvcreate -l "+100%FREE" -n "homelv" "systemvg" << EOF
y
y
y
y
EOF
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
function disk::make_unencrypted_volume_file_systems()
{
    local drive="$1"
    local root_mount="$2"

    local boot_partition

    boot_partition=$(disk::get_boot_partition "${drive}")

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

    mount "/dev/systemvg/rootlv" "${root_mount}"
    mount "${boot_partition}" "${root_mount}/boot" --mkdir
    mount "/dev/systemvg/homelv" "${root_mount}/home" --mkdir

}

###################################################################################################
# creates the root/boot file systems and mounts them
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
function disk::make_encrypted_file_system_part_1()
{
    local drive="$1"
    local root_mount="$2"
    local encryption_password="$3"

    local boot_partition

    boot_partition=$(disk::get_boot_partition "${drive}")

    # create full disk encryption, -q to remove the YES confirm and password verification
cryptsetup -q "luksFormat" "/dev/systemvg/rootlv" --type "luks2" << EOF
${encryption_password}
EOF

cryptsetup "open" "/dev/systemvg/rootlv" "root" << EOF
${encryption_password}
EOF
    # create root file system
mkfs.ext4 -L "root" "/dev/mapper/root" << EOF
y
EOF

    # mount root
    mount "/dev/mapper/root" "${root_mount}"

    # mount boot onto root
    mount "${boot_partition}" "${root_mount}/boot" --mkdir
}

###################################################################################################
# creates the home file systems and sets up swap
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
function disk::make_encrypted_file_system_part_2()
{
    local root_mount="$1"
    local encryption_password="$2"

    # add linux parameter to grub config to set root volume
    boot::add_linux_parameters "${root_mount}" "cryptdevice=UUID=$(blkid -s "UUID" -o "value" "/dev/systemvg/rootlv"):root root=/dev/mapper/root"

    # generate key file for home
    mkdir -m "700" "${root_mount}/etc/luks-keys"
    dd "if=/dev/random" "of=${root_mount}/etc/luks-keys/home.key" "bs=1" "count=256" "status=progress"

    # create luks encryption for home
cryptsetup -q "luksFormat" "/dev/systemvg/homelv" "${root_mount}/etc/luks-keys/home.key" --type "luks2" << EOF
YES
EOF

    # open / map home lv
    cryptsetup -d "${root_mount}/etc/luks-keys/home.key" "open" "/dev/systemvg/homelv" "home"

    # make home file system
mkfs.ext4 -L "home" "/dev/mapper/home" << EOF
y
EOF

    # mount home directory
    mount "/dev/mapper/home" "${root_mount}/home" --mkdir

    # edit crypttab
    echo "swap    /dev/systemvg/swaplv    /dev/urandom     swap,cipher=aes-xts-plain64,size=256" >> "${root_mount}/etc/crypttab"
    echo "home    /dev/systemvg/homelv    /etc/luks-keys/home.key   luks" >> "${root_mount}/etc/crypttab"

    # edit fstab
    echo "/dev/mapper/swap    none    swap    sw          0   0" >> "${root_mount}/etc/fstab"
    echo "/dev/mapper/home    /home   ext4    defaults    0   2" >> "${root_mount}/etc/fstab"
}
