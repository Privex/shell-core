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
# This file contains an associative array, mapping "libraries"
# to their respective file to assist with sourcing them,
# and ensure that they're only loaded once.
#
#############################################################

# Detect shell, locate relative path to script, then use dirname/cd/pwd to find
# the absolute path to the folder containing this script.
! [ -z ${ZSH_VERSION+x} ] && _SDIR=${(%):-%N} || _SDIR="${BASH_SOURCE[0]}"
DIR="$( cd "$( dirname "${_SDIR}" )" && pwd )"

: ${SG_DIR="$DIR"}
: ${SRCED_SGCORE=0}
: ${SG_DEBUG=0}
# : ${SG_DEBUG=0} # If set to 1, will enable debugging output to stderr

if ((SRCED_SGCORE<1)); then
    source "${SG_DIR}/core/000_core_func.sh"
fi


# Small shim in-case logging isn't loaded yet.
if ! has_command _debug; then 
    _debug() { ((SG_DEBUG<1)) && return; echo "$@"; } 
fi


: ${DEBUGLOG="${SG_DIR}/logs/debug.log"}

# DEBUGLOG_DIR=$(dirname "$DEBUGLOG")
# [[ ! -d "$DEBUGLOG_DIR" ]] && mkdir -p "$DEBUGLOG_DIR" && touch "$DEBUGLOG"

if [ -z ${SG_LIB_LOADED[@]+x} ]; then
    _debug "[map_libs.sh] SG_LIB_LOADED not set. Declaring SG_LIB_LOADED assoc array."
    declare -A SG_LIB_LOADED
    SG_LIB_LOADED=(
        [colors]=0 [identify]=0 [permission]=0 [traplib]=0
        [logging]=0 [core_func]=1
        [gnusafe]=0 [trap_helper]=0 [helpers]=0 [datehelpers]=0
    )
fi
if [ -z ${SG_LIBS[@]+x} ]; then
    _debug "[map_libs.sh] SG_LIBS not set. Declaring SG_LIBS assoc array."
    declare -A SG_LIBS

    # We don't quote the keys - while bash ignores quotes, zsh treats them literally and would
    # require that the keys are accessed with the same quote style as they were set.
    SG_LIBS=( 
        [colors]="${SG_DIR}/base/colors.sh" [identify]="${SG_DIR}/base/identify.sh"
        [logging]="${SG_DIR}/core/010_logging.sh" [permission]="${SG_DIR}/base/permission.sh"
        [traplib]="${SG_DIR}/base/trap.bash"
        [gnusafe]="${SG_DIR}/lib/000_gnusafe.sh" [trap_helper]="${SG_DIR}/lib/000_trap_helper.sh"
        [helpers]="${SG_DIR}/lib/010_helpers.sh" [datehelpers]="${SG_DIR}/lib/020_date_helpers.sh"
    )
fi

sg_load_lib() {
    (( $# < 1 )) && { >&2 msgerr "[ERROR] sg_load_lib expects at least one argument!" && return 1; }
    local a
    for a in "$@"; do
        [[ "$a" == "trap" ]] && a="traplib"
        if (( ${SG_LIB_LOADED[$a]} < 1 )); then
            _debug "[map_libs.sg_load_lib] Loading library '$a' from location '${SG_LIBS[$a]}' ..."
            source "${SG_LIBS[$a]}"
        else
            _debug "[map_libs.sg_load_lib] Library '$a' is already loaded..."
        fi
    done
}

sg_load_lib logging



#################
# Using map_libs.sh inside of a ShellCore module inside of base/ core/ or lib/
#
#   # Check that both SG_LIB_LOADED and SG_LIBS exist. If one of them is missing, then detect the folder where this
#   # script is located, and then source map_libs.sh using a relative path from your script.
#   { [ -z ${SG_LIB_LOADED[@]+x} ] || [ -z ${SG_LIBS[@]+x} ] } && {
#       ! [ -z ${ZSH_VERSION+x} ] && _SDIR=${(%):-%N} || _SDIR="${BASH_SOURCE[0]}"; _XDIR="$( cd "$( dirname "${_SDIR}" )" && pwd )";
#       source "${_XDIR}/../map_libs.sh"
#   } || true
#
#   # Mark this library script as loaded successfully
#   SG_LIB_LOADED[somelib]=1
#
#   # Ensure any libraries you plan to use are loaded. If they were already sourced, then they won't be loaded again.
#   sg_load_lib colors permission gnusafe



