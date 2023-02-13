#!/usr/bin/bash

GetInputs(){
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