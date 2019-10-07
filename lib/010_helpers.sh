#!/usr/bin/env bash
#############################################################
#                                                           #
# Privex's Shell Core                                       #
# Cross-platform / Cross-shell helper functions             #
#                                                           #
# Released under the GNU GPLv3                              #
#                                                           #
# Official Repo: github.com/Privex/shell-core               #
#                                                           #
#############################################################
#
# Various Bash Helper Functions to ease the pain of writing
# complex, user friendly bash scripts.
#
# -----------------------------------------------------------
#
# Most parts written by Someguy123 https://github.com/Someguy123
# Some parts copied from elsewhere e.g. StackOverflow - but often improved by Someguy123
#
#####################

# Used by dependant scripts to check if this file has already been sourced
# e.g.    [ -z ${SRCED_010HLP+x} ] && source "$DIR/010_helpers.sh"
export SRCED_010HLP=1

# From https://stackoverflow.com/a/8574392/2648583
# Usage: containsElement "somestring" "${myarray[@]}"
# Returns 0 (true) if element exists in given array, or 1 if it doesn't.
#
# Example:
# 
#     a=(hello world)
#     if containsElement "hello" "${a[@]}"; then
#         echo "The array 'a' contains 'hello'"
#     else
#         echo "The array 'a' DOES NOT contain 'hello'"
#     fi
#
containsElement () {
    local e match="$1"
    shift
    for e; do [[ "$e" == "$match" ]] && return 0; done
    return 1
}

# Returns 0 (true) if a requested command exists (WARNING: this will match functions and aliases too)
# Use `has_binary` if you want to specifically only test for binaries
# Example:
#     has_command zip && echo "zip has binary or alias/function" || echo "error: zip not found"
#
has_command() {
    command -v "$1" > /dev/null
}

# Returns 0 (true) if the requested command exists as a binary (not as an alias/function)
# Example:
#     has_binary git && echo "the binary 'git' is available" || echo "could not find binary 'git' using which"
#
has_binary() {
    /usr/bin/env which "$1" > /dev/null
}

# Usage: yesno [message] (options...)
# Displays a bash `read -p` prompt, with the given message, and returns 0 (yes) or 1 (no) depending
# on how the user answers the prompt. Allows for handling yes/no user prompt questions in just
# a single line.
#
# Default functionality: returns 0 if yes, 1 if no, and repeat the question if answer is invalid.
# YesNo Function written by @someguy123
#
# Options:
#     Default return code:
#       defno - If empty answer, return 1 (no)
#       defyes - If empty answer, return 0 (yes)
#       deferr - If empty answer, return 3 (you must manually check $? return code)
#       fail - If empty answer, call 'exit 2' to terminate this script.
#     Flip return code:
#       invert - Flip the return codes - return 1 for yes, 0 for no. Bash will then assume no == true, yes == false
#
# Example:
# 
#     if yesno "Do you want to open this? (y/n) > "; then
#         echo "user said yes"
#     else
#         echo "user said no"
#     fi
#
#     yesno "Are you sure? (y/N) > " defno && echo "user said yes" || echo "user said no, or didn't answer"
#
yesno() {
    local MSG invert=0 retcode=3 defact="none" defacts
    defacts=('defno' 'defyes' 'deferr' 'fail')

    MSG="Do you want to continue? (y/n) > "
    (( $# > 0 )) && MSG="$1" && shift

    while (( $# > 0 )); do
        containsElement "$1" "${defacts[@]}" && defact="$1"
        [[ "$1" == "invert" ]] && invert=1
        shift
    done

    local YES=0 NO=1
    (( $invert == 1 )) && YES=1 NO=0

    unset answer
    while true; do
        read -p "$MSG" answer
        if [ -z "$answer" ]; then
            case "$defact" in
                defno)
                    retcode=$NO
                    break
                    ;;
                defyes)
                    retcode=$YES
                    (( $invert == 0 )) && retcode=0 || retcode=1
                    break
                    ;;
                fail)
                    exit 2
                    break
                    ;;
                *)
                    ;;
            esac
        fi
        case "$answer" in
            y|Y|yes|YES)
                retcode=$YES
                break
                ;;
            n|N|no|NO|nope|NOPE|exit)
                retcode=$NO
                break
                ;;
            *)
                msg red " (!!) Please answer by typing yes or no - or the characters y or n - then press enter."
                msg red " (!!) If you want to exit this program, press CTRL-C (hold CTRL and tap the C button on your keyboard)."
                msg
                ;;
        esac
    done
    return $retcode
}

# The command used to update the system package manager repos
: ${PKG_MGR_UPDATE="apt update -qy"}
# The command used to install a package - where the package name would be
# specified as the first argument following the command.
: ${PKG_MGR_INSTALL="apt install -y"}

PKG_MGR_UPDATED="n"
pkg_not_found() {
    # check if a command is available
    # if not, install it from the package specified
    # Usage: pkg_not_found [cmd] [package-name]
    # e.g. pkg_not_found git git
    if (($#<2)); then
        msg red "ERR: pkg_not_found requires 2 arguments (cmd) (package)"
        exit
    fi
    local cmd=$1
    local pkg=$2
    if ! has_binary "$cmd"; then
        msg yellow "WARNING: Command $cmd was not found. installing now..."
        if [[ "$PKG_MGR_UPDATED" == "n" ]]; then
            sudo sh -c "${PKG_MGR_UPDATE}" > /dev/null
            PKG_MGR_UPDATED="y"
        fi
        sudo sh -c "${PKG_MGR_INSTALL} ${pkg}" >/dev/null
    fi
}

# This is an alias function to intercept commands such as 'sudo apt install' and avoid silent failure
# on systems that don't have sudo - especially if it's being ran as root. Some systems don't have sudo, 
# but if this script is being ran as root anyway, then we can just bypass sudo anyway and run the raw command.
#
# If we are in-fact a normal user, then check if sudo is installed - alert the user if it's not.
# If sudo is installed, then forward the arguments to the real sudo command.
#
sudo() {
  # If user is not root, check if sudo is installed, then use sudo to run the command
  if [ "$EUID" -ne 0 ]; then
    if ! has_binary sudo; then
      msg bold red "ERROR: You are not root, and you don't have sudo installed. Cannot run command '${@:1}'"
      msg red "Please either install sudo and add your user to the sudoers group, or run this script as root."
      sleep 5
      return 3
    fi
    /usr/bin/env sudo "${@:1}"
    return $?
  fi
  # If we got to this point, then the user is already root, so just drop the 'sudo' and run it raw.
  /usr/bin/env "${@:1}"
}

[ -z ${SRCED_IDENT_SH+x} ] && source "${DIR}/identify.sh"

if [[ $(ident_shell) == "bash" ]]; then
    export -f sudo containsElement yesno pkg_not_found >/dev/null
elif [[ $(ident_shell) == "zsh" ]]; then
    export sudo containsElement yesno pkg_not_found >/dev/null
else
    msgerr bold red "WARNING: Could not identify your shell. Attempting to export with plain export..."
    export sudo containsElement yesno pkg_not_found >/dev/null
fi


