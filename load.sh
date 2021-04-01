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

ident_shell >/dev/null

if [ -z ${SG_LOAD_LIBS+x} ]; then
    SG_LOAD_LIBS=(gnusafe helpers datehelpers)
    _debug "SG_LOAD_LIBS not specified from environment. Using default libs: ${SG_LOAD_LIBS[*]}"
else
    _debug "SG_LOAD_LIBS was specified in environment. Using environment libs: ${SG_LOAD_LIBS[*]}"
fi

sg_load_lib "${SG_LOAD_LIBS[@]}"

