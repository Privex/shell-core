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

set -eE

if [ -t 1 ]; then
    BOLD="$(tput bold)" RED="$(tput setaf 1)" GREEN="$(tput setaf 2)" YELLOW="$(tput setaf 3)" BLUE="$(tput setaf 4)"
    MAGENTA="$(tput setaf 5)" CYAN="$(tput setaf 6)" WHITE="$(tput setaf 7)" RESET="$(tput sgr0)"
else
    BOLD="" RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN="" WHITE="" RESET=""
fi
export BOLD RED GREEN YELLOW BLUE MAGENTA CYAN WHITE RESET

# just a small wrapper around wc to pipe in all args
# saves constantly piping it in
len() { wc -c <<< "${@:1}"; }

cleanup() {
    if ! [ -z ${clonedir+x} ] && [[ $(len "$clonedir") -gt 5 ]]; then 
        echo "Removing temporary clone folder '$clonedir'..." && rm -rf "$clonedir"; 
    fi
}

sudo() {
  if [ "$EUID" -ne 0 ]; then  # If user is not root, check if sudo is installed, then use sudo to run the command
    if ! has_binary sudo; then
      msg bold red "ERROR: You are not root, and you don't have sudo installed. Cannot run command '${@:1}'"
      msg red "Please either install sudo and add your user to the sudoers group, or run this script as root."
      sleep 5
      return 3
    fi
    /usr/bin/env sudo "${@:1}"
  else
    /usr/bin/env "${@:1}" # The user is already root, so just drop the 'sudo' and run it raw.    
  fi
}

err_trap() {
    >&2 echo -e "${RED}${BOLD}ERROR: Could not install Privex ShellCore as a non-zero return code was encountered.\n" \
                "Check for any error messages above. For extra debugging output from ShellCore, run 'export SG_DEBUG=1' ${RESET} \n"
    cleanup
}

trap err_trap ERR
trap cleanup EXIT

cd /tmp
clonedir="$(mktemp -d)"

has_binary() {
    /usr/bin/env which "$1" > /dev/null
}

install_git() {
    if has_binary apt-get; then
        echo "${YELLOW}Attempting to install 'git' using apt-get...${RESET}"
        sudo apt-get update -qy > /dev/null
        sudo apt-get install -y git
    elif has_binary yum; then
        echo "${YELLOW}Attempting to install 'git' using yum...${RESET}"
        sudo yum -y install git
    else
        return 1
    fi
}

if ! has_binary git; then
    if ! install_git; then
        >&2 echo "${RED}${BOLD}ERROR: Could not find 'git', you're not root, and 'sudo' is not available. " \
                "Cannot continue with install of Privex ShellCore... Please install 'git' as root.${RESET}\n"
        exit 1
    fi
fi

echo "${GREEN} -> Cloning Privex/shell-core into '$clonedir'${RESET}"
git clone -q https://github.com/Privex/shell-core.git "$clonedir"
echo "${GREEN} -> Using 'run.sh install' to install/update Privex ShellCore${RESET}"
bash "${clonedir}/run.sh" install

if [[ -d "${HOME}/.pv-shcore" ]]; then
    echo "source ${HOME}/.pv-shcore/load.sh" > /tmp/pv-shellcore
elif [[ -d "/usr/local/share/pv-shcore" ]]; then
    echo "source /usr/local/share/pv-shcore/load.sh" > /tmp/pv-shellcore
else
    >&2 echo "${RED}${BOLD}ERROR: Install appeared successful, but neither the local nor global ShellCore " \
             "installation folder could be found...${RESET}\n"
    exit 1
fi

echo "${GREEN} +++ Privex ShellCore has been installed / updated.${RESET}"
