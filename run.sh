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

# Load bash error handler library
source "${__DIR}/base/trap.bash"

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

    if (($SG_IS_GLOBAL==1)); then

        gp_out=$(sudo git pull -q)
    else
        gp_out=$(git pull -q)
    fi

    _debug green " (+) 'git pull' returned zero - successfully updated?"
    _debug "GIT PULL output:\n ${gp_out}"
    date +'%s' > "${INST_DIR}/.last_update"
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
        return
    else
        _debug yellow "    -> The folder '$INST_DIR' already exists... Attempting to update it.\n"
        _sg_auto_update "$INST_DIR"
        return
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
    # chmod 755 "$INST_DIR" "$INST_DIR"/*.sh 
    # chmod -R 755 "$INST_DIR"/{base,lib}
    chmod 755 "$INST_DIR"
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
    # sudo chmod 755 "$INST_DIR" "$INST_DIR"/*.sh 
    # sudo chmod -R 755 "$INST_DIR"/{base,lib}
    sudo chmod 755 "$INST_DIR"
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

remove_sources() {
    sed -E "s/.*source \".*\.sh\".*//g" "$@"
    # raise_error
}

remove_comments() {
    sed -E "s/^#.*//g" "$@" | sed -E "s/^[[:space:]]+#.*//g"
    # raise_error "unexpected error removing comments" "${BASH_SOURCE[0]}" $LINENO
}

_sg_compile() {
    local use_file=0 out_file
    (($#>0)) && use_file=1 && out_file="$1" || out_file="$(mktemp)"
    : ${SHEBANG_LINE='#!/usr/bin/env bash'}
    {
        echo "$SHEBANG_LINE"
        export __CMP_NOW=$(date)
        sg_copyright="
#############################################################
#                                                           #
# Privex's Shell Core  (Version v${S_CORE_VER})                     #
# Cross-platform / Cross-shell helper functions             #
#                                                           #
# Released under the GNU GPLv3                              #
#                                                           #
# Official Repo: github.com/Privex/shell-core               #
#                                                           #
# This minified script was compiled at:                     #
# $__CMP_NOW                              #
#                                                           #
#############################################################
"
        echo "$sg_copyright"
        echo -e "\n### --------------------------------------"
        echo "### Privex/shell-core/init.sh"
        echo "### --------------------------------------"
        cat "${SG_DIR}/init.sh" | remove_sources | remove_comments | tr -s '\n'
        echo -e "\n### --------------------------------------"
        echo "### Privex/shell-core/base/identify.sh"
        echo "### --------------------------------------"
        cat "${SG_DIR}/base/identify.sh" | remove_sources | remove_comments | tr -s '\n'
        echo -e "\n### --------------------------------------"
        echo "### Privex/shell-core/base/colors.sh"
        echo "### --------------------------------------"
        cat "${SG_DIR}/base/colors.sh" | remove_sources | remove_comments | tr -s '\n'
        echo -e "\n### --------------------------------------"
        echo "### Privex/shell-core/base/permission.sh"
        echo "### --------------------------------------"
        cat "${SG_DIR}/base/permission.sh" | remove_sources | remove_comments | tr -s '\n'

        for f in "${SG_DIR}/lib"/*.sh; do
            local b=$(basename "$f")
            echo -e "\n### --------------------------------------"
            echo "### Privex/shell-core/lib/$b"
            echo "### --------------------------------------"
            cat $f | remove_sources | remove_comments | tr -s '\n'
        done
        echo
        echo "$sg_copyright"
        echo
    } > "$out_file"
    
    (($use_file==1)) && msg green " -> Compiled ShellCore into file '$out_file'" || { cat "$out_file"; rm -f "$out_file"; }

    return 0
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
    compile)
        _sg_compile "${@:2}"
        exit $?
        ;;
    dockertest)
        error_control 2
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
        error_control 2
        msg bold red "Unknown command '$1'\n"
        _help
        exit 99
        ;;
esac

