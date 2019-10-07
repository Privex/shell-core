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
FROM ubuntu:bionic

RUN apt-get update -qy && apt-get install -y zsh bash-completion curl wget git && apt-get clean -qy

COPY . /root/sgshell

COPY docker/bashrc /root/.bashrc
COPY docker/zshrc /root/.zshrc

COPY docker/bashrc /etc/skel/.bashrc
COPY docker/zshrc /etc/skel/.zshrc

RUN adduser --gecos "" --disabled-password testuser

WORKDIR /root/sgshell
ENTRYPOINT [ "bash" ]

