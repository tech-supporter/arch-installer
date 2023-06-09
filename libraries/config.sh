#!/usr/bin/bash

###################################################################################################
# Functions for configuring the installer
###################################################################################################

# Global hash table of configuration values for the install script
export -A configuration=(
    ["uefi"]=""                             # system supports Unified Extensible Firmware Interface true / false
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
    ["users"]=""                            # space separated user list: username, password and additional groups
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
    if boot::uefi; then
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
    configuration["key_map"]="us"
    configuration["timezone"]="America/Chicago"
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
    local status
    local option
    local options=("on" "off")

    if boot::uefi; then
        configuration["uefi"]=true

        input::capture_dialog status option dialog --yesno "Enable UEFI" 0 0

        if [[ "${status}" == "0" ]]; then
            configuration["uefi"]=true
        else
            configuration["uefi"]=false
        fi

    else
        configuration["uefi"]=false

        input::capture_dialog status option dialog --yesno "Booted in BIOS Mode, Reboot for BIOS Menu?" 0 0

        if [[ "${status}" == "0" ]]; then
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
    local status
    local option
    local prompt="Install CPU Micro Code"

    input::capture_dialog status option dialog --yesno "${prompt}" 0 0

    if [[ "${status}" == "0" ]]; then
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
    local status
    local options=()
    local vendor="${configuration["cpu_vendor"]}"
    local vendors=("intel" "amd")
    local prompt="Select a CPU Vendor"

    for index in "${!vendors[@]}"; do
        if [[ "${vendors[index]}" == "${vendor}" ]]; then
            options+=("${vendors[index]}" "on")
        else
            options+=("${vendors[index]}" "off")
        fi
    done

    input::capture_dialog status vendor dialog --no-items --no-cancel --radiolist "${prompt}" 0 0 0 "${options[@]}"

    configuration["cpu_vendor"]="${vendor}"
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
    local status
    local options=()
    local gpu_driver="${configuration["gpu_driver"]}"
    local gpu_drivers=("amd" "nvidia" "nouveau" "none")
    local prompt="Select a GPU Driver"

    for index in "${!gpu_drivers[@]}"; do # for each index in the list
        if [[ "${gpu_drivers[index]}" == "${gpu_driver}" ]]; then
            options+=("${gpu_drivers[index]}" "on")
        else
            options+=("${gpu_drivers[index]}" "off")
        fi
    done

    input::capture_dialog status gpu_driver dialog --no-items --no-cancel --radiolist "${prompt}" 0 0 0 "${options[@]}"

    configuration["gpu_driver"]="${gpu_driver}"
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
    local status
    local computer_name="${configuration["computer_name"]}"
    local prompt="Enter a name for this computer"
    local error="Computer name must be at least 1 character and can only contain letters, numbers, underscores (_) and hyphens (-)"

    while true; do
        input::capture_dialog status computer_name dialog --no-cancel --inputbox "${prompt}" 0 0 "${computer_name}"

        if input::validate_computer_name "${computer_name}"; then
            break
        else
            input::capture_dialog status status dialog --no-cancel --msgbox "${error}" 0 0
        fi
    done

    configuration["computer_name"]="${computer_name}"
}

###################################################################################################
# Prompt the user for a linux kernel to install
#
# Globals:
#   configuration["kernel"]
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
    local status
    local kernel="${configuration["kernel"]}"
    local kernels
    local options=()
    local prompt="Select a Linux Kernel"
    kernels=("linux" "linux-lts" "linux-zen" "linux-hardened" "linux-rt" "linux-rt-lts")

    for index in "${!kernels[@]}"; do
        options+=("${kernels[index]}")
        if [[ "${kernels[index]}" == "${kernel}" ]]; then
            options+=("on")
        else
            options+=("off")
        fi
    done

    input::capture_dialog status kernel dialog --no-items --no-cancel --radiolist "${prompt}" 0 0 0 "${options[@]}"

    configuration["kernel"]="${kernel}"
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
    local status
    local selection
    local options=()

    local drive="${configuration["drive"]}"
    local drives=()
    local sizes=()

    local prompt="Select an Install Drive"

    readarray -t drives < <(lsblk | grep disk | awk '{print $1}')
    readarray -t sizes < <(lsblk | grep disk | awk '{print $4}')

    for (( i = 0; i < "${#drives[@]}"; i++ )); do
        options+=("${drives[i]}" "${sizes[i]}")
        if [[ "${drives[i]}" == "${drive}" ]]; then
             options+=("on")
        else
             options+=("off")
        fi
    done

    input::capture_dialog status drive dialog --no-cancel --radiolist "${prompt}" 0 0 0 "${options[@]}"

    configuration["drive"]="${drive}"
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
    local status
    local root_partition_size="${configuration["root_partition_size"]}"
    local prompt="Enter the Root Partition Size in GiB"
    local error="Root partition size must a whole number"

    while true; do
        input::capture_dialog status root_partition_size dialog --no-cancel --inputbox "${prompt}" 0 0 "${root_partition_size}"

        if input::validate_whole_number "${root_partition_size}"; then
            break
        else
            input::capture_dialog status status dialog --msgbox "${error}" 0 0
        fi
    done

    configuration["root_partition_size"]="${root_partition_size}"
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
    local status
    local swap_partition_size="${configuration["swap_partition_size"]}"
    local prompt="Enter the Swap Partition Size in GiB"
    local error="Swap partition size must a whole number"

    while true; do
        input::capture_dialog status swap_partition_size dialog --no-cancel --inputbox "${prompt}" 0 0 "${swap_partition_size}"

        if input::validate_whole_number "${swap_partition_size}"; then
            break
        else
            input::capture_dialog status status dialog --msgbox "${error}" 0 0
        fi
    done

    configuration["swap_partition_size"]="${swap_partition_size}"
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
    local status
    local timezone="${configuration["timezone"]}"
    local timezones
    local options=()
    local prompt="Select a Time Zone"

    readarray -t timezones < <(system::timezones)

    for index in "${!timezones[@]}"; do # for each index in the list
        if [[ "${timezones[index]}" == "${timezone}" ]]; then
            options+=("${timezones[index]}" "on")
        else
            options+=("${timezones[index]}" "off")
        fi
    done

    input::capture_dialog status timezone dialog --no-items --no-cancel --radiolist "${prompt}" 0 0 0 "${options[@]}"

    configuration["timezone"]="${timezone}"
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
    local key_map="${configuration["key_map"]}"
    local key_maps
    local status
    local options=()
    local prompt="Select a Keyboard Mapping"

    readarray -t key_maps < <(system::key_maps)

    for index in "${!key_maps[@]}"; do # for each index in the list
        options+=("${key_maps[index]}")
        if [[ "${key_maps[index]}" == "${key_map}" ]]; then
            options+=("on")
        else
            options+=("off")
        fi
    done

    if system::package_installed "dialog"; then
        input::capture_dialog status key_map dialog --no-items --no-cancel --radiolist "${prompt}" 0 0 0 "${options[@]}"
    else
        # dialog is not installed yet
        input::capture_dialog status key_map whiptail --noitem --nocancel --radiolist "${prompt}" 0 0 0 "${options[@]}"
    fi

    configuration["key_map"]="${key_map}"

    # load in the selected key map right away
    system::load_key_map "${key_map}"
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
    local locale="${configuration["locale"]}"
    local locales
    local status
    local options=()
    local prompt="Select a Locale and Character Set"

    readarray -t locales < <(system::locales)

    for index in "${!locales[@]}"; do # for each index in the list
        if [[ "${locales[index]}" == "${locale}" ]]; then
            options+=("${locales[index]}" "on")
        else
            options+=("${locales[index]}" "off")
        fi
    done

    input::capture_dialog status locale dialog --no-items --no-cancel --radiolist "${prompt}" 0 0 0 "${options[@]}"

    configuration["locale"]="${locale}"
}

###################################################################################################
# Prompt the user to select their locale and character set information
#
# Globals:
#   configuration["location"]
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
    local status
    local location="${configuration["location"]}"
    local prompt="Enter a Location for the Computer"

    input::capture_dialog status location dialog --inputbox "${prompt}" 0 0 "${location}"

    configuration["location"]="${location}"
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
    local password

    input::read_password "Enter a Root Password" password

    configuration["root_password"]="${password}"
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
    local status
    local option
    local repos=("archzfs")
    local prompt="Install Unofficial User Repositories? Repos: ${repos[@]}"

    input::capture_dialog status option dialog --yesno "${prompt}" 0 0

    if [[ "${status}" == "0" ]]; then
        configuration["install_unofficial_repositories"]=true
    else
        configuration["install_unofficial_repositories"]=false
    fi
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
    local status
    local option
    local prompt="Enable SSH Server"

    input::capture_dialog status option dialog --yesno "${prompt}" 0 0

    if [[ "${status}" == "0" ]]; then
        configuration["enable_ssh_server"]=true
    else
        configuration["enable_ssh_server"]=false
    fi
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
function config::edit_user()
{
    local index="$1"
    local user=("$2")
    local index_user
    local new_users=()
    local count

    ((username_index=index*3))
    ((username_index=username_index+3))

    users=("${configuration["users"]}")
    count=$(config::get_user_count)

    for (( i = 0; i < "${count}"; i++ )); do
        if [[ "${i}" == "${index}" ]]; then
            new_users+=("${user[0]}" "${user[1]}" "${user[2]}")
        else
            index_user=($(config::get_user "${i}"))
            new_users+=("${index_user[0]}" "${index_user[1]}" "${index_user[2]}")
        fi
    done

    configuration["users"]="${new_users[@]}"
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
function config::get_usernames()
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
# Checks if a username is already in use
#
# Globals:
#   configuration["users"]
#
# Arguments:
#   The username to check for
#
# Output:
#   true if username exists, false if not
#
# Source:
#   N/A
#
###################################################################################################
function config::username_exists()
{
    local username="$1"
    local usernames

    usernames=($(config::get_usernames))

    for (( i = 0; i < "${#usernames[@]}"; i++ )); do
        if [[ "${username}" == "${usernames[i]}" ]]; then
            return 0
        fi
    done

    return 1
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
function config::prompt_user_groups()
{
    local -n group_text_ref=$1
    local group_text="${group_text_ref}"
    local working_groups
    local selected_groups=()
    local option_index
    local options
    local selected
    local status
    local prompt="Select Groups"

    working_groups=($(system::groups))
    options=()

    IFS=',' read -ra selected_groups <<< "${group_text}"

    for (( i = 0; i < "${#working_groups[@]}"; i++ )); do
        options+=("${working_groups[i]}")
        selected=false

        for (( j = 0; j < "${#selected_groups[@]}"; j++ )); do
            if [[ "${working_groups[i]}" == "${selected_groups[j]}" ]]; then
                selected=true
                break 1
            fi
        done

        if $selected; then
            options+=("on")
        else
            options+=("off")
        fi
    done

    input::capture_dialog status selected_groups dialog --no-cancel --no-items --checklist "${prompt}" 0 0 0 "${options[@]}"

    IFS=' ' read -ra selected_groups <<< "${selected_groups}"

    group_text=""
    for ((i = 0; i < "${#selected_groups[@]}"; i++)); do
        if [[ -z "${group_text}" ]]; then
            group_text+="${selected_groups[i]}"
        else
            group_text+=",${selected_groups[i]}"
        fi
    done

    if [[ -z "${group_text}" ]]; then
        group_text="-"
    fi

    group_text_ref="${group_text}"
}

###################################################################################################
# prompt the user for a username
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
function config::prompt_user_username()
{
    local -n username_ref=$1
    local status
    local working_username="${username_ref}"
    local prompt="Enter a Username"
    local taken_error="Username is already in use"
    local invalid_error="Username must be at least 1 character and can only contain letters, numbers, underscores (_) and hyphens (-)"

    while true; do
        input::capture_dialog status working_username dialog --no-cancel --inputbox "${prompt}" 0 0 "${working_username}"

        if config::username_exists "${working_username}" && [[ "${working_username}" != "${username_ref}" ]]; then
            input::capture_dialog status status dialog --no-cancel --msgbox "${taken_error}" 0 0
        elif ! input::validate_computer_name "${working_username}"; then
            input::capture_dialog status status dialog --no-cancel --msgbox "${invalid_error}" 0 0
        else
            break 1
        fi
    done

    username_ref="${working_username}"
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
#   instead of adding a new user and then editing it, just bring up the menu to edit with blanks
###################################################################################################
function config::prompt_add_user()
{
    local count

    count=$(config::get_user_count)

    config::add_user "username password -"

    config::prompt_edit_user "${count}"
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
function config::prompt_edit_user()
{
    local index="$1"
    local status
    local user
    local usernames
    local pass
    local options
    local selection
    local username
    local password
    local groups
    local prompt="Select a Value to Edit"

    while true; do
        user=($(config::get_user "${index}"))

        username="${user[0]}"
        password="${user[1]}"
        groups="${user[2]}"

        if [[ "${groups}" == "-" ]]; then
            groups=""
        fi

        pass="$(printf "%${#password}s\n" | tr ' ' '*')"
        options=("Username" "${username}" "Password" "${pass}" "Groups" "${groups}" "Delete" "" )

        input::capture_dialog status selection dialog --ok-label "Edit" --cancel-label "Exit" --menu "${prompt}" 0 0 0 "${options[@]}"

        if [[ "${selection}" == "Username" ]]; then
            config::prompt_user_username username
        elif [[ "${selection}" == "Password" ]]; then
            input::read_password "Enter Password" password
        elif [[ "${selection}" == "Groups" ]]; then
            config::prompt_user_groups groups
        elif [[ "${selection}" == "Delete" ]]; then
            config::remove_user "${index}"
            break 1
        else
            break 1
        fi

        if [[ "${groups}" == "" ]]; then
            groups="-"
        fi

        config::edit_user "${index}" "${username} ${password} ${groups}"
    done
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
###################################################################################################
function config::prompt_users()
{
    local selection
    local index
    local usernames
    local options
    local user
    local prompt="Select a User to Edit or Add a New User"

    while true; do
        usernames=($(config::get_usernames))

        options=($(config::get_usernames))
        options+=("Add User")

        input::capture_dialog status selection dialog --ok-label "Edit" --cancel-label "Exit" --noitems --menu "${prompt}" 0 0 0 "${options[@]}"

        if [[ "${selection}" == "Add User" ]]; then
            config::prompt_add_user
        elif [[ "${selection}" == "" ]]; then
            break
        else
            for (( i = 0; i < "${#usernames[@]}"; i++ )); do
                if [[ "${selection}" == "${usernames[i]}" ]]; then
                    config::prompt_edit_user "${i}"
                fi
            done
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
    local status
    local desktop_environment=${configuration["desktop_environment"]}
    local desktop_environments=("lxqt" "plasma" "xfce" "none")
    local options=()
    local prompt="Select a Desktop Environment"

    for index in "${!desktop_environments[@]}"; do # for each index in the list
        if [[ "${desktop_environments[index]}" == "${desktop_environment}" ]]; then
            options+=("${desktop_environments[index]}" "on")
        else
            options+=("${desktop_environments[index]}" "off")
        fi
    done

    input::capture_dialog status desktop_environment dialog --no-items --no-cancel --radiolist "${prompt}" 0 0 0 "${options[@]}"

    configuration["desktop_environment"]="${desktop_environment}"
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
# TODO:
#   Add option to export/import configurations to/from files
###################################################################################################
function config::show_menu()
{
    local selection
    local options
    local prompt="Select a Setting to Configure"
    local prompt_function
    local value
    local length=0
    local labels=("UEFI" "CPU Vendor" "Install CPU Micro Code" "GPU Driver" "Install Unofficial Repositories" "Enable SSH Server"
                    "Key Mapping" "Locale" "Timezone" "Computer Name" "Location" "Desktop Environment" "Root Password" "Users"
                    "Drive" "Root Partition Size" "Swap Partition Size"
                    "Kernel")
    local prompts=("uefi" "cpu_vendor" "install_micro_code" "gpu_driver" "install_unofficial_repositories" "enable_ssh_server"
                   "key_map" "locale" "timezone" "computer_name" "location" "desktop_environment" "root_password" "users"
                   "drive" "root_partition_size" "swap_partition_size"
                   "kernel")

    while true; do

        # add in the values of the configuration as "items" in the dialog
        options=()
        for ((i = 0; i < ${#labels[@]} ; i++)); do
            options+=("${labels[i]}")
            if [[ "${prompts[i]}" == "root_password" ]]; then
                value="${configuration["${prompts[i]}"]}"
                options+=("$(printf "%${#value}s\n" | tr ' ' '*')")
            elif [[ "${prompts[i]}" == "root_partition_size" ]] || [[ "${prompts[i]}" == "swap_partition_size" ]]; then
                options+=("${configuration["${prompts[i]}"]} GiB")
            elif [[ "${prompts[i]}" == "users" ]]; then
                length=$(config::get_user_count)
                options+=("${length}")
            else
                options+=("${configuration["${prompts[i]}"]}")
            fi
        done

        input::capture_dialog status selection dialog --ok-label "Edit" --cancel-label "Install" --menu "${prompt}" 0 0 0 "${options[@]}"

        # execute specialized commands or the prompt functions
        if [[ "${selection}" == "" ]]; then
            # make sure each configuration setting has a value
            value=""
            for ((i = 0; i < ${#labels[@]}; i++)); do

                # ignore some settings which can be left unconfigured
                if [[ "${prompts[i]}" == "users" ]]; then
                    continue
                fi

                if [[ "${configuration["${prompts[i]}"]}" == "" ]]; then
                    value="${labels[i]}"
                    break 1
                fi
            done

            if [[ "${value}" == "" ]]; then
                # if every setting had a value, exit to installation
                break 1
            else
                # else tell user which setting needs to be configured next
                input::capture_dialog status status dialog --msgbox "You have not Configured Setting: ${value}" 0 0
            fi
        else
            # find the correct prompt function for a given label
            # a dictionary would work great for this if it kept items in correct order
            for (( i = 0; i < "${#labels[@]}"; i++ )); do
                if [[ "${selection}" == "${labels[i]}" ]]; then
                    # get the configuration function for the selection
                    prompt_function="config::prompt_${prompts[i]}"

                    # execute config function
                    "${prompt_function}"

                    break 1
                fi
            done
        fi
    done
}
