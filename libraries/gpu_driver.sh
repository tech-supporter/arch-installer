#!/usr/bin/bash

###################################################################################################
# Handles gpu driver sourcing and gpu driver installation interface
###################################################################################################

###################################################################################################
# Sources all GPU driver installation scripts from the gpu drivers directory
#
# Globals:
#   N/A
#
# Arguments:
#   N/A
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function gpu_driver::source_installers()
{
    local script_directory
    local driver_directory

    script_directory=$(install::get_script_directory)
    driver_directory="${script_directory}/gpu_drivers/"

    install::source_directory "${driver_directory}"
}

###################################################################################################
# installs a given gpu driver
#
# Globals:
#   N/A
#
# Arguments:
#   gpu driver name
#   uefi
#   cpu vendor
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function gpu_driver::install()
{
    local root_mount="$1"
    local gpu_driver="$2"
    local uefi="$3"
    local cpu_vendor="$4"

    local installer="gpu_driver::install_${gpu_driver}"

    $installer "${root_mount}" "${uefi}" "${cpu_vendor}"
}
