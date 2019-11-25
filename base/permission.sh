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

! [ -z ${ZSH_VERSION+x} ] && _SDIR=${(%):-%N} || _SDIR="${BASH_SOURCE[0]}"
_XDIR="$( cd "$( dirname "${_SDIR}" )" && pwd )"

# Check that both SG_LIB_LOADED and SG_LIBS exist. If one of them is missing, then detect the folder where this
# script is located, and then source map_libs.sh using a relative path from this script.
{ [ -z ${SG_LIB_LOADED[@]+x} ] || [ -z ${SG_LIBS[@]+x} ]; } && source "${_XDIR}/../map_libs.sh" || true
SG_LIB_LOADED[permission]=1 # Mark this library script as loaded successfully
sg_load_lib colors # Check whether 'colors' has already been sourced, otherwise source it.

# [ -z ${SRCED_COLORS+x} ] && source "${DIR}/colors.sh"

#####
# Check if there are directory permissions issues affecting access to a file.
# Based on the StackOverflow answer https://unix.stackexchange.com/a/82349 and modified by Someguy123 into a function 
# with return codes and zsh compatibility.
#
# If there's a problem, it prints a red message to stderr specifying the first directory in the path which is non-executable.
#
# Example:
#     if path_permission "/root/.ssh/authorized_keys"; then
#          # do something with the file, maybe further read/write checks
#     else
#          >&2 echo "Could not access /root/.ssh/authorized_keys due to a directory being non-executable"
#     fi
#
#####
path_permission() {
    local pm_file="$1" pm_path="" part parts
    [[ "$pm_file" != /* ]] && pm_path="."
    parts=($(dirname "$pm_file" | tr '/' $'\n'))
    for part in "${parts[@]}"; do
        pm_path="$pm_path/$part"
        # Check for execute permissions
        if ! [[ -x "$pm_path" ]] ; then
            msgerr red "Cannot access file/folder '$pm_file' because '$pm_path' isn't +x - please run 'sudo chmod +x \"$pm_path\"' to resolve this."
            return 1
        fi
    done
    return 0
}

#####
# can_read [file|folder]
# Check if we have read permission to a file/folder, while also checking that each folder in the path
# is executable - alerts with a red message to stderr if a folder in the path is not executable.
#####
can_read() {
    path_permission "$1" && [ -r "$1" ] && return 0 || return 1
}

#####
# can_write [file|folder]
# Check if we have write permission to a file/folder, while also checking that each folder in the path
# is executable - alerts with a red message to stderr if a folder in the path is not executable.
#####
can_write() {
    path_permission "$1" && [ -w "$1" ] && return 0 || return 1
}

