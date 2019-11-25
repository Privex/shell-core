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

RUN echo "Installing bats-core/bats-core (Bash unit testing)" \
    && git clone -q https://github.com/bats-core/bats-core.git /tmp/bats-core \
    && cd /tmp/bats-core \
    && ./install.sh /usr \
    && cd && rm -rf /tmp/bats-core

RUN adduser --gecos "" --disabled-password testuser

WORKDIR /root/sgshell
ENTRYPOINT [ "bash" ]

