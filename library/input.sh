#!/usr/bin/bash

# validation functions, custom validation methods can be defined as needed
# The validation function simply takes in an input string and returns:
# 0 -> function executed without error, means valid
# 1 -> function executed with error, means invalid
# argument {1} is the input

# validate that the input is a whole number
# I.e. an integer which is greater or equal to zero
function validate_whole_number()
{
    local input=${1}
    local regex='^[0-9]+$'
    local error='1'
    if [[ ${input} =~ ${regex} ]]; then
        return 0
    fi
    return 1
}

# validates that an input is an integer with an optional negative sign
function validate_integer()
{
    local input=${1}
    local regex='^\-?[0-9]+$'
    local error='1'
    if [[ ${input} =~ ${regex} ]]; then
        return 0
    fi
    return 1
}

# validates that an input is a decimal with an optional negative sign
# does NOT allow for exponent notation example: 10.1E-1
function validate_decimal()
{
    local input=${1}
    local regex='^\-?[0-9]*\.?[0-9]+$'
    local error='1'
    if [[ ${input} =~ ${regex} ]]; then
        return 0
    fi
    return 1
}

# validates that an input is a fraction
# allows optional lead zeros in denominator but does not allow division by zero
function validate_fraction()
{
    local input=${1}
    local regex='^\-?[0-9]+\/0*[1-9]+0*$'
    local error='1'
    if [[ ${input} =~ ${regex} ]]; then
        return 0
    fi
    return 1
}

function validate_storage_size()
{
    local input=${1}
    local regex='^[0-9]+[bkmgtBKMGT]$'
    local error='1'
    if [[ ${input} =~ ${regex} ]]; then
        return 0
    fi
    return 1
}

# checks if the input matches the structure of an email address
# does not allow subdomains
function validate_email()
{
    local input=${1}
    local regex='^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$'
    local error='1'
    if [[ ${input} =~ ${regex} ]]; then
        return 0
    fi
    return 1
}

# checks that the input is an existing directory
function validate_folder_exists()
{
    local input=${1}
    local error='1'
    if [[ -d ${input} ]]; then
        return 0
    fi
    return 1
}

# read input from user
# argument 1: the prompt to the user
# argument 2: an array of validation functions
# argument 3: an array of error messages
# argument 4: an optional default input
# argument 5: an optional setting to check all validation functions regardless if one fails
# example call to this function:
# validation_functions_array=('validate_integer' 'validate_whole_number')
# validation_errors_array=('Input is not an integer!' 'Input is not a whole number!')
# value=$(read_input "Enter a whole number" validation_functions_array validation_errors_array "42" true)
function read_input()
{
    local prompt=${1}
    local -n validation_functions=$2
    local -n validation_errors=$3
    local default_input=${4}
    local check_all=${5}
    local value=''
    local input=''
    local short_circuit_validation=true

    if ! [[ -z ${check_all} ]]; then
        short_circuit_validation=$check_all
    fi

    while [[ -z ${value} ]]; do
        echo "${prompt}" >&2

        # display the default input value
        if ! [[ -z "${default_input}" ]]; then
            echo "(Default: ${default_input})" >&2
        fi

        # read in the user's input
        read -r input

        # if the user did not enter anything and there is a default, use the default
        if [[ -z ${input} ]] && ! [[ -z ${default_input} ]]; then
            value=${default_input}
        else
            # check if the user's input passes validation functions
            local valid=true
            for ((i = 0; i < ${#validation_functions[@]}; i++)); do
                local validation_function="${validation_functions[i]}"
                if ! $validation_function "${input}"; then
                    echo "${validation_errors[i]}" >&2
                    valid=false

                    # apply short-circuit validation
                    if $short_circuit_validation; then
                        break 1
                    fi
                fi
            done
            if $valid; then
                value=$input
            else
                echo >&2
            fi
        fi
    done

    echo ${value}
}
