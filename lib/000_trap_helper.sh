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
# This file contains functions related to managing shell TRAP hooks.
#
# It's recommended to use the function 'add_on_exit' if you're adding standard "cleanup on exit"
# hooks, as it detects the shell and uses the appropriate exit hook for the detected shell.
#
# The function 'trap_add' allows you to append to a trap instead of overwriting it, and is 
# compatible with both bash and zsh. 
#
# The function 'get_trap_cmd' is primarily just a helper function for 'trap_add', but can
# be used on it's own, to read the code that would be ran for a specific trap signal on
# both bash and zsh.
#
# However, if used within zsh, you cannot view or append to the 'EXIT' trap, as 'EXIT' traps 
# are function local with zsh.
#
# -----------------------------------------------------------
#
# Most parts written by Someguy123 https://github.com/Someguy123
# Some parts copied from elsewhere e.g. StackOverflow - but often improved by Someguy123
#
#####################


# Check that both SG_LIB_LOADED and SG_LIBS exist. If one of them is missing, then detect the folder where this
# script is located, and then source map_libs.sh using a relative path from this script.
{ [ -z ${SG_LIB_LOADED[@]+x} ] || [ -z ${SG_LIBS[@]+x} ]; } && source "${_XDIR}/../map_libs.sh" || true
SG_LIB_LOADED[trap_helper]=1 # Mark this library script as loaded successfully
sg_load_lib logging colors # Check whether 'colors' and 'logging' have already been sourced, otherwise source them.

SG_SHELL="$(ident_shell)"

# Helper function for extracting trap command via get_trap_cmd
extract_trap_cmd() { (($#>2)) && printf '%s\n' "$3" || echo; }
# Get the function attached to a given trap signal
#
# WARNING: If you're using this function in ZSH, this does NOT work for the signal 'EXIT',
#          because 'EXIT' traps are always local to a zsh function
#
# Example:
#
#     $ trap "echo 'hello world';" INT
#     $ get_trap_cmd INT
#     echo 'hello world'
#
get_trap_cmd() {
    local trap_cmd="$1" trap_res list_traps

    if [[ "$SG_SHELL" == "bash" ]]; then 
        # For bash, we can directly query the trap signal using trap -p
        eval "extract_trap_cmd $(trap -p "$1")"
    elif [[ "$SG_SHELL" == "zsh" ]]; then
        # With zsh, we need to call 'trap', then scan it's output for the specific signal we're looking for
        trap | IFS= read -rd '' list_traps     
        trap_res=$(egrep ".* $trap_cmd\$" <<< "$list_traps")
        # Then extract just the command portion from the 'trap' output line.
        eval "extract_trap_cmd $trap_res"
    else
        fatal "[trap_add.get_trap_cmd] Unsupported shell "$SG_SHELL""
    fi
}

#######
# Appends a command to a trap signal. Works with both bash and zsh.
#
# WARNING: If using this function with ZSH, be aware that the signal 'EXIT' is local to a function.
#          Attempting to append to the 'EXIT' signal will simply cause the code to be ran immediately after
#          trap_add finishes.
#
# - 1st arg:  code to add
# - remaining args:  names of traps to modify
#
# Usage:
#    trap_add 'echo "in trap DEBUG and INT"' DEBUG INT
# 
# Source: https://stackoverflow.com/a/7287873/
#
trap_add() {
    trap_add_cmd=$1; shift || fatal "${FUNCNAME} usage error"
    for trap_add_name in "$@"; do
        trap_out="$(mktemp)"

        get_trap_cmd "$trap_add_name" > "$trap_out"
        _trap_cmd="$(cat $trap_out)"
        trap -- "$(printf '%s\n%s\n' "${_trap_cmd}" "${trap_add_cmd}")" "${trap_add_name}" \
            || exit_fatal "unable to add to trap ${trap_add_name}"
        rm -f "$trap_out" &>/dev/null
    done
}

# Same as trap_add, but adds the trap to the start of the command chain
# Important for traps that need to detect and handle errors, e.g. base/trap.bash
trap_prepend() {
    trap_add_cmd=$1; shift || fatal "${FUNCNAME} usage error"
    for trap_add_name in "$@"; do
        trap_out="$(mktemp)"

        get_trap_cmd "$trap_add_name" > "$trap_out"
        _trap_cmd="$(cat $trap_out)"
        trap -- "$(printf '%s\n%s\n' "${trap_add_cmd}" "${_trap_cmd}")" "${trap_add_name}" \
            || exit_fatal "unable to prepend to trap ${trap_add_name}"
        rm -f "$trap_out" &>/dev/null
    done
}

if [[ "$SG_SHELL" == "bash" ]]; then 
    declare -f -t trap_add
    declare -f -t trap_prepend
fi

#######
# Add a piece of code to execute when the script terminates.
#
# This function is for zsh scripts only. Use 'add_on_exit' if you want your script
# to be compatible with both zsh and bash
#
add_zshexit() {
    (($#<1)) && >&2 fatal "error: add_zshexit expects at least one argument (the code to run on zsh exit)"
    code="$1"
    _debug " >> Appending following code to run on exit:"
    _debug "# ================================"
    _debug "$code"
    _debug "# ================================"
    if [ -z ${functions[zshexit]+x} ]; then
        _debug " +++ zshexit did not yet exist. creating zshexit function."
        zshexit() { eval "$code"; }
    else
        _debug " +++ zshexit already exists. appending your code to the end."
        functions[zshexit]="
        $functions[zshexit]

        $code
        "
    fi
    echo
}

#######
# Add a piece of code to execute when the script terminates. (compatible with both bash and zsh)
#
#  - For bash, we use 'trap_add' to create / append to an EXIT trap
#  - For zsh, we use 'add_zshexit' to create / append to the zshexit function
#
# Example:
#
#     $ # You can either use plain shellscript code inside of a string
#     $ add_on_exit "echo 'hello world'"
#
#     $ # Or you can reference a function you've created
#     $ my_cleanup() { echo "running some sort-of cleanup..."; }
#     $ add_on_exit "my_cleanup"
#
add_on_exit() {
    (($#<1)) && >&2 fatal "error: add_on_exit expects at least one argument (the code to run on script exit)"
    local exit_cmd=$1
    if [[ "$SG_SHELL" == "bash" ]]; then 
        _debug "[add_on_exit] Detected shell BASH - appending to EXIT trap"
        trap_add "$exit_cmd" EXIT
    elif [[ "$SG_SHELL" == "zsh" ]]; then
        _debug "[add_on_exit] Detected shell ZSH - creating/appending to zshexit function"
        add_zshexit "$exit_cmd"
    else
        fatal "[trap_helper.add_on_exit] Unsupported shell "$SG_SHELL""
    fi
}
