#!/usr/bin/bash

###################################################################################################
# Handles driver sourcing and driver related functions
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
function driver::source_gpu_driver_installers()
{
    local script_directory
    local driver_directory

    script_directory=$(install::get_script_directory)
    driver_directory="${script_directory}/gpu_drivers/"

    install::source_directory "${driver_directory}"
}
