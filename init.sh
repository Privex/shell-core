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

export S_CORE_VER="0.1.2"    # Used by sourcing scripts to identify the current version of Privex's Shell Core.


######
# Directory where the script is located, so we can source files regardless of where PWD is
######

# Detect shell, locate relative path to script, then use dirname/cd/pwd to find
# the absolute path to the folder containing this script.
! [ -z ${ZSH_VERSION+x} ] && _SDIR=${(%):-%N} || _SDIR="${BASH_SOURCE[0]}"
DIR="$( cd "$( dirname "${_SDIR}" )" && pwd )"

# SG_DIR holds the absolute path to where Privex SH-CORE is installed.
# If not set in the environment, it defaults to the folder containing this script.
: ${SG_DIR="$DIR"}
: ${SG_LAST_UPDATE_FILE="${SG_DIR}/.last_update"}

: ${SG_DEBUG=0} # If set to 1, will enable debugging output to stderr
: ${DEBUGLOG="${SG_DIR}/logs/debug.log"}

: ${SG_LOCALDIR="${HOME}/.pv-shcore"}            # Folder to install Privex Shell Core for local installs
: ${SG_GLOBALDIR="/usr/local/share/pv-shcore"}   # Folder to install Privex Shell Core for global installs
# How many seconds must've passed since the last update to trigger an auto-update
: ${SG_UPDATE_SECS=604800}
SG_LAST_UPDATE=0

export SG_DIR SG_LOCALDIR SG_GLOBALDIR DEBUGLOG SG_DEBUG

last_update_shellcore() {
    if [[ -f "${SG_DIR}/.last_update" ]]; then
        __sg_lst=$(cat "$SG_LAST_UPDATE_FILE")
        export SG_LAST_UPDATE=$(($__sg_lst))
    fi
}

last_update_shellcore

update_shellcore() { bash "${SG_DIR}/run.sh" update; }
autoupdate_shellcore() {
    last_update_shellcore
    local _unix_now=$(date +'%s') unix_now=$(($_unix_now)) next_update=$((SG_LAST_UPDATE+SG_UPDATE_SECS))
    local last_rel=$((unix_now-SG_LAST_UPDATE))
    if (($next_update<$unix_now)); then
        _debug green "Last update was $last_rel seconds ago. Auto-updating Privex ShellCore."
        update_shellcore
    else
        _debug yellow "Auto-update requested, but last update was $last_rel seconds ago (next update due after ${SG_UPDATE_SECS} seconds)"
    fi
}

DEBUGLOG_DIR=$(dirname "$DEBUGLOG")
[[ ! -d "$DEBUGLOG_DIR" ]] && mkdir -p "$DEBUGLOG_DIR" && touch "$DEBUGLOG"

#########
# First we source essential "base" scripts, which provide important functions that
# are used by this init script itself.
#########

source "${SG_DIR}/base/identify.sh"
source "${SG_DIR}/base/colors.sh"
source "${SG_DIR}/base/permission.sh"


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
    msg ts "$@" >> "$DEBUGLOG";
    (($SG_DEBUG!=1)) && return
    msgerr ts "$@"
}

