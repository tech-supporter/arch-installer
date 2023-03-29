#!/usr/bin/bash

gpu_driver::install_nvidia()
{
    # read in parameters
    local root_mount="$1"
    local uefi="$2"
    local cpu_vendor="$3"

    # install nvidia packages
    echo "Installing nVidia driver packages..."
pacstrap -i "${root_mount}" "nvidia-dkms" "nvidia-utils" "opencl-nvidia" "libglvnd" "lib32-libglvnd" "lib32-nvidia-utils" "lib32-opencl-nvidia" "nvidia-settings" << install_commands
$(echo)
$(echo)
y
y
install_commands

    # create the dynamic kernal module support hook
    # it's likely that only the linux and nvidia-dkms targets are required
    # but to avoid any potential of something failing, putting all the packages in there
    # though this will rebuild the kernal for each package that is updated so might want to trim this down to just the required ones
    local hooks_path="${root_mount}/etc/pacman.d/hooks/"
    echo "Creating DKMS hook..."
    mkdir -p ${hooks_path}
    echo '
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=nvidia
Target=nvidia-dkms
Target=nvidia-utils
Target=opencl-nvidia
Target=libglvnd
Target=lib32-libglvnd
Target=lib32-nvidia-utils
Target=lib32-opencl-nvidia
Target=nvidia-settings
Target=linux

[Action]
Depends=mkinitcpio
When=PostTransaction
Exec=/usr/bin/mkinitcpio -P
' > "${hooks_path}nvidia.hook"

    # update kernal modules
    echo "Updating kernal modules list..."
    sed -i 's/MODULES=(/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm/g' "${root_mount}/etc/mkinitcpio.conf"

    echo "Updating boot loader..."

    # disable Indirect Branch Tracking when using intel based CPUs
    # on linux kernal 5.18 and higher, it is required, at least until the issue is solved
    # https://wiki.archlinux.org/title/NVIDIA#Installation
    local boot_text="nvidia-drm.modeset=1"
    if [[ "${cpu_vendor}" == "intel" ]]; then
        boot_text="${boot_text} ibt=off"
    fi

    # update the correct boot loader based on uefi status
    local boot_path="${root_mount}/boot/syslinux/syslinux.cfg"
    if $uefi; then
        boot_path="${root_mount}/boot/loader/entries/arch.conf"
    fi

    # update the configuration of the boot loader
    sed -i "s/rw/rw ${boot_text}/" ${boot_path}

    echo "Finished installing nVidia drivers."
}
