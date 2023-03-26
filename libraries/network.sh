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
        echo "Reaching out to: ${website}"
        response=$(curl --connect-timeout "${timeout}" -Is "${website}" | head -n 1 | grep "200")
        if [[ -n "${response}" ]]; then
            return 0
        fi
        echo "Could not connect to: ${website}"
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
    local state
    local default_wifi_adaptor
    local wifi_adaptor
    local network_names
    local wifi_network
    local confirm
    local wifi_password
    local wifi_connect_response

    state='network'
    while true; do
    case ${state} in
        'network')
        # get device
        default_wifi_adaptor=$(iw dev | awk '$1=="Interface"{print $2}')
        wifi_adaptor=${default_wifi_adaptor}

        # if connected to a network disconnect to start over
        iwctl station ${wifi_adaptor} disconnect

        # get networks
        clear
        iwctl station ${wifi_adaptor} scan # enable scanning
        iwctl station ${wifi_adaptor} get-networks
        network_names=$(iwctl station ${wifi_adaptor} get-networks | awk '{if(NR > 4) print $1}' )

        # choose network
        wifi_network=$(input::read_autocomplete 'Choose network to connect to: ' "${network_names}")

        # check if network is in list
        if [[ ${network_names} == *${wifi_network}* ]]; then
            state='password'
        else
            read -p "That network (${wifi_network}) was not found. Do you want to choose a different network? (y/n)" confirm
            if [ -z ${confirm} ] || [ ${confirm} = 'y' ]; then
            echo ""
            else
            state='password'
            fi
        fi
        ;;

        'password')
        read -s -p "Enter network password or nothing to choose different network: " wifi_password
        if [ -z ${wifi_password} ]; then
            state='network'
        else
            state='connect'
        fi
        ;;

        'connect')
        echo -n "Connecting to network."
        wifi_connect_response=$(iwctl --passphrase ${wifi_password} station ${wifi_adaptor} connect ${wifi_network} 2>&1)
        for ((i = 0 ; i < 2 ; i++)); do
            sleep 1
            echo -n "."
        done
        echo ""

        if [[ ${wifi_connect_response:0:${#invalid_name}} == ${invalid_name} ]]; then
            echo "Invalid network name."
            state='network'
        elif [[ ${wifi_connect_response:0:${#incorrect_password}} == ${incorrect_password} ]]; then
            echo "Invalid network password."
            state='password'
        else
            if ! network::online; then
                echo "Connection failed."
                state='password'
            else
                state='connected'
            fi
        fi
        ;;

        'connected')
        echo "Connected to network."
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
    local confirm

    echo "Checking for internet access"
    while ! network::online; do
        input::read_yes_no "No access to internet, connect to a wifi network?"
        if [ $? -eq 0 ]; then
            network::connect_to_wifi
        fi
    done
    echo "Connected to the internet"
    echo
}
