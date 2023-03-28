#!/usr/bin/bash

desktop_environment::install_xfce()
{
    root_mount="$1"

    echo "Installing XFCE Desktop enviorment with X11 and lightdm..."

pacstrap -i "${root_mount}" "mesa" "xorg" "xfce4" "xfce4-goodies" "lightdm" "lightdm-gtk-greeter" << syslinux_install_commands
$(echo)
y
y
y
syslinux_install_commands

    arch-chroot "${root_mount}" "systemctl" "enable" "lightdm.service"
}
