# ArchLinux alternative
FROM archlinux/archlinux
RUN pacman -Syu --noconfirm
RUN pacman -S --noconfirm --needed base-devel git gcc clang
RUN pacman -S --noconfirm lua luarocks sdl2

# for using the terminal
RUN pacman -S --noconfirm vim bash-completion

# add docker user with sudo permission
RUN pacman -S --noconfirm sudo
RUN useradd -m -G wheel -s /bin/bash docker
RUN echo '%wheel ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
USER docker

# luacov
RUN sudo luarocks install cluacov
# luacheck
RUN sudo luarocks install luacheck

# nelua global config (to force testing it)
RUN mkdir -p /home/docker/.config/nelua
RUN echo "return {}" >> /home/docker/.config/nelua/neluacfg.lua

WORKDIR /mnt
