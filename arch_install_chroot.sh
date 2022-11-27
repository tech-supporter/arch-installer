#!/usr/bin/bash
UEFI_enabled=${1}
root_password=${2}

clear
echo "Configuring Arch Linux..."
sleep 1

# set locale

echo "Setting locale..."
locale-gen

export LANG=en_US.UTF-8

echo "Setting hardware clock..."
hwclock --systohc --utc

pacman -Sy

# install boot loader

if [[ ${UEFI_enabled} ]] then
    echo "Installing UEFI boot loader..."
    bootctl install
else
    # install MBR boot loader syslinux
fi

systemctl enable NetworkManager.service
systemctl enable sshd.service

# set root password

echo "Setting root password..."
passwd << password_commands
${root_password}
${root_password}
password_commands
sleep 10
exit
