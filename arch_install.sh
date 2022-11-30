#!/usr/bin/bash

# startup
clear
echo "Installing arch linux..."
pacman -Sy

# check if we're in UEFI mode
UEFI_Vars=$(efivar -l 2>&1)
if ! [[ ${UEFI_Vars:0:13} = "efivar: error" ]]; then
    UEFI_enabled=true
    echo "UEFI mode enabled."
else
    read -p "Warning: UEFI mode is not enabled. Reboot for bios menu? (Y/n): " confirm
    if [ -z ${confirm} ] || [ ${confirm} = 'y' ]; then
        reboot
    else
        UEFI_enabled=false
        echo "Continuing without UEFI mode."
    fi
fi

# choose cpu architecture/band
architecture=''
while [[ ${architecture} != i* ]] && [[ ${architecture} != a* ]]; do
    read -p "Choose CPU architecture/brand, (intel/amd): " typed
    if [[ ${typed} == i* ]]; then
        architecture="intel"
    elif [[ ${typed} == a* ]]; then
        architecture="amd"
    else
        echo "Invalid CPU architecture/brand: ${typed}"
    fi
done
echo "Using ${architecture} CPU architecture/brand"

# choose computer name
pretty_computer_name=''
while [ -z ${pretty_computer_name} ]; do
    read -p "Choose computer name: " pretty_computer_name
    if [[ -z ${pretty_computer_name} ]]; then
        echo "Invalid computer name."
    fi
done

computer_name=$(echo ${pretty_computer_name} | tr ' ' '-' | tr -dc '[:alnum:]-')
echo "Computer name: "${pretty_computer_name}
echo "Internal host name: "${computer_name}

# choose root password
read -s -p "Choose root password: " root_password
printf "%${#root_password}s\n" | tr ' ' '*'

# pick swap size
mem_size_raw=$(awk '/^Mem/{print $2}' <(free -g))
default_swap_size=$((${mem_size_raw}+1))
read -p "Default swap size = ram size: ${default_swap_size}GiB. Use default? (Y/n): " confirm
if [ -z ${confirm} ] || [ ${confirm} = 'y' ]; then
    echo "Using default swap size."
    swap_size=$default_swap_size
else
    choose_swap_size=0
    while [ ${choose_swap_size} == 0 ]; do
        re='^[0-9]+$'
        read -p "Choose swap size in GiB." typed
        if ! [[ ${typed} =~ ${re} ]]; then
            echo "Size must be a number"
        else
            choose_swap_size=${typed}
        fi
    done
    swap_size=${choose_swap_size}
    echo "Using choosen swap size."
fi
echo "Swap size is: ${swap_size}GiB"

# pick root partition size
default_root_size=64
read -p "Default root partition size: ${default_root_size}GiB. Use default? (Y/n): " confirm
if [ -z ${confirm} ] || [ ${confirm} = 'y' ]; then
    echo "Using default root partition size."
    root_size=${default_root_size}
else
    echo "Choose root partition size in GiB."
    choose_root_size=0
    while [ ${choose_root_size} == 0 ]; do
        re='^[0-9]+$'
        read typed
        if ! [[ ${typed} =~ ${re} ]]; then
            echo "Size must be a number"
        else
            choose_root_size=${typed}
        fi
    done
    root_size=${choose_root_size}
    echo "Using choosen swap size."
fi
echo "Root Partition size is: ${root_size}GiB"

# choose primary drive
confirm='n'
while ! [ ${confirm} = 'y' ]; do
    clear
    lsblk
    fdisk_output=''
    while [[ -z ${fdisk_output} ]]; do
        read -p "Choose primary drive to use. Note drive will be cleared: " primary_drive
        fdisk_output=$(fdisk -l "/dev/${primary_drive}" 2> grep 'cannot open')
        if [[ -z ${fdisk_output} ]]; then
            echo "Cannot find drive: ${primary_drive}"
        fi
    done

    read -p "Please confirm this is the correct drive: ${primary_drive} (y/N): " confirm
done

# unmount existing partitions and turn off swap spaces
swapoff -a
umount -R -f /mnt

# remove file systems on the drive
wipefs -a ${primary_drive}

# clear primary drive partitions
echo "Clearing out primary drive: ${primary_drive}.."
gdisk "/dev/${primary_drive}" << clear_commands

x
z
y
y
clear_commands

# create new partitions
if $UEFI_enabled; then
gdisk /dev/$primary_drive << partition_commands
o
y
n
1

+1GiB
EF00
n
2

+${swap_size}GiB
8200
n
3

+${root_size}GiB
8300
n
4


8300
w
y
q
partition_commands
else
fdisk /dev/$primary_drive << partition_commands
o
y
n
p
1

+1GiB
y
n
p
2

+${swap_size}GiB
y
n
p
3

+${root_size}GiB
y
n
p
4


t
2
82
w
y
q
partition_commands
fi

boot_part=$(fdisk -l | awk '/^\/dev/{print $1}' | grep ${primary_drive} | grep 1$)
swap_part=$(fdisk -l | awk '/^\/dev/{print $1}' | grep ${primary_drive} | grep 2$)
root_part=$(fdisk -l | awk '/^\/dev/{print $1}' | grep ${primary_drive} | grep 3$)
home_part=$(fdisk -l | awk '/^\/dev/{print $1}' | grep ${primary_drive} | grep 4$)

# create and mount directories/file systems
echo "Making file systems..."
if $UEFI_enabled; then
mkfs.fat -F32 ${boot_part} << mkfat
y
mkfat
else
mkfs.ext4 -L boot -O '^64bit' ${boot_part} << mkfs_cmds
y
mkfs_cmds
fi

mkswap ${swap_part}
swapon ${swap_part}

mkfs.ext4 ${root_part} << mkfs_cmds
y
mkfs_cmds

mkfs.ext4 ${home_part} << mkfs_cmds
y
mkfs_cmds

mount ${root_part} /mnt
mkdir /mnt/boot
mount ${boot_part} /mnt/boot
mkdir /mnt/home
mount ${home_part} /mnt/home
lsblk

# install base linux
echo "Installing base linux..."
pacstrap -i /mnt base base-devel linux linux-headers linux-firmware vim bash-completion networkmanager ${architecture}-ucode openssh git << base_install_commands




y
y
base_install_commands

# generate fstab file
echo "Creating fstab file..."
genfstab -U -p /mnt >> /mnt/etc/fstab

# set locale
echo "Setting locale..."
echo "en_US.UTF-8 UTF-8" > /mnt/etc/locale.gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf

# setup hostname
echo "Configuring host name..."
echo ${computer_name} > /mnt/etc/hostname

# create host file
echo "Creating hosts file..."
echo "127.0.0.1    localhost" > /mnt/etc/hosts
echo "::1          localhost" >> /mnt/etc/hosts
echo "127.0.1.1    "${computer_name} >> /mnt/etc/hosts

# create machine-info
echo "Creating machine-info file..."
echo "PRETTY_HOSTNAME=\"${pretty_computer_name}\"" > /mnt/etc/machine-info
echo "ICON_NAME=computer" >> /mnt/etc/machine-info
echo "CHASSIS=desktop" >> /mnt/etc/machine-info
echo "DEPLOYMENT=production" >> /mnt/etc/machine-info
echo "Location=\"Server Room\"" >> /mnt/etc/machine-info

# enable multilib
echo "Enabling multilib..."
echo "[multilib]" >> /mnt/etc/pacman.conf
echo "Include = /etc/pacman.d/mirrorlist" >> /mnt/etc/pacman.conf

# edit sudors files
echo "Editing sudoer's file..."
echo "%wheel ALL=(ALL:ALL) ALL" >> /mnt/etc/sudoers
echo "Defaults rootpw" >> /mnt/etc/sudoers

# chroot into and configure new install
arch-chroot /mnt 'locale-gen'
arch-chroot /mnt 'ln' '-s' '/usr/share/zoneinfo/America/Chicago' '/etc/localtime'
arch-chroot /mnt 'hwclock' '--systohc' '--utc'
arch-chroot /mnt 'pacman' '-Sy'
arch-chroot /mnt 'systemctl' 'enable' 'NetworkManager.service'
arch-chroot /mnt 'systemctl' 'enable' 'sshd.service'
arch-chroot /mnt 'passwd' << chroot_commands
${root_password}
${root_password}
chroot_commands

# install/configure correct boot loader
if $UEFI_enabled; then
    arch-chroot /mnt 'bootctl' 'install'
    # make UEFI boot loader file
    mkdir -p /mnt/boot/loader/entries
    echo "title ${computer_name}" > /mnt/boot/loader/entries/arch.conf
    echo "linux /vmlinuz-linux" >> /mnt/boot/loader/entries/arch.conf
    echo "initrd /${architecture}-ucode.img" >> /mnt/boot/loader/entries/arch.conf
    echo "initrd /initramfs-linux.img" >> /mnt/boot/loader/entries/arch.conf
    echo "options root=PARTUUID=$(blkid -s PARTUUID -o value ${root_part}) rw" >> /mnt/boot/loader/entries/arch.conf
else
pacstrap -i /mnt syslinux << syslinux_install_commands

y
syslinux_install_commands
    # install syslinux MBR
    syslinux-install_update -i -a -m -c /mnt

    root_part_uuid=$(blkid -s PARTUUID -o value ${root_part})

    # configure boot loader entry
    sed -i "s.root=${root_part}.root=PARTUUID=${root_part_uuid}." /mnt/boot/syslinux/syslinux.cfg
    sed -i "55 i \ \ \ \ INITRD ../${architecture}-ucode.img" /mnt/boot/syslinux/syslinux.cfg
    sed -i "62 i \ \ \ \ INITRD ../${architecture}-ucode.img" /mnt/boot/syslinux/syslinux.cfg
fi

echo "Base installation complete!"
shutdown_count=30
echo "Shutting down in ${shutdown_count} seconds: Remove USB boot drive before starting computer back up"
echo "Press the Enter Key to shutdown now."
while [[ ${shutdown_count} > 0 ]]; do
    echo ${shutdown_count}
    read -t 1 -n 1 input
    if [[ $? == 0 ]]; then
        ((shutdown_count=0))
    fi
    ((shutdown_count=shutdown_count-1))
done
shutdown now
