#!/usr/bin/bash

###################################################################################################
# Main installer script
# Handles sourcing libraries from the libraries folder
# Should be kept simple and small, most of the logic should be handled by sourced library scripts
###################################################################################################


###################################################################################################
# Find the installer script's directory
#
# Globals:
#   N/A
#
# Arguments:
#   N/A
#
# Output:
#   The absolute path of the directory where this script is located
#
# Source:
#   https://www.baeldung.com/linux/bash-get-location-within-script
###################################################################################################
function install::get_script_directory()
{
    local script_path
    local script_directory

    script_path="${BASH_SOURCE}"
    while [ -L "${script_path}" ]; do
    script_directory="$(cd -P "$(dirname "${script_path}")" >/dev/null 2>&1 && pwd)"
    script_path="$(readlink "${script_path}")"
    [[ ${script_path} != /* ]] && script_path="${script_directory}/${script_path}"
    done
    script_path="$(readlink -f "${script_path}")"
    script_directory="$(cd -P "$(dirname -- "${script_path}")" >/dev/null 2>&1 && pwd)"

    echo "${script_directory}"
}

###################################################################################################
# Sources all script files in a given directory
#
# Globals:
#   N/A
#
# Arguments:
#   The path to a directory containing scripts with a trailing forward slash
#
# Output:
#   N/A
#
# Source:
#   N/A
###################################################################################################
function install::source_directory()
{
    local script_directory="$1"

    for script in ${script_directory}*.sh; do
        source "${script}"
    done
}

###################################################################################################
# Main install function serving as entry point to the install script
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
function install::main()
{
    local script_directory

    # source libraries
    script_directory=$(install::get_script_directory)
    install::source_directory "${script_directory}/libraries/"

    # connect to the internet
    network::setup

    # show configuration menu
    config::show_menu

    # format the selected drive, create file systems and swap
    #disk::format "${configuration["drive"]}" "${configuration["uefi"]}" "${configuration["root_partition_size"]}" "${configuration["swap_partition_size"]}"
}

install::main
