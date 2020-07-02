# AlpineLinux
FROM alpine:3.10
RUN apk update
RUN apk upgrade
RUN apk add bash sudo curl build-base git
RUN apk add lua5.3 lua5.3-dev luarocks5.3 sdl2-dev
RUN sudo ln -s /usr/bin/lua5.3 /usr/bin/lua
RUN sudo ln -s /usr/bin/luarocks-5.3 /usr/bin/luarocks

# ArchLinux alternative
#FROM archlinux/base
#RUN pacman -Syu --noconfirm
#RUN pacman -S --noconfirm --needed base-devel git gcc clang
#RUN pacman -S --noconfirm lua luarocks sdl2

COPY rockspecs/nelua-dev-1.rockspec .

# nelua lua dependencies
RUN sudo luarocks install --only-deps nelua-dev-1.rockspec

# nelua global config (to force testing it)
RUN mkdir -p /.config/nelua
RUN echo "return {}" >> /.config/nelua/neluacfg.lua

WORKDIR /nelua
