#!/usr/bin/bash

###################################################################################################
# Handles password generation and other cryptographic functions
###################################################################################################

###################################################################################################
# generates a random password of lower/upper case letters and numbers from /dev/urandom
#
# Globals:
#   N/A
#
# Arguments:
#   password length
#
# Output:
#   return password
#
# Source:
#   N/A
###################################################################################################
function security::generate_password()
{
    local length="$1"
    local password

    password=$(tr -dc A-Za-z0-9 </dev/urandom | head -c "${length}")

    echo "${password}"
}
