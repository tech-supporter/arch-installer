#!/usr/bin/bash

# usage
# ReadWithAutocomplete <promt text> <space delimited list of autocomplete options>

# imports
SCRIPT_PATH="${BASH_SOURCE}"
while [ -L "${SCRIPT_PATH}" ]; do
  SCRIPT_DIR="$(cd -P "$(dirname "${SCRIPT_PATH}")" >/dev/null 2>&1 && pwd)"
  SCRIPT_PATH="$(readlink "${SCRIPT_PATH}")"
  [[ ${SCRIPT_PATH} != /* ]] && SCRIPT_PATH="${SCRIPT_DIR}/${SCRIPT_PATH}"
done
SCRIPT_PATH="$(readlink -f "${SCRIPT_PATH}")"
SCRIPT_DIR="$(cd -P "$(dirname -- "${SCRIPT_PATH}")" >/dev/null 2>&1 && pwd)"

source "${SCRIPT_DIR}/GetInputs.sh"

ReadWithAutocomplete(){
  # inputs
  local propt=${1}
  local options=(${2})
  # output variable
  local output=""
  # function
  echo -n "${propt}" >$(tty)
  while true; do
    input=$(GetInputs)
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
     output=${output}${input}
    fi
  done
}