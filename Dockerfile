# AlpineLinux alternative
# FROM alpine:3.10
# RUN apk update
# RUN apk upgrade
# RUN apk add bash sudo curl build-base git
# RUN apk add lua5.3 lua5.3-dev luarocks5.3 sdl2-dev
# RUN sudo ln -s /usr/bin/lua5.3 /usr/bin/lua
# RUN sudo ln -s /usr/bin/luarocks-5.3 /usr/bin/luarocks

# ArchLinux alternative
FROM archlinux/base
RUN pacman -Syu --noconfirm
RUN pacman -S --noconfirm --needed base-devel git gcc clang
RUN pacman -S --noconfirm lua luarocks sdl2

# for using the terminal
RUN pacman -S --noconfirm vim bash-completion

# add docker user with sudo permission
ARG USER_ID
ARG GROUP_ID
RUN pacman -S --noconfirm sudo
RUN groupadd -g $GROUP_ID docker
RUN useradd -m -s /bin/bash -u $USER_ID -g $GROUP_ID docker
RUN gpasswd -a docker wheel
RUN echo '%wheel ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
USER docker

# busted
RUN sudo luarocks install busted
# luacov
RUN sudo luarocks install luacov
# cluacov
RUN sudo luarocks install cluacov
# luacheck
RUN sudo luarocks install https://raw.githubusercontent.com/edubart/luacheck/myrocks/luacheck-dev-1.rockspec

# nelua global config (to force testing it)
RUN mkdir -p /home/docker/.config/nelua
RUN echo "return {}" >> /home/docker/.config/nelua/neluacfg.lua

WORKDIR /nelua
