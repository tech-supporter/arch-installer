#!/usr/bin/bash

###################################################################################################
# Handles installing the boot loader
###################################################################################################

###################################################################################################
# Checks if the system has booted in uefi mode
#
# Globals:
#   N/A
#
# Arguments:
#   N/A
#
# Output:
#   return 0 for UEFI mode enabled, return 1 for UEFI mode disabled
#
# Source:
#   N/A
###################################################################################################
function boot::uefi()
{
    local uefi_vars

    uefi_vars=$(efivar -l 2>&1)

    if ! [[ ${uefi_vars:0:13} = "efivar: error" ]]; then
        return 0
    else
        return 1
    fi
}

###################################################################################################
# installs the uefi boot loader
#
# Globals:
#   N/A
#
# Arguments:
#   path to where the root partition is mounted, without trailing slash
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function boot::install_boot_loader_uefi()
{
    local root_mount="$1"
    local drive="$2"

    # install efi boot manager required by grub
pacstrap -i "${root_mount}" "efibootmgr" << install_commands
$(echo)
y
install_commands

    # install boot loader
    arch-chroot "${root_mount}" "grub-install" "--target=x86_64-efi" "--efi-directory=/boot" "--bootloader-id=GRUB"
}

###################################################################################################
# installs the bios boot loader
#
# Globals:
#   N/A
#
# Arguments:
#   path to where the root partition is mounted, without trailing slash
#   drive path
#
# Output:
#   N/A
#
# Source:
#   N/A
#
# TODO: make the micro code insertion more robust
###################################################################################################
function boot::install_boot_loader_bios()
{
    local root_mount="$1"
    local drive="$2"

    # install boot loader
    arch-chroot "${root_mount}" "grub-install" "--target=i386-pc" "/dev/${drive}"
}

###################################################################################################
# installs the boot loader
# Globals:
#   N/A
#
# Arguments:
#   uefi mode true / false
#   drive path
#   path to where the root partition is mounted, without trailing slash
#
# Output:
#   N/A
#
# Source:
#   N/A
#
# TODO: make the micro code insertion more robust
###################################################################################################
function boot::install_boot_loader()
{
    local uefi="$1"
    local drive="$2"
    local root_mount="$3"

    local root_partition

    root_partition=$(disk::get_root_partition "${drive}")

    # run installer grub script
    if $uefi; then
        boot::install_boot_loader_uefi "${root_mount}" "${drive}"
    else
        boot::install_boot_loader_bios "${root_mount}" "${drive}"
    fi

    # generate grub config
    boot::generate_config "${root_mount}"

    # add root partition uuid to linux parameters
    #boot::add_linux_parameters "${root_mount}" "options root=PARTUUID=$(blkid -s PARTUUID -o value "${root_partition}") rw"
}

###################################################################################################
# regenerates the grub config applying the setting si /etc/default/grub and in /etc/grub.d/
# Globals:
#   N/A
#
# Arguments:
#   path to where the root partition is mounted, without trailing slash
#
# Output:
#   N/A
#
# Source:
#   N/A
#
###################################################################################################
function boot::generate_config()
{
    local root_mount="$1"

    arch-chroot "${root_mount}" "grub-mkconfig" "-o" "/boot/grub/grub.cfg"
}

###################################################################################################
# appends to the start of the linux kernal parameters
# Globals:
#   N/A
#
# Arguments:
#   path to where the root partition is mounted, without trailing slash
#   parameters to append
#
# Output:
#   N/A
#
# Source:
#   N/A
#
###################################################################################################
function boot::add_linux_parameters()
{
    local root_mount="$1"
    local parameters="$2"

    sed -i "s/GRUB_CMDLINE_LINUX=\"/GRUB_CMDLINE_LINUX=\"${parameters} /" "${root_mount}/etc/default/grub"

    # generate grub config
    boot::generate_config "${root_mount}"
}
