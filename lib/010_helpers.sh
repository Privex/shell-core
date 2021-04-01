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
# Several helpers were refactored out of this file into
#   core/000_core_func.sh
# Including: 
#   len has_command has_binary ident_shell sudo
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
SG_LIB_LOADED[helpers]=1 # Mark this library script as loaded successfully
sg_load_lib logging colors # Check whether 'colors' and 'logging' have already been sourced, otherwise source them.


# Remove any lines containing 'source xxxx.sh'
remove_sources() { sed -E "s/.*source \".*\.sh\".*//g" "$@"; }

# Compress instances of more than one blank line into a singular blank line
# Unlike "tr -s '\n'" this will only compact multiple blank lines into one, instead of
# removing blank lines entirely.
compress_newlines() { cat -s "$@"; }

# Trim newlines down to singular newlines (no blank lines allowed)
remove_newlines() { tr -s '\n'; }

# Remove any comments starting with '#'
remove_comments() { sed -E "s/^#.*//g" "$@" | sed -E "s/^[[:space:]]+#.*//g"; }

# Trim away any /usr/bin/* or /bin/* shebangs - either pipe in data, or pass filename as argument
remove_shebangs() { sed -E "s;^#!/usr/bin.*$;;" "$@" | sed -E "s;^#!/bin.*$;;"; }


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
: ${PKG_MGR_UPDATE="apt-get update -qy"}
# The command used to install a package - where the package name would be
# specified as the first argument following the command.
: ${PKG_MGR_INSTALL="apt-get install -y"}

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

# Split argument 1 by argument 2, then output the elements separated by newline, allowing you to split a string
# into an array
#
# For associative arrays (AKA dictionaries / hashes), see split_assoc in 015_bash_helpers.bash 
# (split_assoc is only compatible with bash)
#
# Usage:
#
#     $ x='hello-world-one-two-three'
#     # Split variable $x into a bash/zsh array by the dash "-" character
#     $ x_data=($(split_by "$x" "-"))
#     $ echo "${x_data[0]}"
#     hello
#     $ echo "${x_data[1]}"
#     world
#
split_by() {
    if (($# != 2)); then
        echo >&2 "Error: split_by requires exactly 2 arguments"
        return 1
    fi
    local split_data="$1" split_sep="$2" data_splitted

    # Backup the field separator so we can restore it once we're done splitting.
    _IFS="$IFS"
    IFS="$split_sep"
    if [[ $(ident_shell) == "bash" ]]; then
        read -a data_splitted <<<"$split_data"
    elif [[ $(ident_shell) == "zsh" ]]; then
        setopt sh_word_split
        data_splitted=($split_data)
        setopt +o sh_word_split
    else
        fatal "Function 'split_by' is only compatible with bash or zsh. Detected shell: $(ident_shell)"
        return 1
    fi

    echo "${data_splitted[@]}"

    IFS="$_IFS"
}



# Split argument 1 into an associative array (AKA dictionary / hash), separating each pair by arg 2, 
# and the key/value by arg 3.
# You must source the file location which is outputted to stdout, as bash does not support exporting 
# associative arrays. The sourced file will add the associative array 'assoc_result' to your shell.
# 
# Usage:
#   NOTE: Due to limitations in both bash and zsh, associative arrays cannot be exported. 
#   As a workaround, the associative array is serialized into a temporary file, and the tempfile location 
#   is printed from the function.
#   You can then source this to load the associative array into your current function, or globally.
#
#   In the below example, we split each "item" by commas, then split items into keys and values by ":".
#
#   $ x="hello:world,lorem:ipsum,dolor:orange"
#   $ source $(split_assoc "$x" "," ":")
#   $ echo "${assoc_result[hello]}"
#   world
#
#   If you want to rename / copy the associative array to a different variable name, you must declare your own
#   array and loop over the result array.
#
#   $ declare -A my_arr
#   $ for key in "${!assoc_result[@]}"; do
#         my_arr["$key"]="${assoc_result["$key"]}"
#     done
#
# shellcheck disable=SC2207
split_assoc() {
    if (($# != 3)); then
        echo >&2 "Error: split_assoc requires exactly 3 arguments"
        return 1
    fi

    local split_data="$1" item_sep="$2" keyval_sep="$3" s_rows row s_cols

    s_rows=($(split_by "$split_data" "$item_sep"))
    declare -A assoc_result
    export assoc_output="$(mktemp)"

    for row in "${s_rows[@]}"; do
        _debug "Row is: $row"
        s_cols=($(split_by "$row" "$keyval_sep"))
        _debug "s_cols is:" ${s_cols[@]}

        num_cols="${#s_cols[@]}"
        num_cols=$((num_cols))
        if ((num_cols != 2)); then
            _debug "Warning: split_assoc row does not have 2 columns (has ${num_cols}): '${s_cols[*]}'"
            continue
        fi
        if [[ $(ident_shell) == "bash" ]]; then
            assoc_result[${s_cols[0]}]="${s_cols[1]}"
        elif [[ $(ident_shell) == "zsh" ]]; then
            assoc_result[${s_cols[1]}]="${s_cols[2]}"
        else
            fatal "Function 'split_assoc' is only compatible with bash or zsh. Detected shell: $(ident_shell)"
            return 1
        fi
        

    done
    # Serialize the associative array to the temporary file, then print the temp file location to stdout.
    # Source: https://stackoverflow.com/a/55317015
    declare -p assoc_result >"$assoc_output"
    echo "$assoc_output"
}

# rm-extension [path]
# Remove the last extension from a filename/path and output the individual filename
# without the last extension
#
#     $ rm-extension /backups/mysql/2021-03-17.tar.lz4
#     2021-03-17.tar
#
rm-extension() {
    local fname=$(basename -- "$1")
    echo "${fname%.*}"
}

# get-extension [path]
# Extract the last extension from a filename/path and output it.
#
#     $ get-extension /backups/mysql/2021-03-17.tar.lz4
#     lz4
#
get-extension() {
    local fname=$(basename -- "$1")
    echo "${fname##*.}"
}


if [[ $(ident_shell) == "bash" ]]; then
    export -f sudo containsElement yesno pkg_not_found split_by split_assoc rm-extension get-extension >/dev/null
elif [[ $(ident_shell) == "zsh" ]]; then
    export sudo containsElement yesno pkg_not_found split_by split_assoc rm-extension get-extension >/dev/null
else
    msgerr bold red "WARNING: Could not identify your shell. Attempting to export with plain export..."
    export sudo containsElement yesno pkg_not_found split_by split_assoc rm-extension get-extension >/dev/null
fi


