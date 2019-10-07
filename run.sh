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

! [ -z ${ZSH_VERSION+x} ] && _SDIR=${(%):-%N} || _SDIR="${BASH_SOURCE[0]}"
__DIR="$( cd "$( dirname "${_SDIR}" )" && pwd )"

set -eE    # Exit on error

IGNORE_ERR=0 # Set this to 1 within a function to ignore the next non-zero return code. Automatically re-set's to 0 after a non-zero.

error() {
  local parent_lineno="$1"
  local message="$2"
  local code="${3:-1}"
  (($code==0)) && return
  (($IGNORE_ERR==1)) && IGNORE_ERR=0 && return
  >&2 echo -e "${RED}${BOLD}ERROR: Exited Privex ShellCore as a non-zero return code ($code) was encountered near line ${parent_lineno} (run.sh)\n" \
              "Check for any error messages above. For extra debugging output from ShellCore, run 'export SG_DEBUG=1' ${RESET} \n"
  if [[ -n "$message" ]] ; then
    >&2 echo -e "${RED}Error message was:${RESET}"
    >&2 echo "$message"
  fi
  exit "${code}"
}
trap 'error ${LINENO}' ERR

source "${__DIR}/load.sh"
DIR="$__DIR"
INST_DIR="$SG_DIR"

# This global variable is used for context information - if the calling function is operating
# on a global install, then it may set SG_IS_GLOBAL=1 to inform called functions that the
# installation directory is known to be global, and thus sudo should be used.
SG_IS_GLOBAL=0

_sg_auto_update() {
    (($#<1)) && msgerr bold red "_sg_auto_update expects at least 1 argument..." && return 1
    INST_DIR="$1"
    [[ ! -d "$INST_DIR" ]] && msgerr bold red "The folder '$INST_DIR' does not exist, so it cannot be updated..." && return 1  
    cd "$INST_DIR"
    _debug green " (+) Updating existing installation at '$INST_DIR'"
    set +eE  # Temporarily disable exit-on-error so we can handle the return code ourselves
    IGNORE_ERR=1
    if (($SG_IS_GLOBAL==1)); then
        gp_out=$(sudo git pull 2>&1)
        _ret=$?
    else
        gp_out=$(git pull 2>&1)
        _ret=$?
    fi
    set -eE

    if (($_ret==0)); then
        _debug green " (+) 'git pull' returned zero - successfully updated?"
        _debug "GIT PULL output:\n ${gp_out}"
        date +'%s' > "${INST_DIR}/.last_update"
    else
        msgerr bold yellow "WARNING: Attempted to update existing install at '$INST_DIR' but got non-zero status from 'git pull'"
        msgerr red "GIT PULL output:${RESET}\n${gp_out}"
    fi
    return $_ret
}

NEED_REINSTALL=0

_sg_fallback_update() {
    local INST_DIR="$1"
    if [[ ! -f "${INST_DIR}/load.sh" ]]; then
        msgerr bold yellow "WARNING: The folder '$INST_DIR' exists, but doesn't contain load.sh..."
        if (($(len "$INST_DIR")<8)); then
            msg bold red "The folder '$INST_DIR' appears to be shorter than 8 characters."
            msg red "For your safety, no automated removal + re-install will be attempted."
            return 1
        fi
        msgerr yellow "Removing the folder and re-installing."
        (($SG_IS_GLOBAL==1)) && sudo rm -rf "$INST_DIR" || rm -rf "$INST_DIR"
        NEED_REINSTALL=1
        return 0
    else
        _debug yellow "    -> The folder '$INST_DIR' already exists... Attempting to update it.\n"
        _sg_auto_update "$INST_DIR"
        return $?
    fi
}

_sg_install_local() {
    INST_DIR="$SG_LOCALDIR"
    _debug green " (+) Installing SG Shell Core locally: '$INST_DIR' ...\n"
    # If the installation folder already exists, attempt to update it.
    # If the install appears to be damaged, NEED_REINSTALL would be set to 1, meaning that the install folder
    # was removed by fallback_update, so we should continue with the installation.
    if [[ -d "$INST_DIR" ]]; then
        _sg_fallback_update "$INST_DIR"
        ((${NEED_REINSTALL}==0)) && return 0
    fi
    _debug yellow "     -> Creating folder '$INST_DIR' ..."
    mkdir -p "$INST_DIR" &> /dev/null
    
    _debug yellow "     -> Copying all files from '$SG_DIR' to '$INST_DIR' ..."
    cp -Rf "${SG_DIR}/." "$INST_DIR"

    _debug yellow "     -> Adjusting permissions for '$INST_DIR' and files/folders within it..."
    chmod 755 "$INST_DIR" "$INST_DIR"/*.sh 
    chmod -R 755 "$INST_DIR"/{base,lib}
    chmod -R 777 "$INST_DIR"/logs
    local u=$(whoami)
    chown -R "$u" "$INST_DIR"

    _debug green " +++ Finished installing SG Shell Core locally into '$INST_DIR'"
    return 0
}

_sg_install_global() {
    local INST_DIR="$SG_GLOBALDIR"
    SG_IS_GLOBAL=1
    _debug green " (+) Installing SG Shell Core systemwide: '$INST_DIR' ...\n"
    # If the installation folder already exists, attempt to update it.
    # If the install appears to be damaged, NEED_REINSTALL would be set to 1, meaning that the install folder
    # was removed by fallback_update, so we should continue with the installation.
    if [[ -d "$INST_DIR" ]]; then
        _sg_fallback_update "$INST_DIR"
        ((${NEED_REINSTALL}==0)) && return 0
    fi
    _debug yellow "     -> Creating folder '$INST_DIR' ..."
    sudo mkdir -p "$INST_DIR" &> /dev/null
    
    _debug yellow "     -> Copying all files from '$SG_DIR' to '$INST_DIR' ..."
    sudo cp -Rf "${SG_DIR}/." "$INST_DIR"

    _debug yellow "     -> Adjusting permissions for '$INST_DIR' and files/folders within it..."
    sudo chmod 755 "$INST_DIR" "$INST_DIR"/*.sh 
    sudo chmod -R 755 "$INST_DIR"/{base,lib}
    sudo chmod -R 777 "$INST_DIR"/logs
    local u=$(whoami)
    sudo chown -R "$u" "$INST_DIR"

    _debug green " +++ Finished installing SG Shell Core systemwide into '$INST_DIR'"
    return 0
}

_sg_install() {
    local inst_type='auto'
    (($#>0)) && inst_type="$1"
    case "$inst_type" in
        aut*)
            if [[ $UID == 0 || $EUID == 0 ]]; then
                _sg_install_global
                return $?
            fi
            _sg_install_local
            return $?
            ;;
        glo*)
            _sg_install_global
            return $?
            ;;
        loc*)
            _sg_install_local
            return $?
            ;;
        *)
            msgerr bold red "ERROR: _sg_install was passed an invalid install type: '$inst_type'"
            return 1
            ;;
    esac
}

_help() {
    msg green "Privex's Shell Core - Version v${S_CORE_VER}"
    msg green "(C) 2019 Privex - Released under the GNU GPL v3 license"
    msg yellow "-------------------------------------------------------------------"
    msg cyan "Official Repo: https://github.com/Privex/shell-core"
    msg
    msg bold green "Available run.sh commands:\n"

    msg bold magenta "\t - install (global|local|auto)"
    msg magenta      "\t   Install Shell Core to allow other scripts to find it. If you don't specify\n" \
                     "\t   the install type (global, local, or auto), then it will default to 'auto'.\n" \
                     "\t   \n" \
                     "\t   local   - Install Shell Core into the home folder: '$SG_LOCALDIR'\n" \
                     "\t   global  - Install Shell Core into the system folder: '$SG_GLOBALDIR'\n" \
                     "\t   auto    - If the current user is 'root', install globally; otherwise locally.\n"
    msg cyan "-------------------------------------------------------------------\n"
    msg bold magenta "\t - update (localfb)"
    msg magenta      "\t   Updates the installation of Shell Core in this folder '${SG_DIR}'. \n" \
                     "\t   \n" \
                     "\t   If you're calling this command on a global installation of Shell Core from a \n" \
                     "\t   potentially non-privileged user, you may wish to pass the argument 'localfb', \n" \
                     "\t   which means: \n" \
                     "\t   \n" \
                     "\t       'If the current user has no permissions to update this install, nor sudo,  \n" \
                     "\t        then install or update the local user's Shell Core installation.'\n" 
    msg cyan "-------------------------------------------------------------------\n"

}

case "$1" in
    help)
        _help
        ;;
    install)
        _sg_install "${@:2}"
        exit $?
        ;;
    update)
        localfb=0
        (($#>1)) && [[ "$2" == "localfb" ]] && localfb=1

        if can_write "${SG_DIR}/.git/HEAD"; then
            _sg_auto_update "${SG_DIR}"
            exit $?
        fi
        msgerr bold yellow "WARNING: ${SG_DIR}/.git/HEAD is not writable by this user."
        if (($localfb==1)); then
            msgerr yellow "Falling back to local install/update"
            _sg_install_local
            exit $?
        fi
        msgerr red "As 'localfb' was not specified, giving up. Cannot update this installation."
        exit 5
        ;;
    dockertest)
        cd "$SG_DIR"
        msg green " -> Building image tag 'sgshell' from directory '$SG_DIR'"
        docker build -t sgshell .
        (($?!=0)) && msgerr bold red "Error building image 'sgshell'. Please see log messages above." && exit 1

        msg bold green " + Successfully built image 'sgshell'"
        msg green " -> Starting container 'sg-shell' using image 'sgshell'"
        docker run --rm --name sg-shell -itd sgshell

        (($?!=0)) && msgerr bold red "Error while launching 'sg-shell'. See log messages above." && exit 1

        msg green " -> Opening a bash prompt in container 'sg-shell'. Start by typing 'source load.sh'"
        docker exec -it sg-shell bash

        msg yellow " !! Looks like you're finished. Now stopping and removing container 'sg-shell'..."
        docker stop sg-shell
        docker rm sg-shell &> /dev/null
        msg green " +++ Done. Exiting cleanly."
        exit 0
        ;;

    *)
        msg bold red "Unknown command '$1'\n"
        _help
        exit 99
        ;;
esac

