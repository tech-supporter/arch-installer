#!/usr/bin/bash

###################################################################################################
# Handles desktop environment installer sourcing
###################################################################################################

###################################################################################################
# Sources all desktop environment installation scripts from the desktop environment directory
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
function desktop_environment::source_installers()
{
    local script_directory
    local driver_directory

    script_directory=$(install::get_script_directory)
    driver_directory="${script_directory}/desktop_environments/"

    install::source_directory "${driver_directory}"
}

###################################################################################################
# installs a given gpu driver
#
# Globals:
#   N/A
#
# Arguments:
#   path where the root of the new system is located
#   desktop environment
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function desktop_environment::install()
{
    local root_mount="$1"
    local desktop_environment="$2"

    local installer="desktop_environment::install_${desktop_environment}"

    $installer "${root_mount}"
}
