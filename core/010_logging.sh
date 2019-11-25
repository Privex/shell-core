#!/usr/bin/sh

! [ -z ${ZSH_VERSION+x} ] && _SDIR=${(%):-%N} || _SDIR="${BASH_SOURCE[0]}"; _XDIR="$( cd "$( dirname "${_SDIR}" )" && pwd )"

# # Check that both SG_LIB_LOADED and SG_LIBS exist. If one of them is missing, then detect the folder where this
# # script is located, and then source map_libs.sh using a relative path from this script.
{ [ -z ${SG_LIB_LOADED[@]+x} ] || [ -z ${SG_LIBS[@]+x} ]; } && source "${_XDIR}/../map_libs.sh" || true
# Mark this library script as loaded successfully
SG_LIB_LOADED[logging]=1
sg_load_lib colors

: ${stderr_log="$(mktemp).log"}   # Randomly generated file in a temp folder for logging stderr into
: ${SG_DIR="${_SDIR}/.."}    # This is supposed to be set by init.sh. This is just in-case logging.sh is sourced on it's own...
: ${SG_DEBUG=0} # If set to 1, will enable debugging output to stderr
: ${DEBUGLOG="${SG_DIR}/logs/debug.log"}

DEBUGLOG_DIR=$(dirname "$DEBUGLOG")
[[ ! -d "$DEBUGLOG_DIR" ]] && mkdir -p "$DEBUGLOG_DIR" && touch "$DEBUGLOG"

#####
# Debugging output helper function.
#
# Outputs debugging messages with timestamps to $DEBUGLOG
# If $SG_DEBUG is 1 - then will also print any debugging messages to stderr
#
# Example:
#
#     _debug yellow "Warning: Something went wrong with x and y because..."
#
#####
_debug() {
    msg ts "$@" >> "$DEBUGLOG"
    ((SG_DEBUG<1)) && return
    msgerr ts "$@"
}

# Used by dependant scripts to check if this file has already been sourced
# e.g.    [ -z ${SRCED_LOG+x} ] && source "$SG_DIR/base/logging.sh"
SRCED_LOG=1

####
# Log stderr to '$stderr_log' using a named pipe (fifo) with tee, this allows us to log stderr
# and have it printed to the screen at the same time.
####
_sg_log_pipe=$(mktemp -u)
mkfifo "$_sg_log_pipe"
>&2 tee <"$_sg_log_pipe" "$stderr_log" &
# Backup the stderr descriptor (2) into descriptor 4 for later restoration
exec 4>&2 2> "$_sg_log_pipe"


log() { 
    >&4 msgts "$@";
}
error() { log "ERROR: $@"; }

fatal() { error "$@"; return 1; }

exit_fatal() { error "$@"; exit 1; }

