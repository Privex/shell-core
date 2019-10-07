# Used by dependent scripts to check if this file has been sourced or not.
export SRCED_COLORS=1

! [ -z ${ZSH_VERSION+x} ] && _SDIR=${(%):-%N} || _SDIR="${BASH_SOURCE[0]}"
DIR="$( cd "$( dirname "${_SDIR}" )" && pwd )"

if [ -t 1 ]; then
    BOLD="$(tput bold)" RED="$(tput setaf 1)" GREEN="$(tput setaf 2)" YELLOW="$(tput setaf 3)" BLUE="$(tput setaf 4)"
    MAGENTA="$(tput setaf 5)" CYAN="$(tput setaf 6)" WHITE="$(tput setaf 7)" RESET="$(tput sgr0)"
else
    BOLD="" RED="" GREEN="" YELLOW="" BLUE=""
    MAGENTA="" CYAN="" WHITE="" RESET=""
fi

#####
# Easy coloured messages function
# Written by @someguy123
# Usage:
#   # Prints "hello" and "world" across two lines in the default terminal color
#   msg "hello\nworld"
#
#   # Prints "    this is an example" in green text
#   msg green "\tthis" is an example
#
#   # Prints "An error has occurred" in bold red text
#   msg bold red "An error has occurred"
#
#####
function msg () {
    if [[ "$#" -eq 0 ]]; then echo ""; return; fi;
    if [[ "$#" -eq 1 ]]; then
        echo -e "$1"
        return
    fi
    [[ "$1" == "ts" ]] && shift && _msg="[$(date +'%Y-%m-%d %H:%M:%S %Z')] " || _msg=""
    if [[ "$#" -gt 2 ]] && [[ "$1" == "bold" ]]; then
        echo -n "${BOLD}"
        shift
    fi
    (($#==1)) && _msg+="$@" || _msg+="${@:2}"

    case "$1" in
        bold) echo -e "${BOLD}${_msg}${RESET}";;
        BLUE|blue) echo -e "${BLUE}${_msg}${RESET}";;
        YELLOW|yellow) echo -e "${YELLOW}${_msg}${RESET}";;
        RED|red) echo -e "${RED}${_msg}${RESET}";;
        GREEN|green) echo -e "${GREEN}${_msg}${RESET}";;
        CYAN|cyan) echo -e "${CYAN}${_msg}${RESET}";;
        MAGENTA|magenta|PURPLE|purple) echo -e "${MAGENTA}${_msg}${RESET}";;
        * ) echo -e "${_msg}";;
    esac
}

# Alias for 'msg' function with timestamp on the left.
function msgts () {
    msg ts "${@:1}"
}

function msgerr () {
    # Same as `msg` but outputs to stderr instead of stdout
    >&2 msg "$@"
}

[ -z ${SRCED_IDENT_SH+x} ] && source "${DIR}/identify.sh"

if [[ $(ident_shell) == "bash" ]]; then
    export -f msg msgts >/dev/null
elif [[ $(ident_shell) == "zsh" ]]; then
    export msg msgts >/dev/null
else
    >&2 echo "${RED}${BOLD}WARNING: Could not identify your shell. Attempting to export msg and msgts with plain export..."
    export msg msgts
fi

export RED GREEN YELLOW BLUE BOLD NORMAL RESET

