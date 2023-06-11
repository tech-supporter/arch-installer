#!/usr/bin/bash

###################################################################################################
# Handles setting kernel hooks and modules
###################################################################################################

###################################################################################################
# builds the linux kernel using mkinitcpio
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
function kernel::build()
{
    local root_mount="$1"

    arch-chroot "${root_mount}" "mkinitcpio" "-P"
}

###################################################################################################
# appends to the start of the linux kernal hooks
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
function kernel::add_hook_after()
{
    local root_mount="$1"
    local parameters="$2"
    local after="$3"

    sed -i "s/${after}/${after} ${parameters}/" "${root_mount}/etc/mkinitcpio.conf"

    # generate linux kernel
    kernel::build "${root_mount}"
}

###################################################################################################
# sets the linux kernal hooks
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
function kernel::set_hooks()
{
    local root_mount="$1"
    local parameters="$2"

    sed -i "s/^HOOKS=(.*/HOOKS=(${parameters})/" "${root_mount}/etc/mkinitcpio.conf"

    # generate linux kernel
    kernel::build "${root_mount}"
}

###################################################################################################
# sets the required linux kernal hooks
# Globals:
#   N/A
#
# Arguments:
#   path to where the root partition is mounted, without trailing slash
#   is encryption enabled
#
# Output:
#   N/A
#
# Source:
#   N/A
#
###################################################################################################
function kernel::set_default_hooks()
{
    local root_mount="$1"
    local encryption="$2"

    if $encryption; then
        kernel::set_hooks "${root_mount}" "base udev autodetect keyboard keymap modconf kms consolefont block lvm2 encrypt filesystems fsck"
    else
        kernel::set_hooks "${root_mount}" "base udev autodetect keyboard keymap modconf kms consolefont block lvm2 filesystems fsck"
    fi
}
