#!/usr/bin/zsh
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

#####
#
# Due to the fact that BSD utilities can sometimes suck, 
# this is a sanity checker, which makes sure we have access
# to the GNU toolset if we're not on a Linux system.
#
# Usage: 
# from a function:
#    gnusafe || return 1
# from a script (that isn't sourced):
#    gnusafe || exit 1
#
# Original code, written by @someguy123 (github.com/@someguy123)
# License: GNU GPLv3
#
#####

if [ -t 1 ]; then
    BOLD="$(tput bold)" RED="$(tput setaf 1)" GREEN="$(tput setaf 2)" YELLOW="$(tput setaf 3)" BLUE="$(tput setaf 4)"
    MAGENTA="$(tput setaf 5)" CYAN="$(tput setaf 6)" WHITE="$(tput setaf 7)" RESET="$(tput sgr0)"
else
    BOLD="" RED="" GREEN="" YELLOW="" BLUE=""
    MAGENTA="" CYAN="" WHITE="" RESET=""
fi

: ${HAS_GGREP=0}
: ${HAS_GSED=0}
: ${HAS_GAWK=0}

function gnusafe () {
    # Detect if the script is being ran from bash or zsh
    # so we can enable aliases for scripts
    if ! [ -z ${ZSH_VERSION+x} ]; then
        # Enable aliases for zsh
        setopt aliases
    elif ! [ -z ${BASH_VERSION+x} ]; then
        # Enable aliases for bash
        shopt -s expand_aliases
    else
        >&2 echo "${RED}
    We can't figure out what shell you're running as neither BASH_VERSION 
    nor ZSH_VERSION are set. This is important as we need to figure out 
    which grep/sed/awk that we should use, and alias appropriately.

    Different shells have different ways of enabling alias's in scripts 
    such as this, but since you don't seem to be using zsh or bash, we 
    can't continue...${RESET}
        "
        return 3
    fi

    if [[ $(uname -s) != 'Linux' ]] && [ -z ${FORCE_UNIX+x} ]; then
        # msg warn " --- WARNING: Non-Linux detected. ---"
        # echo " - Checking for ggrep"
        if [[ $(command -v ggrep) ]]; then
            HAS_GGREP=1
            # msg pos " + found GNU alternative 'ggrep'. setting alias"
            alias grep="ggrep"
            alias egrep="ggrep -E"
        fi
        # echo " - Checking for gsed"	
        if [[ $(command -v gsed) ]]; then
            HAS_GSED=1
            # msg pos " + found GNU alternative 'gsed'. setting alias"
            alias sed=gsed
        fi
        if [[ $(command -v gawk) ]]; then
            HAS_GAWK=1
            # msg pos " + found GNU alternative 'gawk'. setting alias"
            alias awk=gawk
        fi
        if [[ $HAS_GGREP -eq 0 || $HAS_GSED -eq 0 || $HAS_GAWK -eq 0 ]]; then
            >&2 echo "${RED} 
    --- ERROR: Non-Linux detected. Missing GNU sed, awk or grep ---
    The program could not find ggrep, gawk, or gsed as a fallback.
    Due to differences between BSD and GNU Utils the program will now exit
    Please install GNU grep and GNU sed, and make sure they work
    On BSD systems, including OSX, they should be available as 'ggrep' and 'gsed'
    
    For OSX, you can install ggrep/gsed/gawk via brew:
        brew install gnu-sed
        brew install grep
        brew install gawk
    
    If you are certain that both 'sed' and 'grep' are the GNU versions,
    you can bypass this and use the default grep/sed with FORCE_UNIX=1${RESET}
            "
            return 4
        else
            # msg pos " +++ Both gsed and ggrep are available. Aliases have been set to allow this script to work."
            # msg warn "Please be warned. This script may not work as expected on non-Linux systems..."
            trap gnusafe-cleanup EXIT
            return 0
        fi
    else
        # if we're on linux
        # make sure any direct uses of gsed, gawk, and ggrep work
        alias ggrep="grep"
        alias gawk="awk"
        alias gsed="sed"
        # if we don't have egrep, alias it
        if [[ $(command -v egrep) ]]; then
            alias egrep="grep -E"
        fi
        trap gnusafe-cleanup EXIT
        return 0
    fi
}

function is_alias () {
    command -V "$1" 2> /dev/null | grep -qi "alias"
}
# Ran on exit to ensure no aliases leak out into the environment
# and break the users terminal
function gnusafe-cleanup () {
    is_alias ggrep && unalias ggrep 2>/dev/null
    is_alias gawk && unalias gawk 2>/dev/null
    is_alias gsed && unalias gsed 2>/dev/null
    is_alias grep && unalias grep 2>/dev/null
    is_alias awk && unalias awk 2>/dev/null
    is_alias sed && unalias sed 2>/dev/null
}
