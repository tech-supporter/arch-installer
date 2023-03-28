#!/usr/bin/bash

desktop_environment::install_plasma()
{
    root_mount="$1"

    echo "Installing Plasma Desktop enviorment with X11 and SDDM..."

pacstrap -i "${root_mount}" "mesa" "xorg" "plasma" "sddm" << syslinux_install_commands
$(echo)
y
y
y
syslinux_install_commands

    arch-chroot "${root_mount}" "systemctl" "enable" "sddm.service"
}
