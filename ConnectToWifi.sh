#!/usr/bin/bash

# imports
SCRIPT_PATH="${BASH_SOURCE}"
while [ -L "${SCRIPT_PATH}" ]; do
  SCRIPT_DIR="$(cd -P "$(dirname "${SCRIPT_PATH}")" >/dev/null 2>&1 && pwd)"
  SCRIPT_PATH="$(readlink "${SCRIPT_PATH}")"
  [[ ${SCRIPT_PATH} != /* ]] && SCRIPT_PATH="${SCRIPT_DIR}/${SCRIPT_PATH}"
done
SCRIPT_PATH="$(readlink -f "${SCRIPT_PATH}")"
SCRIPT_DIR="$(cd -P "$(dirname -- "${SCRIPT_PATH}")" >/dev/null 2>&1 && pwd)"

source "${SCRIPT_DIR}/ReadWithAutocomplete.sh"

# ping site
ping_site="gnu.org"

# standard error strings
invalid_name="Invalid network name"
incorrect_password="Operation failed"
connection_error="failure"
#connection_error="Ping: "${ping_site}": Temporary failure in name resolution"

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
      wifi_network=$(ReadWithAutocomplete 'Choose network to connect to: ' "${network_names}")

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
        ping_response=$(ping ${ping_site} -c 1 2>&1)
        if [[ ${ping_response} == *${connection_error}* ]]; then
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
#while true; do
#    ping_response=$(ping ${ping_site} -c 1 2>&1)
#    error_start_string="Ping: "${ping_site}": "
#    if [[ ${ping_response:${#error_start_string}:${#error_string}} = ${error_string} ]]; then
#        echo "No internet connection found."
#        read -p "Would you like to configure Wifi? (Y/n): " confirm
#        if [ -z ${confirm} ] || [ ${confirm} = 'y' ]; then
#            default_wifi_adaptor=$(iw dev | awk '$1=="Interface"{print $2}')
#            echo "Wi-Fi device: "${default_wifi_adaptor}
#
#            wifi_adaptor=${default_wifi_adaptor}
#            iwctl station ${wifi_adaptor} scan
#            iwctl station ${wifi_adaptor} get-networks
#
#            read -p "Choose network to connect to: " wifi_network
#            read -s -p "Network password: " wifi_password
#            echo ""
#            echo "Connecting to network..."
#
#            wifi_connect_response=$(iwctl --passphrase ${wifi_password} station ${wifi_adaptor} connect ${wifi_network} 2>&1)
#            sleep 2
#            if [[ ${wifi_connect_response:0:${#invalid_name}} = ${invalid_name} ]]; then
#                echo "Invalid network name."
#            elif [[ ${wifi_connect_response:0:${#incorrect_password}} = ${incorrect_password} ]]; then
#                echo "Invalid network password."
#            fi
#        else
#            read -p "Then please plug in an ethernet cord and try again. (press enter to try again)" confirm
#        fi
#    else
#        echo "Internet connection found."
#        break
#    fi
#done