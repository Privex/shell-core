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
# This file contains essential functions, which are not only
# helpers for use by dependent shellscript projects, but
# also essential for many parts of ShellCore itself, such as
# initialization or installation of ShellCore. 
#
# Functions:
# 
# has_command  has_binary  ident_shell  sudo
#
#############################################################

SRCED_SGCORE=1


# just a small wrapper around wc to pipe in all args
# saves constantly piping it in
#   $ len "hello"
#   5
#
len() { local l=$(wc -c <<< "${@:1}"); echo $((l-1)); }

# Returns 0 (true) if a requested command exists (WARNING: this will match functions and aliases too)
# Use `has_binary` if you want to specifically only test for binaries
# Example:
#     has_command zip && echo "zip has binary or alias/function" || echo "error: zip not found"
#
has_command() {
    command -v "$1" > /dev/null
}

# Returns 0 (true) if the requested command exists as a binary (not as an alias/function)
# Example:
#     has_binary git && echo "the binary 'git' is available" || echo "could not find binary 'git' using which"
#
has_binary() {
    /usr/bin/env which "$1" > /dev/null
}


ident_shell() {
    ####
    # Attempt to identify the shell we're running in.
    # Example uses:
    #
    #     # Reading the echo output
    #     { [[ $(ident_shell) == "zsh" ]] && echo "Running in zsh"; } || \
    #     { [[ $(ident_shell) == "bash" ]] && echo "Running in bash"; } || \
    #     echo "Unsupported Shell!" && exit 1
    #     
    #     # Using the CURRENT_SHELL var
    #     ident_shell >/dev/null
    #     if [[ "$CURRENT_SHELL" == "bash" ]]; then 
    #       echo "Running in bash"; 
    #     fi;
    #
    ####
    if ! [ -z ${ZSH_VERSION+x} ]; then
        export CURRENT_SHELL="zsh"
    elif ! [ -z ${BASH_VERSION+x} ]; then
        export CURRENT_SHELL="bash"
    else
        export CURRENT_SHELL="unknown"
        return 1
    fi
    echo "$CURRENT_SHELL"
    return 0
}

# Small shim in-case colors.sh isn't loaded yet.
if ! has_command msg; then msg() { echo "$@"; }; fi
if ! has_command msgerr; then msgerr() { >&2 echo "$@"; }; fi

# This is an alias function to intercept commands such as 'sudo apt install' and avoid silent failure
# on systems that don't have sudo - especially if it's being ran as root. Some systems don't have sudo, 
# but if this script is being ran as root anyway, then we can just bypass sudo anyway and run the raw command.
#
# If we are in-fact a normal user, then check if sudo is installed - alert the user if it's not.
# If sudo is installed, then forward the arguments to the real sudo command.
#
sudo() {
  # If user is not root, check if sudo is installed, then use sudo to run the command
  if [ "$EUID" -ne 0 ]; then
    if ! has_binary sudo; then
      msg bold red "ERROR: You are not root, and you don't have sudo installed. Cannot run command '${@:1}'"
      msg red "Please either install sudo and add your user to the sudoers group, or run this script as root."
      sleep 5
      return 3
    fi
    /usr/bin/env sudo "${@:1}"
    return $?
  fi
  # If we got to this point, then the user is already root, so just drop the 'sudo' and run it raw.
  /usr/bin/env "${@:1}"
}

