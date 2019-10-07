#!/usr/bin/env sh
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

 
######
# Directory where the script is located, so we can source files regardless of where PWD is
######
! [ -z ${ZSH_VERSION+x} ] && _SDIR=${(%):-%N} || _SDIR="${BASH_SOURCE[0]}"
DIR="$( cd "$( dirname "${_SDIR}" )" && pwd )"

source "${DIR}/init.sh"

#########
# First we load "cross-platform/shell" modules - which are files ending in the generic '.sh' extension. 
# These should be at least compatible with both bash and zsh
#########
_debug green " (+) Loading cross-platform/shell files from ${SG_DIR}\n"

for f in "${SG_DIR}/lib"/*.sh; do
    _debug yellow "    -> Sourcing file $f"
    source "$f"
done

#########
# Now we identify the shell we're currently running inside of, so that we can 
# source shell-exclusive modules - i.e. ones which only run on either zsh or bash, not both. 
#########

ident_shell >/dev/null 

if [[ "$CURRENT_SHELL" == "bash" ]]; then
    _debug green " (+) Detected shell 'bash'. Loading bash-specific files.\n"
    for f in "${SG_DIR}/lib"/*.bash; do
        [ -e "$f" ] || continue
        _debug yellow "    -> Sourcing bash file $f"
        source "$f"
    done
elif [[ "$CURRENT_SHELL" == "zsh" ]]; then
    _debug green " (+) Detected shell 'zsh'. Loading zsh-specific files.\n"
    for f in "${SG_DIR}/lib"/*.zsh; do
        [ -e "$f" ] || continue
        _debug yellow "    -> Sourcing zsh file $f"
        source "$f"
    done
else
    msgerr bold red "Error: Unsupported shell. Only loaded cross-platform helpers" 
fi

