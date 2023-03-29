#!/usr/bin/bash

desktop_environment::install_lxqt()
{
    root_mount="$1"

    echo "Installing LXQT Desktop enviorment with X11 and SDDM..."

pacstrap -i "${root_mount}" "mesa" "xorg" "lxqt" "sddm" "breeze-icons" << syslinux_install_commands
$(echo)
$(echo)
$(echo)
$(echo)
$(echo)
$(echo)
$(echo)
$(echo)
$(echo)
$(echo)
$(echo)
$(echo)
$(echo)
$(echo)
$(echo)
$(echo)
syslinux_install_commands

    arch-chroot "${root_mount}" "systemctl" "enable" "sddm.service"
}
