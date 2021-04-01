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

S_CORE_VER="0.5.0"    # Used by sourcing scripts to identify the current version of Privex's Shell Core.


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

_ENV_CLEAN_BLACKLIST=('SG_DEBUG')

last_update_shellcore() {
    if [[ -f "${SG_DIR}/.last_update" ]]; then
        __sg_lst=$(cat "$SG_LAST_UPDATE_FILE")
        SG_LAST_UPDATE=$(($__sg_lst))
    fi
}

last_update_shellcore

update_shellcore() { bash "${SG_DIR}/run.sh" update; }
autoupdate_shellcore() {
    last_update_shellcore
    local _unix_now=$(date +'%s') 
    local unix_now=$(($_unix_now)) next_update=$((SG_LAST_UPDATE+SG_UPDATE_SECS))
    local last_rel=$((unix_now-SG_LAST_UPDATE))
    if (($next_update<$unix_now)); then
        _debug green "Last update was $last_rel seconds ago. Auto-updating Privex ShellCore."
        update_shellcore
    else
        _debug yellow "Auto-update requested, but last update was $last_rel seconds ago (next update due after ${SG_UPDATE_SECS} seconds)"
    fi
}

# DEBUGLOG_DIR=$(dirname "$DEBUGLOG")
# [[ ! -d "$DEBUGLOG_DIR" ]] && mkdir -p "$DEBUGLOG_DIR" && touch "$DEBUGLOG"

source "${SG_DIR}/map_libs.sh"


#########
# First we source essential "base" scripts, which provide important functions that
# are used by this init script itself.
#########

sg_load_lib logging colors permission trap_helper



cleanup_env() {
    _debug "[init.cleanup_env] Unsetting any leftover variables"
    clean_env_prefix "SG_"
    clean_env_prefix "SRCED_"
}

####
# Unset all env vars starting with $1 - works with both bash and zsh
# Example:
#     # Would unset SG_DEBUG, SG_DIR, SG_GLOBALDIR etc.
#     clean_env_prefix "SG_"
#
clean_env_prefix() {
    local clean_vars _prefix="$1"
    (($#<1)) && fatal "Usage: clean_env_prefix [prefix]"
    if [[ $(ident_shell) == "bash" ]]; then
        mapfile -t clean_vars < <(set | grep -E "^${_prefix}" | sed -E 's/^('${_prefix}'[a-zA-Z0-9_]+)(\=.*)$/\1/')
        for v in "${clean_vars[@]}"; do
            if ! containsElement "$v" "${_ENV_CLEAN_BLACKLIST[@]}"; then
                _debug "[cleanup_env_prefix] [bash ver] Unsetting variable: $v"
                unset "$v"
            else
                _debug "[cleanup_env_prefix] [bash ver] Skipping blacklisted variable: $v"
            fi
        done
    elif [[ $(ident_shell) == "zsh" ]]; then
        _debug "[cleanup_env_prefix] [zsh ver] Unsetting all variables with pattern: ${_prefix}*"
        unset -m "${_prefix}*"
    else
        fatal "Function 'clean_env_prefix' is only compatible with bash or zsh. Detected shell: $(ident_shell)"
        return 1
    fi
}

add_on_exit "cleanup_env"

