---
layout: default
title: Installing
permalink: /installing/
toc: true
categories: sidenav
order: 4
---

{% raw %}

# Installing

To use Nelua you need a system with the following:

* Git (for cloning nelua)
* Lua (for running nelua compiler, can be lua 5.1, lua 5.3 or luajit)
* LuaRocks (lua package manager for installing nelua)
* A C compiler (for compiling C generated code such as GCC or Clang)

## Installing on Linux

Use your system package manager to install Lua, LuaRocks and GCC first. For example in Ubuntu:

```bash
sudo apt-get install lua5.1 git luarocks gcc
```

Then install nelua from master with the following command:

```bash
luarocks install https://raw.githubusercontent.com/edubart/nelua-lang/master/rockspecs/nelua-dev-1.rockspec
```

After installing Nelua compiler binary should be available in the binary path then
run `nelua -h` in terminal check if its working. If doesn't work your
environment is probably missing the luarocks environment variables, to fix execute the output from
`luarocks path` in your terminal.

## Installing on Windows

Getting an environment with Git, Lua, LuaRocks and a C compiler working on Windows itself can
be some troublesome and would need to manually download, install, compile packages,
create folders and configure many environment variables. All through UIs which would take
effort and time. This tutorial will show an alternative way using ArchLinux subsystem on Windows
through WSL (Windows Subsystem for Linux) with all Nelua requirements in a few commands,
inside the system you will be able to compile Windows binaries, Linux binaries and
even WebAssembly binaries too.

Before going through these steps make sure that you are using an **updated Windows 10**.

### 1. Install Scoop

[Scoop](https://scoop.sh/) is a command line installer for windows, we use it to install
ArchWSL. Open "Windows PowerShell" then execute:

```bash
Set-ExecutionPolicy RemoteSigned -scope CurrentUser
iwr -useb get.scoop.sh | iex
```

### 2. Install ArchWSL

Get [ArchWSL](https://github.com/yuk7/ArchWSL) from scoop:

```bash
scoop install git
scoop bucket add extras
scoop install archwsl
```

Open another "Windows PowerShell" with Administrative privileges, then enable WSL feature:

```bash
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
```

Restart the system if requested, then open the newly shortcut ArchLinux in startup menu,
a new terminal will be shown, continue updating the subsystem:

```bash
pacman -Syy
pacman -S archlinux-keyring --noconfirm
pacman -Syu --noconfirm
```

Install required dependencies for compiling packages:

```bash
pacman -S --needed --noconfirm git autoconf automake binutils bison flex gcc libtool m4 make cmake patch pkgconf texinfo
```

### 3. Install Lua, LuaRocks and Nelua

Install Lua and LuaRocks:

```bash
pacman -S --noconfirm lua luarocks
```

Install Nelua:

```bash
luarocks install https://raw.githubusercontent.com/edubart/nelua-lang/master/rockspecs/nelua-dev-1.rockspec
```

Nelua now should be working, check it running `nelua -h`,
you can clone and test examples from the official repository:

```bash
wget https://raw.githubusercontent.com/edubart/nelua-lang/master/examples/helloworld.nelua
nelua helloword.nelua
```

Note this is compiling Linux binaries using GCC, thus this way you are only be able to run it
inside WSL therefore limiting to command line applications. To run graphical applications you need
to compile actual Windows binaries, proceed bellow.

### 4. Install Mingw-w64

Continue here only if you want to compile Windows binaries in the ArchWSL.

Create a password-less privileged user for compiling packages and login with it:

```bash
useradd builduser -m
passwd -d builduser
echo 'builduser ALL=(ALL) ALL' >> /etc/sudoers
su builduser
cd ~
```

Install YAY package manager:

```bash
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
makepkg -si --noconfirm
```

Install mingw-w64 compiler and SDL2 to run the graphical demo:

```bash
yay -S --noconfirm mingw-w64-gcc-bin mingw-w64-headers-bin mingw-w64-crt-bin mingw-w64-binutils-bin mingw-w64-winpthreads-bin
yay -S --noconfirm mingw-w64-sdl2
```

You can now logout the builduser:
```bash
exit
```

To run snakesdl demo:
```bash
wget https://raw.githubusercontent.com/edubart/nelua-lang/master/examples/snakesdl.nelua
cp /usr/x86_64-w64-mingw32/bin/SDL2.dll .
nelua --cc=x86_64-w64-mingw32-gcc snakesdl.nelua
```

### Developing setup on Windows

You can use your favorite text editor to edit Nelua projects and save them in your user home in Windows,
the files will be located somewhere in `/mnt/c/Users/<user>/` on ArchWSL. Use the WSL terminal
to change to that path and run the nelua compiler.

### Note for users wanting to use Nelua with MSVC

At the moment the language C code generator uses some C extensions that are supported by GCC and Clang
but not by MSVC C compiler, for those really wanting to use MSVC they should install and use Clang
support in Visual Studio.

Getting Lua and LuaRocks working in MSVC is tricky, the user should try to follow
LuaRocks website. I don't recommend using this method because is quite difficult.

{% endraw %}
