#!/usr/bin/bash

###################################################################################################
# Functions for configuring the installer
###################################################################################################

# Global hash table of configuration values for the install script
export -A configuration=(
    ["uefi"]=""                             # true / false
    ["install_micro_code"]=""               # install micro code true / false
    ["cpu_vendor"]=""                       # intel / amd
    ["gpu_driver"]=""                       # name of gpu driver installer
    ["computer_name"]=""                    # human readable pretty computer name
    ["root_password"]=""                    # password for root account
    ["swap_partition_size"]=""              # size of the swap partition in gigabytes
    ["root_partition_size"]=""              # size of root partition in gigabytes
    ["drive"]=""                            # drive to install to
    ["kernel"]=""                           # linux kernal varient: linux, linux-lts, linux-hardened, etc
    ["timezone"]=""                         # timezone: America/Chicago
    ["locale"]=""                           # system localization: "en_US.UTF-8 UTF-8"
    ["key_map"]=""                          # the keyboard layout for the new and install system
    ["location"]=""                         # string descriptor in the machine-info
    ["install_unofficial_repositories"]=""  # install unofficial user repositories, true / false
    ["enable_ssh_server"]=""                # enable the ssh server after installing, true / false
    ["users"]=""                            # space separated user list, passwords and additional groups
    ["desktop_environment"]=""              # desktop environment E.I. KDE Plasma
)

###################################################################################################
# Checks if the system has booted in uefi mode
#
# Globals:
#   configuration
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
function config::load_defaults()
{
    if system::uefi; then
        configuration["uefi"]=true
    else
        configuration["uefi"]=false
    fi

    configuration["cpu_vendor"]=$(system::cpu_vendor)
    configuration["install_micro_code"]=true
    configuration["gpu_driver"]="none"
    configuration["computer_name"]="Arch Linux Computer"
    configuration["location"]="Server Room"
    configuration["locale"]="en_US.UTF-8 UTF-8"
    configuration["timezone"]="America/Chicago"
    configuration["root_partition_size"]=64
    configuration["swap_partition_size"]=$(system::memory_size)
    configuration["kernel"]="linux"
    configuration["install_unofficial_repositories"]=false
    configuration["enable_ssh_server"]=true
    configuration["desktop_environment"]="none"

    if [[ "${configuration["cpu_vendor"]}" == "unknown" ]]; then
        echo "Could not determine CPU vendor!"
        configuration["install_micro_code"]=false
    fi
}

###################################################################################################
# Check UEFI mode and ask user if they wish to reboot if UEFI is disabled
#
# Globals:
#   configuration["uefi"]
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
function config::prompt_uefi()
{
    local option
    local options=("on" "off")

    if system::uefi; then
        configuration["uefi"]=true

        input::read_option "Set UEFI Mode" options
        option="${input_selection}"

        if [[ "${option}" == "on" ]]; then
            configuration["uefi"]=true
            echo "UEFI Mode is Enabled"
        else
            configuration["uefi"]=false
            echo "UEFI Mode is Disabled"
        fi

    else
        configuration["uefi"]=false
        echo "UEFI Mode is Disabled"
        input::read_yes_no "Reboot for BIOS menu?"
        if [ $? -eq 0 ]; then
            reboot
        fi
    fi
}

###################################################################################################
# Prompt the user if they want to install vendor's microcode
#
# Globals:
#   configuration["install_micro_code"]
#
# Arguments:
#   N/A
#
# Output:
#   N/A
#
# Source:
#   N/A
#
###################################################################################################
function config::prompt_install_micro_code()
{
    local option
    local options=("yes" "no")

    input::read_option "Install CPU Micro Code?" options
    option="${input_selection}"

    if [[ "${option}" == "yes" ]]; then
        configuration["install_micro_code"]=true
    else
        configuration["install_micro_code"]=false
    fi

    echo "Install CPU Vendor Micro Code: ${configuration["install_micro_code"]}"
}

###################################################################################################
# Prompt the user to select a CPU vendor
#
# Globals:
#   configuration["cpu_vendor"]
#
# Arguments:
#   N/A
#
# Output:
#   N/A
#
# Source:
#   N/A
#
###################################################################################################
function config::prompt_cpu_vendor()
{
    local vendor
    local vendors=("Intel" "AMD")
    local prompt="Select a CPU Vendor"

    input::read_option "${prompt}" vendors
    vendor="${input_selection,,}"

    configuration["cpu_vendor"]="${vendor}"

    clear
    echo "CPU Vendor: ${vendor}"
}

###################################################################################################
# Prompt the user for a gpu driver to install
#
# Globals:
#   configuration["gpu_driver"]
#   input_selection
#
# Arguments:
#   N/A
#
# Output:
#   N/A
#
# Source:
#   N/A
#
# TODO: load the list of drivers dynamically from the gpu_drivers directory
###################################################################################################
function config::prompt_gpu_driver()
{
    local drivers
    local driver

    drivers=("amd" "none" "nouveau" "nvidia")

    input::read_option "Select a GPU driver " drivers
    driver="${input_selection}"

    configuration["gpu_driver"]="${driver}"

    clear
    echo "GPU Driver: ${driver}"
}

###################################################################################################
# Prompt the user for a computer name
#
# Globals:
#   configuration["computer_name"]
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
function config::prompt_computer_name()
{
    local computer_name
    local host_name
    local validation_functions_array
    local validation_errors_array

    validation_functions_array=('input::validate_computer_name')
    validation_errors_array=('Computer name must be at least 1 character and can only contain letters, numbers, underscores (_) and hyphens (-)')
    computer_name=$(input::read_validated "Enter a name for this computer" validation_functions_array validation_errors_array)
    #host_name=$(echo ${computer_name} | tr '[:upper:]' '[:lower:]' | tr '_ ' '-' | tr -dc '[:alnum:]-')

    configuration["computer_name"]="${computer_name}"

    echo "Computer Name: ${computer_name}"
}

###################################################################################################
# Prompt the user for a linux kernel to install
#
# Globals:
#   configuration["kernel"]
#   input_selection
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
function config::prompt_kernel()
{
    local kernels
    local kernel

    kernels=("linux" "linux-lts" "linux-zen" "linux-hardened" "linux-rt" "linux-rt-lts")

    input::read_option "Select a Linux Kernel Varient " kernels
    kernel="${input_selection}"

    configuration["kernel"]="${kernel}"

    clear
    echo "Linux Kernel: ${kernel}"
}

###################################################################################################
# Prompt the user to select a disk to install the system to
#
# Globals:
#   configuration["drive"]
#   input_selection
#
# Arguments:
#   N/A
#
# Output:
#   N/A
#
# Source:
#   N/A
#
# TODO: make this easy to tell which drive is which using some kind of hardware info like brand
###################################################################################################
function config::prompt_drive()
{
    local drives
    local options
    local drive
    local index

    readarray -t drives < <(lsblk | grep disk | awk '{print $1}')
    readarray -t options < <(lsblk | grep disk | awk '{print $1 " " $4}')

    input::read_option "Select a Drive for Install " options true
    index="${input_selection}"
    drive="${drives[${index}]}"

    configuration["drive"]="${drive}"

    clear
    echo "Install Drive: ${drive}"
}

###################################################################################################
# Prompt the user to enter a root partition size in gibibytes
#
# Globals:
#   configuration["root_partition_size"]
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
function config::prompt_root_partition_size()
{
    local root_partition_size
    local validation_functions_array
    local validation_errors_array

    validation_functions_array=('input::validate_whole_number')
    validation_errors_array=('Root partition size must a whole number')
    root_partition_size=$(input::read_validated "Enter the Root Partition Size in GiB" validation_functions_array validation_errors_array "64")

    configuration["root_partition_size"]="${root_partition_size}"

    echo "Root Partition Size: ${root_partition_size}Gib"
}

###################################################################################################
# Prompt the user to enter a swap partition size in gibibytes
#
# Globals:
#   configuration["swap_partition_size"]
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
function config::prompt_swap_partition_size()
{
    local swap_partition_size
    local validation_functions_array
    local validation_errors_array
    local default_swap_size

    local prompt="Enter the Swap Partition Size in GiB"

    default_swap_size=$(system::memory_size)

    validation_functions_array=('input::validate_whole_number')
    validation_errors_array=('Swap partition size must a whole number')
    swap_partition_size=$(input::read_validated "${prompt}" validation_functions_array validation_errors_array "${default_swap_size}")

    configuration["swap_partition_size"]="${swap_partition_size}"

    echo "Swap Partition Size: ${swap_partition_size}Gib"
}

###################################################################################################
# Prompt the user to enter their time zone in Olson format
# Exmaple America/Chicago
#
# Globals:
#   configuration["timezone"]
#
# Arguments:
#   N/A
#
# Output:
#   N/A
#
# Source:
#   N/A
#
###################################################################################################
function config::prompt_timezone()
{
    local timezone
    local timezones
    local prompt="Select a Time Zone"

    readarray -t timezones < <(timedatectl list-timezones)

    input::read_option "${prompt}" timezones
    timezone="${input_selection}"

    configuration["timezone"]="${timezone}"

    clear
    echo "Time Zone: ${timezone}"
}

###################################################################################################
# Prompt the user to select their locale and character set information
#
# Globals:
#   configuration["key_map"]
#
# Arguments:
#   N/A
#
# Output:
#   N/A
#
# Source:
#   N/A
#
###################################################################################################
function config::prompt_key_map()
{
    local key_map
    local key_maps
    local prompt="Select a Keyboard Mapping"

    readarray -t key_maps < <(localectl list-keymaps)

    input::read_option "${prompt}" key_maps
    key_map="${input_selection}"

    configuration["key_map"]="${key_map}"

    # load in the selected key map right away
    system::load_key_map "${key_map}"

    clear
    echo "Keyboard Mapping: ${key_map}"
}

###################################################################################################
# Prompt the user to select their locale and character set information
#
# Globals:
#   configuration["locale"]
#
# Arguments:
#   N/A
#
# Output:
#   N/A
#
# Source:
#   N/A
#
###################################################################################################
function config::prompt_locale()
{
    local locale
    local locales
    local prompt="Select a Locale and Character Set"

    readarray -t locales < <(cat /usr/share/i18n/SUPPORTED)

    input::read_option "${prompt}" locales
    locale="${input_selection}"

    configuration["locale"]="${locale}"

    clear
    echo "Locale and Character Set: ${locale}"
}

###################################################################################################
# Prompt the user to select their locale and character set information
#
# Globals:
#   configuration["locale"]
#
# Arguments:
#   N/A
#
# Output:
#   N/A
#
# Source:
#   N/A
#
###################################################################################################
function config::prompt_location()
{
    local location
    local prompt="Enter a Location for the Machine: "

    read -p "${prompt}" location

    configuration["location"]="${location}"

    clear
    echo "Location: ${location}"
}

###################################################################################################
# Prompt the user to select a root password
# Globals:
#   configuration["root_password"]
#
# Arguments:
#   N/A
#
# Output:
#   N/A
#
# Source:
#   N/A
#
###################################################################################################
function config::prompt_root_password()
{
    configuration["root_password"]="$(input::read_password "Enter a Root Password")"

    clear
    echo "Root Password Set"
}

###################################################################################################
# Prompt the user if the install unofficial repositories should be installed
#
# Globals:
#   configuration["install_unofficial_repositories"]
#   input_selection
#
# Arguments:
#   N/A
#
# Output:
#   N/A
#
# Source:
#   N/A
#
# TODO: Allow the selection of individual repos -- as a list instead of boolean
###################################################################################################
function config::prompt_install_unofficial_repositories()
{
    local options
    local option

    options=("yes" "no")
    repos=("archzfs")

    input::read_option "Install Unofficial User Repositories? Repos: ${repos[@]}" options
    option="${input_selection}"

    if [[ "${option}" == "yes" ]]; then
        configuration["install_unofficial_repositories"]=true
    else
        configuration["install_unofficial_repositories"]=false
    fi

    clear
    echo "Install Unofficial User Repositories: ${option}"
}

###################################################################################################
# Prompt the user if they want to enable an ssh server
#
# Globals:
#   configuration["enable_ssh_server"]
#
# Arguments:
#   N/A
#
# Output:
#   N/A
#
# Source:
#   N/A
#
###################################################################################################
function config::prompt_enable_ssh_server()
{
    local option
    local options=("yes" "no")

    input::read_option "Enable SSH Server?" options
    option="${input_selection}"

    if [[ "${option}" == "yes" ]]; then
        configuration["enable_ssh_server"]=true
    else
        configuration["enable_ssh_server"]=false
    fi

    echo "Enable SSH Server: ${configuration["enable_ssh_server"]}"
}

###################################################################################################
# Gets the nth user in the users configuration
#
# Globals:
#   configuration["users"]
#
# Arguments:
#   index of the user, starting at 0
#
# Output:
#   space delimited username, password and additional groups
#
# Source:
#   N/A
#
###################################################################################################
function config::get_user()
{
    local index="$1"
    local username_index
    local password_index
    local groups_index
    local users
    local user

    ((username_index=index*3))
    ((password_index=index*3+1))
    ((groups_index=index*3+2))

    IFS=' ' read -ra users <<< "${configuration["users"]}"

    user="${users[username_index]} ${users[password_index]} ${users[groups_index]}"

    echo "${user}"
}

###################################################################################################
# Gets the number of users configured
#
# Globals:
#   configuration["users"]
#
# Arguments:
#   N/A
#
# Output:
#   the count of users
#
# Source:
#   N/A
#
###################################################################################################
function config::get_user_count()
{
    local users
    local count

    IFS=' ' read -ra users <<< "${configuration["users"]}"

    ((count=${#users[@]}/3))

    echo "${count}"
}

###################################################################################################
# Adds a user to the configuration
#
# Globals:
#   configuration["users"]
#
# Arguments:
#   space delimited user info, username, password additional groups
#
# Output:
#   the count of users
#
# Source:
#   N/A
#
###################################################################################################
function config::add_user()
{
    local user="$1"

    if [[ -z "${configuration["users"]}" ]]; then
        configuration["users"]+="${user}"
    else
        configuration["users"]+=" ${user}"
    fi
}

###################################################################################################
# removes a user to the configuration
#
# Globals:
#   configuration["users"]
#
# Arguments:
#   space delimited user info, username, password additional groups
#
# Output:
#   the count of users
#
# Source:
#   N/A
#
###################################################################################################
function config::remove_user()
{
    local index="$1"
    local user_index
    local password_index
    local groups_index
    local users
    local count

    ((user_index=index*3))
    ((password_index=user_index+1))
    ((groups_index=user_index+2))

    count=$(config::get_user_count)

    if [[ "${count}" > 0 ]]; then
        users=(${configuration["users"]})

        unset users[$groups_index]
        unset users[$password_index]
        unset users[$user_index]

        configuration["users"]="${users[@]}"
    fi
}

###################################################################################################
# Gets the names of the users configured
#
# Globals:
#   configuration["users"]
#
# Arguments:
#   N/A
#
# Output:
#   the usernames of all users
#
# Source:
#   N/A
#
###################################################################################################
function config::get_user_names()
{
    local user
    local users
    local count
    local index

    users=()
    count=$(config::get_user_count)

    for ((i = 0; i < count; i++)); do
        ((index=i*3))
        user=($(config::get_user "${i}"))
        users[$i]="${user[0]}"
    done

    echo "${users[@]}"
}

###################################################################################################
# prompt the user to select user groups
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
#
###################################################################################################
function config::prompt_groups()
{
    local groups
    local group_selection
    local group_text
    local option_index
    local options

    groups=($(system::groups))
    for ((i = 0; i < ${#groups[@]}; i++)); do
        group_selection[i]="0"
    done

    while true; do
        options=()

        for ((i = 0; i < ${#groups[@]}; i++)); do
            if [[ "${group_selection[i]}" == "1" ]]; then
                options[i]="[${groups[i]}]"
            else
                options[i]="${groups[i]}"
            fi
        done

        options[${#options[@]}]="Exit"

        input::read_option "Select Groups" options true "${option_index}"
        option_index="${input_selection}"

        if [[ "${options["${option_index}"]}" == "Exit" ]]; then
            break
        else
            if [[ "${group_selection["${option_index}"]}" == "0" ]]; then
                group_selection["${option_index}"]="1"
            else
                group_selection["${option_index}"]="0"
            fi
        fi
    done

    group_text=""
    for ((i = 0; i < ${#groups[@]}; i++)); do
        if [[ "${group_selection[i]}" == "1" ]]; then
            if [[ -z "${group_text}" ]]; then
                group_text+="${groups[i]}"
            else
                group_text+=",${groups[i]}"
            fi
        fi
    done

    if [[ -z "${group_text}" ]]; then
        group_text="-"
    fi

    echo "${group_text}"
}

###################################################################################################
# prompt the user for new user details
#
# Globals:
#   configuration["users"]
#
# Arguments:
#   N/A
#
# Output:
#   N/A
#
# Source:
#   N/A
#
# TODO:
#   Keep the user from entering two or more users with the same username
###################################################################################################
function config::prompt_add_user()
{
    local username
    local password
    local groups

    local validate_username
    local username_errors

    clear
    validate_username=('input::validate_computer_name')
    username_errors=('Username must be at least 1 character and can only contain letters, numbers, underscores (_) and hyphens (-)')
    username=$(input::read_validated "Enter a Username" validate_username username_errors)

    clear
    password=$(input::read_password "Enter a Password")

    clear
    groups="$(config::prompt_groups)"

    config::add_user "${username} ${password} ${groups}"
}

###################################################################################################
# UI for adding and removing users
#
# Globals:
#   configuration["users"]
#
# Arguments:
#   N/A
#
# Output:
#   N/A
#
# Source:
#   N/A
#
# TODO:
#   Allow the user to edit user definitions and delete them
###################################################################################################
function config::prompt_users()
{
    local option_index
    local options

    while true; do
        options=($(config::get_user_names))
        options[${#options[@]}]="Add User"
        options[${#options[@]}]="Exit"

        input::read_option "Select a User to Delete or Add a User" options true
        option_index="${input_selection}"

        if [[ "${options["${option_index}"]}" == "Add User" ]]; then
            config::prompt_add_user
        elif [[ "${options["${option_index}"]}" == "Exit" ]]; then
            break
        else
            config::remove_user "${option_index}"
        fi
    done
}

###################################################################################################
# Prompt the user for a desktop environment
#
# Globals:
#   configuration["desktop_environment"]
#
# Arguments:
#   N/A
#
# Output:
#   N/A
#
# Source:
#   N/A
#
###################################################################################################
function config::prompt_desktop_environment()
{
    local option
    local options=("lxqt" "plasma" "xfce" "none")

    input::read_option "Select a Desktop Environment" options
    option="${input_selection}"

    configuration["desktop_environment"]="${option}"

    echo "Desktop Environment: ${configuration["desktop_environment"]}"
}

###################################################################################################
# Main configuration selection menu
#
# Globals:
#   configuration
#
# Arguments:
#   N/A
#
# Output:
#   N/A
#
# Source:
#   N/A
#
###################################################################################################
function config::show_menu()
{
    local selection
    local index=0
    local options
    local prompt="Select a setting to configure"
    local prompt_function
    local key
    local value
    local length=0
    local max_length=0
    local spacing=0
    local spaces
    local settings=("UEFI" "CPU Vendor" "Install CPU Micro Code" "GPU Driver" "Install Unofficial Repositories" "Enable SSH Server"
                    "Key Mapping" "Locale" "Timezone" "Computer Name" "Location" "Desktop Environment" "Root Password" "Users"
                    "Drive" "Root Partition Size" "Swap Partition Size"
                    "Kernel")
    local prompts=("uefi" "cpu_vendor" "install_micro_code" "gpu_driver" "install_unofficial_repositories" "enable_ssh_server"
                   "key_map" "locale" "timezone" "computer_name" "location" "desktop_environment" "root_password" "users"
                   "drive" "root_partition_size" "swap_partition_size"
                   "kernel")

    config::load_defaults

    while true; do
        options=()
        for ((i = 0; i < ${#settings[@]} ; i++)); do
            options[i]="${settings[i]}"
        done

        # find the length of the longest option
        for ((i = 0; i < ${#options[@]} ; i++)); do
            value="${options[i]}"
            if [[ "${max_length}" -lt "${#value}" ]]; then
                max_length="${#value}"
            fi
        done

        # make all options the same length
        for ((i = 0; i < ${#options[@]} ; i++)); do
            key="${options[i]}"
            length=${#key}
            ((spacing=max_length-length))
            spaces=$(printf '%*s' "${spacing}")
            options[i]="${spaces}${options[i]}: "
        done

        # add the current configuration values to the ends of the options
        for ((i = 0; i < ${#options[@]} ; i++)); do
            if [[ "${prompts[i]}" == "root_password" ]]; then
                value=${configuration[${prompts[i]}]}
                options[i]="${options[i]}$(printf "%${#value}s\n" | tr ' ' '*')"
            elif [[ "${prompts[i]}" == "root_partition_size" ]] || [[ "${prompts[i]}" == "swap_partition_size" ]]; then
                options[i]="${options[i]}${configuration[${prompts[i]}]} GiB"
            elif [[ "${prompts[i]}" == "users" ]]; then
                length=$(config::get_user_count)
                options[i]="${options[i]}${length}"
            else
                options[i]="${options[i]}${configuration[${prompts[i]}]}"
            fi
        done

        # add aditional options
        options["${#options[@]}"]="install"

        input::read_option "${prompt}" options true "${index}"
        index="${input_selection}"
        selection="${options[index]}"

        # execute prompts or specialized commands
        if [[ "${selection}" == "install" ]]; then
            # make sure each setting has a value
            value=""
            for ((i = 0; i < ${#options[@]} - 1 ; i++)); do
                if [[ "${configuration["${prompts[i]}"]}" == "" ]]; then
                    value="${options[i]}"
                    break 1
                fi
            done

            if [[ "${value}" == "" ]]; then
                # if no setting had a value, exit to installation
                break 1
            else
                # else tell user which setting needs to be configured next
                clear
                echo "You have not Configured Setting: $(echo "${value}" | sed 's/^[ \t]*//' |sed 's/://')"
                read -p "Press Enter to Continue" value
            fi
        else
            # get the configuration function for the selection
            prompt_function="config::prompt_${prompts[index]}"

            # execute config function
            clear
            "${prompt_function}"
        fi
    done
}
