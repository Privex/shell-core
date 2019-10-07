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

# Used by dependent scripts to check if this file has been sourced or not.
export SRCED_IDENT_SH=1

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

