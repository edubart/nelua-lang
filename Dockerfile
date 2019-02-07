# AlpineLinux
FROM alpine:3.9
RUN apk update
RUN apk upgrade
RUN apk add bash sudo curl build-base
RUN apk add lua5.3 lua5.3-dev lua5.1 lua5.1-dev luajit luajit-dev luarocks5.1 luarocks5.3

# ArchLinux alternative
#FROM archlinux/base
#RUN pacman -Syu --noconfirm
#RUN pacman -S --noconfirm --needed base-devel git gcc clang
#RUN pacman -S --noconfirm lua lua51 luajit luarocks luarocks5.1

MAINTAINER edubart

# euluna lua dependencies (5.1)
RUN sudo luarocks-5.1 install penlight
RUN sudo luarocks-5.1 install lpeg
RUN sudo luarocks-5.1 install lpeglabel
RUN sudo luarocks-5.1 install lua-term
RUN sudo luarocks-5.1 install inspect
RUN sudo luarocks-5.1 install busted
RUN sudo luarocks-5.1 install luacheck
RUN sudo luarocks-5.1 install luacov
RUN sudo luarocks-5.1 install cluacov
RUN sudo luarocks-5.1 install compat53

# euluna lua dependencies (5.3)
RUN sudo luarocks-5.3 install penlight
RUN sudo luarocks-5.3 install lpeg
RUN sudo luarocks-5.3 install lpeglabel
RUN sudo luarocks-5.3 install lua-term
RUN sudo luarocks-5.3 install inspect
RUN sudo luarocks-5.3 install busted
RUN sudo luarocks-5.3 install luacheck
RUN sudo luarocks-5.3 install luacov
RUN sudo luarocks-5.3 install cluacov
RUN sudo luarocks-5.3 install compat53

WORKDIR /euluna