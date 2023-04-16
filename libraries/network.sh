#!/usr/bin/bash

###################################################################################################
# Handles network connectivity and other network related functions
###################################################################################################


###################################################################################################
# Checks if the machine has access to the internet
#
# Globals:
#   N/A
#
# Arguments:
#   N/A
#
# Output:
#   return 0 for online, return 1 for offline
#
# Source:
#   N/A
###################################################################################################
function network::online()
{
    local response
    local timeout="5"
    local websites=(
        "https://ping.archlinux.org"
        "https://www.linuxfoundation.org"
        "https://www.quad9.net"
        "https://www.eff.org"
        "https://www.gnu.org"
        )

    # reach out to each website to check if we have internet access
    # try another one if we fail or timeout
    # if reached, return true
    for website in "${websites[@]}"; do
        # echo "Reaching out to: ${website}"
        response=$(curl --connect-timeout "${timeout}" -Is "${website}" | head -n 1 | grep "200")
        if [[ -n "${response}" ]]; then
            return 0
        fi
        # echo "Could not connect to: ${website}"
    done

    # could not connect to any websites
    return 1
}

###################################################################################################
# Wifi network connection wizard
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
function network::connect_to_wifi()
{
    # standard error strings
    local invalid_name="Invalid network name"
    local incorrect_password="Operation failed"
    local connection_error="failure"

    # variables
    local status
    local state
    local default_wifi_adaptor
    local wifi_adaptor
    local network_names
    local wifi_network
    local confirm
    local wifi_password
    local wifi_connect_response
    local options
    local percent

    state='network'
    while true; do
        case "${state}" in
            'network')
            # get device
            default_wifi_adaptor=$(iw dev | awk '$1=="Interface"{print $2}')
            wifi_adaptor="${default_wifi_adaptor}"

            # if connected to a network disconnect to start over
            iwctl station "${wifi_adaptor}" disconnect

            # get networks
            iwctl station "${wifi_adaptor}" scan # enable scanning

            readarray -t network_names < <(iwctl station "${wifi_adaptor}" get-networks | tail -n +5 | sed 's,\x1B\[[0-9;]*[a-zA-Z],,g' | sed 's/^[[:space:]]*//g' | awk -F" {2}" '{print $1}' | head -n -1)

            options=()
            for (( i = 0; i < "${#network_names[@]}"; i++ )); do
                options+=("${network_names[i]}" "")
            done

            # choose network
        input::capture_dialog status wifi_network whiptail --noitem --cancel-button "re-scan" --menu "Select a Wifi Network" 0 0 0 "${options[@]}"

            # check if a network was selected
            if [[ "${status}" == "0" ]]; then
                state='password'
            fi
            ;;

            'password')

            input::capture_dialog status wifi_password whiptail --passwordbox "Enter Wifi Password" 8 30
            if [ -z ${wifi_password} ]; then
                state='network'
            else
                state='connect'
            fi
            ;;

            'connect')
            wifi_connect_response=$(iwctl --passphrase "${wifi_password}" station "${wifi_adaptor}" connect "${wifi_network}" 2>&1)

            if [[ "${wifi_connect_response:0:${#invalid_name}}" == "${invalid_name}" ]]; then
            input::capture_dialog status confirm whiptail --msgbox "Invalid SSID (Network Name)" 0 0
                state='network'
            elif [[ "${wifi_connect_response:0:${#incorrect_password}}" == "${incorrect_password}" ]]; then
                input::capture_dialog status confirm whiptail --msgbox "Invalid Password" 0 0
                state='password'
            else
                if ! network::online; then
                    input::capture_dialog status confirm whiptail --msgbox "Connection failed" 0 0
                    state='password'
                else
                    state='connected'
                fi
            fi
            ;;

            'connected')
            break
            ;;

            *)
            state='network'
            ;;
        esac
    done
}

###################################################################################################
# Checks for internet access and kicks off wifi network connection wizard
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
function network::setup()
{
    local status
    local output

    while ! network::online; do
        input::capture_dialog status output whiptail --yesno "No access to internet, connect to a wifi network?" 0 0
        if [[ "${status}" == "0" ]]; then
            network::connect_to_wifi
        fi
    done
    input::capture_dialog status output whiptail --msgbox "Connected to the Internet" 0 0
    echo
}
