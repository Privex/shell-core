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
# This long bash script adds automatic detailed error handling to any bash script, including:
#
#   - A function traceback, similar to Python
#   - Shows the numeric error code and the file which triggered the error
#   - Shows the line number which caused the error (if known)
#   - Prints the function / line of code believed to have triggered the error (if known)
#   - Shows the error message related to the error (if known)
#
# Simply source this file in your bash script and you're done :)
# You can raise custom errors using `raise_error` if needed.
#
# If something isn't working correctly with this error handling, set `enable_trap_debug=1` in your shell.
#
#    export enable_trap_debug=1
#
# This will enable detailed debugging messages (outputted to stderr) helping you to diagnose
# which part is going wrong.
#
# =========================================================================================================
#
# Usage (from within an application already using ShellCore):
#     
#     source "${SG_DIR}/base/trap.bash"
#
# If you need to temporarily disable the error handling:
#
#     somefunc() {   # This is an example function which always returns 1 (a non-zero exit code to trigger errors)
#         return 1
#     }
#     otherfunc() {
#         error_control 1   # Ignore the following non-zero return, but handle any non-zero returns after this.
#         somefunc          # This non-zero returning function would work the first time
#         somefunc          # ...but trigger a fatal error the second time, as error handling would be re-enabled.
#
#         # To disable error handling semi-permanently, pass 2 instead of 1, which disables error handling
#         # until you manually re-enable it with 'error_control 0'
#         error_control 2
#
#         # We can now run somefunc 3 times, despite the non-zero return codes
#         somefunc; somefunc; somefunc;
#
#         error_control 0   # Re-enable error handling
#         somefunc          # This will trigger the error handler now, as error handling has been re-enabled.
#     }
#
# =========================================================================================================
#
# This trap error handling code was originally found on StackOverflow here:
#   https://stackoverflow.com/a/13099228
# Originally written by Luca Borrione on StackOverflow:
#   https://stackoverflow.com/users/1032370/luca-borrione
#
# Modified by Chris (@someguy123) @ Privex Inc. ::
#
#   - Better POSIX compatibility, so it works on both Linux and OSX
#   - Added FIFO named pipes so that stderr can be printed at the same time as being logged
#   - Added _trap_debug to assist with debugging this trap error handling system
#   - Improved detection of the file / line which caused the error
#   - Prints the line of code which triggered the error, if known
#   - Added `raise_err` function for custom error handling
#   - Improved readability of error output
#
#############################################################

lib_name='trap'
lib_version=20191008

: ${enable_trap_debug=0}   # 0 = disable debugging messages, 1 = enable debugging messages
: ${trap_debug_stderr=1}   # 0 = output debugging messages to stdout // 1 = output debugging to stderr
: ${stderr_log="$(mktemp).log"}   # Randomly generated file in a temp folder for logging stderr into

# Set this to 1 within a function to ignore the next non-zero return code. Automatically re-set's to 0 after a non-zero.
# Set to 2 to permanently ignore non-zero return codes until you manually reset IGNORE_ERR back to 0
export IGNORE_ERR=0

#
# TO BE SOURCED ONLY ONCE:
#
###~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##

if (("${g_libs[$lib_name]+_}")); then
    return 0
else
    if ((${#g_libs[@]}==0)); then
        declare -A g_libs
    fi
    g_libs[$lib_name]=$lib_version
fi

_TRAP_LAST_LINE=""
_TRAP_LAST_CALLER=""
_TRAP_ERR_CALL=0
: ${SRCED_000LOG=""}

! [ -z ${ZSH_VERSION+x} ] && _SDIR=${(%):-%N} || _SDIR="${BASH_SOURCE[0]}"
__TRAP_DIR="$( cd "$( dirname "${_SDIR}" )" && pwd )"
# __DIR="$__TRAP_DIR"
# Check that both SG_LIB_LOADED and SG_LIBS exist. If one of them is missing, then detect the folder where this
# script is located, and then source map_libs.sh using a relative path from this script.
{ [ -z ${SG_LIB_LOADED[@]+x} ] || [ -z ${SG_LIBS[@]+x} ]; } && source "${__TRAP_DIR}/../map_libs.sh" || true
SG_LIB_LOADED[trap]=1 # Mark this library script as loaded successfully
# Check whether 'colors', 'trap_helper' and 'logging' have already been sourced, otherwise source em.
sg_load_lib trap_helper colors logging
# source "${__TRAP_DIR}/colors.sh"

_trap_debug () {
    local dbg_msg="[DEBUG trap.bash]${RESET} $@" 
    (($enable_trap_debug==0)) || { (($trap_debug_stderr==0)) && msg ts yellow "$dbg_msg" || msgerr ts yellow "$dbg_msg"; }
}

#
# MAIN CODE:
#
###~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##

set -o pipefail  # trace ERR through pipes
set -o errtrace  # trace ERR through 'time command' and other functions
set -o nounset   ## set -u : exit the script if you try to use an uninitialised variable
set -o errexit   ## set -e : exit the script if any statement returns a non-true return value

# ####
# # Log stderr to '$stderr_log' using a named pipe (fifo) with tee, this allows us to log stderr
# # and have it printed to the screen at the same time.
# ####
# _trap_log_pipe=$(mktemp -u)
# mkfifo "$_trap_log_pipe"
# >&2 tee <"$_trap_log_pipe" "$stderr_log" &
# # Backup the stderr descriptor (2) into descriptor 4 for later restoration
# exec 4>&2 2> "$_trap_log_pipe"

# [ -z ${SRCED_000LOG} ] && source "$SG_DIR/lib/000_logging.sh"


_handle_ignore_err () {
    (($IGNORE_ERR==1)) && IGNORE_ERR=0 && _trap_debug "Ignoring error (1)" && set -eE && return 1
    (($IGNORE_ERR==2)) && _trap_debug "Ignoring error (2)" && return 1
    # IGNORE_ERR 5 is set by `error_control` so that error_control returning doesn't cause IGNORE_ERRORS to be reset back to 0
    (($IGNORE_ERR==5)) && IGNORE_ERR=1 && _trap_debug "Resetting IGNORE_ERRORS to 1" && return 1
    return 0
}


error_control () {
    # Enable/Disable automatic error handling and bash exit-on-err setting.
    # Argument 1:
    #   0 = handle errors  1 = ignore the next non-zero error   2 = ignore errors until manually changed back to normal
    #
    # Example:
    #     somefunc() {
    #         error_control 1   # Ignore the following non-zero return, but handle any non-zero returns after this.
    #         return 1
    #     }
    #
    # If no ignore code was passed as the first arg, then just flip IGNORE_ERR
    # between 0 (handle errors) and 1 (ignore the next non-zero code), plus enable/disable the 'eE' flags.
    if (($#==0)); then
        if (($IGNORE_ERR==0)); then
            set +eE
            IGNORE_ERR=5
            return
        fi
        set -eE
        IGNORE_ERR=0
        return
    fi
    (($1==1)) && IGNORE_ERR=5 || IGNORE_ERR=$(($1))
    _trap_debug "Set IGNORE_ERR to $IGNORE_ERR"
    (($1==0)) && set -eE || set +eE
}

function raise_error () {
    # Outputs an error message to stderr in bash error format, then calls `exit`. This allows the trap function
    # `exit_handler` to correctly display the error in a user readable format.
    #
    # All arguments are optional, but the message, script, and line number strongly recommended for accurate error details.
    #
    # Usage:
    #   raise_error [message] [your_script] [line_num] [exit_code]
    # Example:
    #   raise_error "Error while doing x" "${BASH_SOURCE[0]}" $LINENO
    #
    local _caller="$(basename $0)" _lnum="line 0" _errmsg="An unknown error occurred, but no message was given."
    local _excode=1

    (($#>0)) && _errmsg="$1"; (($#>1)) && _caller="$2"; (($#>2)) && _lnum="line $3"; (($#>3)) && _excode=$(($4))
    >&2 echo "${_caller}: ${_lnum}: ${_errmsg}"
    exit $_excode
}

###~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##
#
# FUNCTION: EXIT_HANDLER
#
###~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##

function exit_handler ()
{
    local error_code="$?"
    _handle_ignore_err || return
    # Restore stderr descriptor (2) from the copy we made in descriptor 4
    exec 2>&4


    # msgerr "code: $error_code arg 1: $1   arg 2: $2"
    _trap_debug "Logging stderr to file: $stderr_log"
    _trap_debug "Running exit handler"
    (($error_code==0)) && _trap_debug "Return code 0 - ignoring." && return;
    _trap_debug "Non-zero return code"
    #
    # LOCAL VARIABLES:
    # ------------------------------------------------------------------
    #    
    local i=0
    local regex=''
    local mem=''

    local error_file="$(basename $0)"
    local error_lineno=''
    local error_message='unknown'
    local error_func=''

    local lineno=''

    #
    # PRINT THE HEADER:
    # ------------------------------------------------------------------
    #
    msgerr bold red "\n(!) ERROR HANDLER:\n"


    #
    # GETTING LAST ERROR OCCURRED:
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #

    #
    # Read last file from the error log
    # ------------------------------------------------------------------
    #
    if [ -f "$stderr_log" ]; then
        _trap_debug "Found log at $stderr_log"
        stderr=$( tail -n 1 "$stderr_log" )
        _trap_debug "Log last line: $stderr"
        if (($enable_trap_debug==1)); then
            _trap_debug "Not deleting error log file as 'enable_trap_debug' is enabled."
            _trap_debug "Full stderr log can be found at: $stderr_log"
        else
            rm "$stderr_log"
        fi
    fi

    #
    # Managing the line to extract information:
    # ------------------------------------------------------------------
    #

    if [ -n "$stderr" ]; then
        _trap_debug "\$stderr not empty."
        ####
        # This 'if' block parses the standard bash error output format from the stderr log, which looks like this:
        #   ./run.sh: line 192: unexpected error removing comments
        ### 
        # Exploding stderr on :
        mem="$IFS"
        local shrunk_stderr=$( echo "$stderr" | sed -E 's/\: /\:/g' )
        IFS=':'
        local stderr_parts=( $shrunk_stderr )
        IFS="$mem"
        # Storing information on the error
        if ((${#stderr_parts[@]}>=2)); then
            _trap_debug "Extracting file/line no from parts: ${stderr_parts[@]}"
            error_file="${stderr_parts[0]}"
            (($_TRAP_ERR_CALL==0)) && error_lineno="${stderr_parts[1]}"
            error_message=""

            _trap_debug "Building error_message from stderr_parts"
            for (( i = 3; i <= ${#stderr_parts[@]}; i++ )); do
                error_message="$error_message "${stderr_parts[$i-1]}": "
            done

            # Removing last ':' (colon character)
            error_message="${error_message%:*}"

            # Trim
            _trap_debug "Trimming error_message with sed"
            error_message="$( echo "$error_message" | sed -E 's/^[ \t]*//' | sed -E 's/[ \t]*$//' )"
        else
            _trap_debug "Not extracting file/line as not enough stderr_parts: ${stderr_parts[@]}"
        fi
    fi

    _trap_debug "Getting backtrace"
    #
    # GETTING BACKTRACE:
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
    _backtrace=$( backtrace 2 )


    #
    # MANAGING THE OUTPUT:
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
    _trap_debug "Parsing error data with regex"
    local lineno=""
    regex='^([a-z]{1,}) ([0-9]{1,})$'

    if [[ $error_lineno =~ $regex ]]; then
        _trap_debug "error line number (error_lineno) was found"
        # The error line was found on the log
        # (e.g. type 'ff' without quotes wherever)
        # --------------------------------------------------------------
    
        local row="${BASH_REMATCH[1]}"
        lineno="${BASH_REMATCH[2]}"

        msgerr white "FILE:\t\t${error_file}"
        msgerr white "${row^^}:\t\t${lineno}\n"

        msgerr white "ERROR CODE:\t${error_code}"             
        msgerr yellow "ERROR MESSAGE:\n"
        msgerr white "\t$error_message\n"

    else
        regex="^${error_file}\$|^${error_file}\s+|\s+${error_file}\s+|\s+${error_file}\$"
        _trap_debug "error line number (error_lineno) NOT found. scanning backtrace with regex: $regex"
        if [[ "$_backtrace" =~ $regex ]]; then
            _trap_debug "_backtrace matched regex"
            # The file was found on the log but not the error line
            # (could not reproduce this case so far)
            # ------------------------------------------------------
        
            msgerr white "FILE:\t\t$error_file"
            msgerr white "ROW:\t\tunknown\n"

            msgerr white "ERROR CODE:\t${error_code}"
            msgerr yellow "ERROR MESSAGE:\n"
            msgerr white "\t${stderr}\n"
        else
            _trap_debug "_backtrace did not match regex..."
            # Neither the error line nor the error file was found on the log
            # (e.g. type 'cp ffd fdf' without quotes wherever)
            # ------------------------------------------------------
            #
            # The error file is the first on backtrace list:

            # Exploding backtrace on newlines
            mem=$IFS
            IFS='
            '
            #
            # Substring: I keep only the carriage return
            # (others needed only for tabbing purpose)
            IFS=${IFS:0:1}
            local lines=( $_backtrace )

            IFS=$mem


            if [ -n "${lines[1]}" ]; then
                array=( ${lines[1]} )
                _trap_debug "Lines are: ${lines[1]}"
                _trap_debug "Array is: ${array[@]}"
                # if ((${#array[@]}))
                error_file=""
                for (( i=2; i<${#array[@]}; i++ ))
                    do
                        _trap_debug "appending to error_file: $error_file --- value: ${array[$i]}"
                        error_file="$error_file ${array[$i]}"
                done
                _trap_debug "out of loop error_file: $error_file"
                # Trim
                error_file="$( echo "$error_file" | sed -E 's/^[ \t]*//' | sed -E 's/[ \t]*$//' )"
            fi

            msgerr white "FILE:\t\t$error_file"
            if (($_TRAP_ERR_CALL==1)); then
                msgerr white "ROW:\t\t$_TRAP_LAST_LINE\n"
                msgerr white "Line which triggered the error:\n\n\t$_TRAP_LAST_CALLER\n\n"
            else
                msgerr white "ROW:\t\tunknown\n"
            fi

            msgerr white "ERROR CODE:\t${error_code}"
            if [ -n "${stderr}" ]; then
                msgerr yellow "ERROR MESSAGE:\n"
                msgerr white "\t${stderr}\n"
            else
                msgerr yellow "ERROR MESSAGE:\n"
                msgerr white "\t${error_message}\n"
            fi
        fi
    fi
    _trap_debug "Attempting to print backtrace"
    #
    # PRINTING THE BACKTRACE:
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #

    msgerr bold blue "\nTraceback:"
    # msgerr bold "\n$_backtrace\n"
    msgerr bold "\n$(trap_traceback 1)\n"

    #
    # EXITING:
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #

    msgerr bold red "Exiting!"

    exit "$error_code"
}

trap_err_handler() {
    local _ret="$?"
    (($_ret==0)) && return
    _handle_ignore_err || return
    
    _TRAP_LAST_LINE="$1"
    _TRAP_LAST_CALLER="$2"
    _TRAP_ERR_CALL=1
    exit $_ret
}

trap_prepend 'exit_handler' EXIT                                    # ! ! ! TRAP EXIT ! ! !
trap_prepend 'trap_err_handler ${LINENO} "$BASH_COMMAND"' ERR       # ! ! ! TRAP ERR ! ! !


###~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##
#
# FUNCTION: BACKTRACE
#
###~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##

function backtrace
{
    local _start_from_=0

    local params=( "$@" )
    if (( "${#params[@]}" >= "1" )); then
        _start_from_="$1"
    fi

    local i=0
    local first=0
    while caller $i > /dev/null
    do
        if [ -n "$_start_from_" ] && (( "$i" + 1   >= "$_start_from_" )); then
                if (($first==0));then
                    first=1
                fi
                echo "    $(caller $i)"
        fi
        let "i=i+1"
    done
}


function trap_traceback
{
  # Hide the trap_traceback() call.
  local -i start=$(( ${1:-0} + 1 ))
  local -i end=${#BASH_SOURCE[@]}
  local -i i=0
  local -i j=0

  for ((i=start; i < end; i++)); do
    j=$(( i - 1 ))
    local function="${FUNCNAME[$i]}"
    local file="${BASH_SOURCE[$i]}"
    local line="${BASH_LINENO[$j]}"
    echo "     ${function}() in ${file}:${line}"
  done
}

return 0
