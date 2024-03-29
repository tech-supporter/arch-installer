#!/usr/bin/bash

# untested, install taken from
# https://wiki.archlinux.org/title/AMDGPU#Installation
gpu_driver::install_amd()
{
    # read in parameters
    local root_mount="$1"
    local uefi="$2"
    local cpu_vendor="$3"

    # install amd packages
    echo "Installing AMD driver packages..."
pacstrap -i "${root_mount}" "mesa" "lib32-mesa" "xf86-video-amdgpu" "vulkan-radeon" "lib32-vulkan-radeon" "libva-mesa-driver" "lib32-libva-mesa-driver" "mesa-vdpau" "lib32-mesa-vdpau" << install_commands
$(echo)
$(echo)
y
y
install_commands

    # update kernal modules
    echo "Updating kernal modules list..."
    sed -i 's/MODULES=(/MODULES=(amdgpu radeon/g' "${root_mount}/etc/mkinitcpio.conf"

    local boot_text="radeon.si_support=0 amdgpu.si_support=1 radeon.cik_support=0 amdgpu.cik_support=1"

    # update the configuration of the boot loader
    boot::add_linux_parameters "${root_mount}" "${boot_text}"

    echo "Finished installing AMD drivers."
}
