#!/usr/bin/bash

###################################################################################################
# Handles prompting and validating input from the user
###################################################################################################

# used to get the select out of the read_option function
export input_selection


###################################################################################################
# Validates that the input is a whole number
#
# Globals:
#   N/A
#
# Arguments:
#   string input for validation
#
# Output:
#   return 0 for valid, return 1 for invalid
#
# Source:
#   N/A
###################################################################################################
function input::validate_whole_number()
{
    local input="$1"
    local regex='^[0-9]+$'

    if [[ ${input} =~ ${regex} ]]; then
        return 0
    fi
    return 1
}

###################################################################################################
# Validates that an input is an integer with an optional negative sign
#
# Globals:
#   N/A
#
# Arguments:
#   string input for validation
#
# Output:
#   return 0 for valid, return 1 for invalid
#
# Source:
#   N/A
###################################################################################################
function input::validate_integer()
{
    local input="$1"
    local regex='^\-?[0-9]+$'

    if [[ ${input} =~ ${regex} ]]; then
        return 0
    fi
    return 1
}

###################################################################################################
# Validates that an input is a decimal with an optional negative sign
# Does NOT allow for exponent notation example: 10.1E-1
#
# Globals:
#   N/A
#
# Arguments:
#   string input for validation
#
# Output:
#   return 0 for valid, return 1 for invalid
#
# Source:
#   N/A
###################################################################################################
function input::validate_decimal()
{
    local input="$1"
    local regex='^\-?[0-9]*\.?[0-9]+$'

    if [[ ${input} =~ ${regex} ]]; then
        return 0
    fi
    return 1
}

###################################################################################################
# Validates that an input is a fraction
# Allows optional lead zeros in denominator but does not allow division by zero
#
# Globals:
#   N/A
#
# Arguments:
#   string input for validation
#
# Output:
#   return 0 for valid, return 1 for invalid
#
# Source:
#   N/A
###################################################################################################
function input::validate_fraction()
{
    local input="$1"
    local regex='^\-?[0-9]+\/0*[1-9]+0*$'

    if [[ ${input} =~ ${regex} ]]; then
        return 0
    fi
    return 1
}

###################################################################################################
# Validates that an input is a storage size with trailing byte based unit
#
# Globals:
#   N/A
#
# Arguments:
#   string input for validation
#
# Output:
#   return 0 for valid, return 1 for invalid
#
# Source:
#   N/A
###################################################################################################
function input::validate_storage_size()
{
    local input="$1"
    local regex='^[0-9]+[bkmgtBKMGT]$'

    if [[ ${input} =~ ${regex} ]]; then
        return 0
    fi
    return 1
}

###################################################################################################
# Validates that the input has the structure of an email address
# Does not allow subdomains
#
# Globals:
#   N/A
#
# Arguments:
#   string input for validation
#
# Output:
#   return 0 for valid, return 1 for invalid
#
# Source:
#   N/A
###################################################################################################
function input::validate_email()
{
    local input="$1"
    local regex='^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$'

    if [[ ${input} =~ ${regex} ]]; then
        return 0
    fi
    return 1
}

###################################################################################################
# Validates that the input is an existing directory
#
# Globals:
#   N/A
#
# Arguments:
#   string input for validation
#
# Output:
#   return 0 for valid, return 1 for invalid
#
# Source:
#   N/A
###################################################################################################
function input::validate_directory_exists()
{
    local input="$1"
    if [[ -d "${input}" ]]; then
        return 0
    fi
    return 1
}

###################################################################################################
# Validates that the input is an valid time zone in Olson format
#
# Globals:
#   N/A
#
# Arguments:
#   string input for validation
#
# Output:
#   return 0 for valid, return 1 for invalid
#
# Source:
#   N/A
###################################################################################################
function input::validate_time_zone()
{
    local input="$1"
    if [[ -e "/usr/share/zoneinfo/${input}" ]] && ! [[ -d "/usr/share/zoneinfo/${input}" ]]; then
        return 0
    fi
    return 1
}

###################################################################################################
# Validates that the input is an valid locale
#
# Globals:
#   N/A
#
# Arguments:
#   string input for validation
#
# Output:
#   return 0 for valid, return 1 for invalid
#
# Source:
#   N/A
###################################################################################################
function input::validate_locale()
{
    local input="$1"

    if [[ ! -z $(grep -x "${input}" "/usr/share/i18n/SUPPORTED") ]]; then
        return 0
    fi
    return 1
}

###################################################################################################
# Validates that the input valid computer name
# Globals:
#   N/A
#
# Arguments:
#   string input for validation
#
# Output:
#   return 0 for valid, return 1 for invalid
#
# Source:
#   N/A
###################################################################################################
function input::validate_computer_name()
{
    local input="$1"
    local regex='^[a-zA-Z0-9 \_\-]+$'

    if [[ ${input} =~ ${regex} ]]; then
        return 0
    fi
    return 1
}

###################################################################################################
# Prompts user with yes / no question
#
# Globals:
#   N/A
#
# Arguments:
#   string prompt
#
# Output:
#   return 0 for yes, return 1 for no
#
# Source:
#   N/A
#
# TODO: add argument for specifying the default behavour when nothing is entered
###################################################################################################
function input::read_yes_no()
{
    local prompt="$1"

    local confirm

    read -p "${prompt} (Y/n): " confirm
    if [ -z ${confirm} ] || [ ${confirm} = 'y' ] || [ ${confirm} = 'Y' ]; then
        return 0
    else
        return 1
    fi
}

###################################################################################################
# Prompts user for a new password
#
# Globals:
#   N/A
#
# Arguments:
#   string prompt
#   variable to write the password to
#
# Output:
#   the password entered
#
# Source:
#   N/A
#
###################################################################################################
function input::read_password()
{
    local prompt="$1"
    local -n password_ref=$2
    local new_password
    local confirm_password
    local status

    while [[ -z "${new_password}" ]] || [[ -z "${confirm_password}" ]] || [[ "${new_password}" != "${confirm_password}" ]]; do
        input::capture_dialog status new_password dialog --no-cancel --insecure --passwordbox "${prompt}" 0 0

        input::capture_dialog status confirm_password dialog --no-cancel --insecure --passwordbox "Confirm Password" 0 0

        if [[ -z "${new_password}" ]] || [[ -z "${confirm_password}" ]]; then
            input::capture_dialog status status dialog --msgbox "Password cannot be empty!" 0 0
        elif ! [[ "${new_password}" = "${confirm_password}" ]]; then
            input::capture_dialog status status dialog --msgbox "Passwords do not match!" 0 0
        fi
    done
    password_ref="${new_password}"
}

###################################################################################################
# captures the output of dialog into a supplied variable
#
# Globals:
#   N/A
#
# Arguments:
#   variable to write exit code to
#   variable to write output to
#   dialog command you wish to run
#   zero to many arguments to that command
#
# Output:
#   writes the captured output to the supplied variable
#
# Source:
#   https://stackoverflow.com/questions/962255/how-to-store-standard-error-in-a-variable
#   https://askubuntu.com/questions/491509/how-to-get-dialog-box-input-directed-to-a-variable
#
###################################################################################################
input::capture_dialog()
{
    local -n exitcode_ref=$1
    local -n result_ref=$2

    if [ "$#" -lt 3 ]; then
        echo "Usage: capture <varname> <returned status> <command> [arg ...]"
        return 1
    fi

    shift
    shift

    exec 3>&1
    result_ref=$("$@" 2>&1 1>&3)
    exitcode_ref="$?"
    exec 3>&-
    clear
}

###################################################################################################
# Validates that the input is an existing directory
#
# Globals:
#   N/A
#
# Arguments:
#   The prompt to the user
#   An array of validation functions
#   An array of error messages
#   An optional default input
#   An optional setting to check all validation functions regardless if one fails
#
# Output:
#   string input from user
#
# Source:
#   N/A
#
# Example:
#   validation_functions_array=('validate_integer' 'validate_whole_number')
#   validation_errors_array=('Input is not an integer!' 'Input is not a whole number!')
#   value=$(input::read_validated "Enter a whole number" validation_functions_array validation_errors_array "42" true)
###################################################################################################
function input::read_validated()
{
    local prompt="$1"
    local -n validation_functions=$2
    local -n validation_errors=$3
    local default_input="$4"
    local check_all="$5"
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

    echo "${value}"
}

###################################################################################################
# Reads input from the user with tab auto completion
#
# Globals:
#   N/A
#
# Arguments:
#   The prompt to the user
#   An array of options to tab auto complete from
#
# Output:
#   string input from user
#
# Source:
#   N/A
###################################################################################################
function input::read_autocomplete()
{
  # inputs
  local prompt=${1}
  local options=(${2})

  # output variable
  local output=""

  local input
  local key_type

  echo -n "${prompt}" >$(tty)
  while true; do
    input=$(input::get_inputs)
    key_type=$?
    if [[ ${input} == 'TAB' ]]; then
      declare -A matches
      matches=()
      for ((i = 0 ; i < ${#options[@]} ; i++)); do
        if [[ ${options[${i}]} == ${output}* ]]; then
          matches[${#matches[@]}]=${options[${i}]}
        fi
      done
      if [[ ${#matches} -gt 0 ]]; then
        for ((i = 0 ; i < ${#output} ; i++)); do
          echo -e -n "\b \b" >$(tty)
        done
        output=$(printf "%s\n" "${matches[@]}" | sed -e '$!{N;s/^\(.*\).*\n\1.*$/\1\n\1/;D;}')
        echo -n ${output} >$(tty)
      fi
    elif [[ ${input} == 'ENTER' ]]; then
      echo "" >$(tty)
      echo "${output}"
      return 0
    elif [[ ${input} == 'BACK_SPACE' ]] && [[ ${#output} -gt 0 ]]; then
      echo -e -n "\b \b" >$(tty)
      output=${output:0:$((${#output} - 1))}
    elif [[ ${key_type} == 0 ]]; then
     echo -n ${input} >$(tty)
     output="${output}${input}"
    fi
  done
}

###################################################################################################
# Reads escape characters and input
#
# Globals:
#   N/A
#
# Arguments:
#   The prompt to the user
#   An array of options to tab auto complete from
#
# Output:
#   Human readable character names for escape characters or the original input
#   Exit code for if the input was an escaped character or not
#
# Source:
#   N/A
###################################################################################################
function input::get_inputs()
{
  local start_input=''
  local end_input=''
  local escape_character=$(printf "\u1b")
  local back_space=$(printf "\u7f")
  IFS= read -s -r -n 1 start_input
  if [[ $start_input == $escape_character ]]; then
    IFS= read -s -r -n 5 -t 0.01 end_input
  fi
  local full_input=${start_input}${end_input}

  # Case Output
  case $full_input in
    '	') echo -n 'TAB'; return 1 ;;
    '') echo -n 'ENTER'; return 1 ;;
    ${escape_character}) echo -n 'ESCAPE'; return 1 ;;
    ${escape_character}"[A") echo -n 'UP'; return 1 ;;
    ${escape_character}"[B") echo -n 'DWON'; return 1 ;;
    ${escape_character}"[D") echo -n 'LEFT'; return 1 ;;
    ${escape_character}"[C") echo -n 'RIGHT'; return 1 ;;

    ${escape_character}"[2~") echo -n 'INSERT'; return 1 ;;
    ${escape_character}"[3~") echo -n 'DELETE'; return 1 ;;
    ${escape_character}"[H") echo -n 'HOME'; return 1 ;;
    ${escape_character}"[F") echo -n 'END'; return 1 ;;
    ${escape_character}"[5~") echo -n 'PAGE_UP'; return 1 ;;
    ${escape_character}"[6~") echo -n 'PAGE_DOWN'; return 1 ;;

    ${back_space}) echo -n 'BACK_SPACE'; return 1 ;;

    ${escape_character}"OP") echo -n 'F1'; return 1 ;;
    ${escape_character}"OQ") echo -n 'F2'; return 1 ;;
    ${escape_character}"OR") echo -n 'F3'; return 1 ;;
    ${escape_character}"OS") echo -n 'F4'; return 1 ;;
    ${escape_character}"[15~") echo -n 'F5'; return 1 ;;
    ${escape_character}"[17~") echo -n 'F6'; return 1 ;;
    ${escape_character}"[18~") echo -n 'F7'; return 1 ;;
    ${escape_character}"[19~") echo -n 'F8'; return 1 ;;
    ${escape_character}"[20~") echo -n 'F9'; return 1 ;;
    ${escape_character}"[21~") echo -n 'F10'; return 1 ;;
    ${escape_character}"[23~") echo -n 'F11'; return 1 ;;
    ${escape_character}"[24~") echo -n 'F12'; return 1 ;;

    *) echo -n "${full_input}"; return 0 ;;
  esac
}

###################################################################################################
# Cleans up the terminal for the read_option function
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
function input::clean_up_read_option()
{
    tput cnorm >$(tty)
}

###################################################################################################
# Shows a menu of selectable options
#
# Globals:
#   input_selection
#
# Arguments:
#   The prompt to the user
#   An array of options to select from
#
# Output:
#   sets the input_selection global to the selection
#
# Source:
#   N/A
#
# TODO: Make options searchable
###################################################################################################
function input::read_option()
{
    local prompt="$1"
    local -n input_options=$2
    local select_index="$3"
    local starting_index="$4"

    local selection
    local index
    local escape_char
    local mode
    local start_index
    local end_index
    local last_index
    local cursor_index
    local display_index
    local size=12

    # make sure we clean up the console if the user exits the script
    trap input::clean_up_read_option EXIT

    index="${starting_index}"
    selection=''
    escape_char=$(printf "\u1b")

    ((last_index=${#input_options[@]}-1))

    # hides the cursor
    tput civis >$(tty)

    while true; do

        ((start_index=index-size))

        if [[ "${start_index}" -lt 0 ]]; then
            start_index=0
            ((end_index=size+size))
        fi

        ((end_index=start_index+size+size))

        if [[ "${end_index}" -gt "${last_index}" ]]; then
            end_index="${last_index}"
            ((start_index=end_index-size-size))
        fi

        # constrain the start and end idecies to zero and option_count - 1
        if [[ "${start_index}" -lt 0 ]]; then
            start_index=0
        fi

        if [[ "${end_index}" -gt "${last_index}" ]]; then
            end_index="${last_index}"
        fi

        ((cursor_index=index-start_index))

        clear >$(tty)
        echo "${prompt}" >&2
        echo "Use the arrow keys and enter to select" >&2

        if [[ "${start_index}" -gt 0 ]]; then
            echo "^" >&2
        fi

        for ((i = "${start_index}" ; i <= "${end_index}" ; i++)); do
            ((display_index=i-start_index))
            if [[ "${cursor_index}" != "${display_index}" ]]; then
                    echo "${input_options[i]}" >&2
            else
                    echo -e "\e[4m${input_options[i]}\e[0m" >&2
            fi
        done

        if [[ "${end_index}" -lt "${last_index}" ]]; then
            echo "v" >&2
        fi

        read -rsn1 mode # get 1 character
        if [[ $mode == $escape_char ]]; then
            read -rsn2 mode # read 2 more chars
        fi
        case $mode in
            '[A') ((index=(index+${#input_options[@]}-1)%${#input_options[@]})) ;; # go up
            '[B') ((index=(index+1)%${#input_options[@]})) ;; # go down
            '') selection="${index}"; break 2;;
            *) ;;
        esac
    done

    # reset the cursor to normal
    input::clean_up_read_option

    if [[ -z "${select_index}" ]] || ! $select_index; then
        selection="${input_options[index]}"
    fi

    input_selection="${selection}"
}
