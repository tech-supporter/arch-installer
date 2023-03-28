#!/usr/bin/bash

driver::install_nouveau()
{
    local root_mount="$1"
    local uefi="$2"
    local cpu_vendor="$3"

    # install Nouveau packages
    echo "Installing Nouveau driver packages..."
pacstrap -i "${root_mount}" "mesa" "lib32-mesa" "xf86-video-nouveau" << install_commands
$(echo)
$(echo)
y
y
install_commands

    echo "Finished installing Nouveau drivers."
}
