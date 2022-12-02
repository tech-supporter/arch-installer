#!/usr/bin/bash

install_driver_nvidia()
{
    # read in parameters
    local is_uefi=$1
    local is_intel=$2

    # install base linux
    echo "Installing nVidia driver packages..."
pacstrap -i /mnt nvidia-dkms nvidia-utils opencl-nvidia libglvnd lib32-libglvnd lib32-nvidia-utils lib32-opencl-nvidia nvidia-settings << install_commands
$(echo)
$(echo)
y
y
install_commands

    # create the dynamic kernal module support hook
    local hooks_path="/mnt/etc/pacman.d/hooks/"
    echo "Creating DKMS hook..."
    mkdir -p ${hooks_path}
    echo '
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=nvidia

[Action]
Depends=mkinitcpio
When=PostTransaction
Exec=/usr/bin/mkinitcpio -P
' > "${hooks_path}nvidia"

    # update kernal modules
    echo "Updating kernal modules list..."
    sed -i 's/MODULES=(/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm/g' "/mnt/etc/mkinitcpio.conf"

    echo "Updating boot loader..."

    # disable Indirect Branch Tracking when using intel based CPUs
    # on linux kernal 5.18 and higher, it might be required, at least until the issue is solved
    # https://wiki.archlinux.org/title/NVIDIA#Installation
    local boot_text="nvidia-drm.modeset=1"
    if $is_intel; then
        boot_text="${boot_text} ibt=off"
    fi

    # update the correct boot loader based on uefi status
    local boot_path="/mnt/boot/syslinux/syslinux.cfg"
    if $is_uefi; then
        boot_path="/mnt/boot/loader/entries/arch.conf"
    fi

    # update the configuration of the boot loader
    sed -i "s/rw/rw ${boot_text}/" ${boot_path}

    echo "Finished installing nVidia drivers."
}
