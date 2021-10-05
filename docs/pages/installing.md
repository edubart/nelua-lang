---
layout: docs
title: Installing
permalink: /installing/
categories: docs toc
order: 1
---

{% raw %}

Instructions for installing Nelua on Windows or Linux.
{: .lead}

To install Nelua you need a system with the following:

* Git (for cloning Nelua)
* A C compiler (GCC or Clang are recommended)
* Build tools (such as make)
* GDB debugger (in case you want to debug runtime errors)

## Linux

Use your system's package manager to install all of the required tools first:

For example, on **Ubuntu** you should do:

```bash
sudo apt-get install build-essential git gcc gdb
```

While on **ArchLinux**, you should do:

```bash
sudo pacman -S base-devel git gcc gdb
```

## MacOS

First make sure you have installed **brew**, then run:

```bash
brew install gcc gdb git make
```

## Windows

MSYS2 is the recommended and supported environment to use Nelua on Windows.
Although you could use other tools, MSYS2 makes using Nelua very easy on Windows,
plus there are many useful C packages on MSYS2 that you can install with ease, such as
SDL2.

Download and install [MSYS2](https://www.msys2.org/).
After installing open the **64 bit terminal**, that is,
**msys64**, and update:

```bash
pacman -Syu
```

You may need close and reopen the terminal and update a second time using the same command.

Now install all the required tools:

```bash
pacman -S base-devel git mingw-w64-x86_64-gcc gdb
```

## Clone and Install

Now you can clone the project and compile:

```bash
git clone https://github.com/edubart/nelua-lang.git && cd nelua-lang
make
```

Now install in your system:

```bash
sudo make install
```

On Linux this will install in `/usr/local` by default,
you could install it somewhere else using the `PREFIX` argument.
For example, suppose you want to install in your home directory,
then you could use `make install PREFIX=/home/user/nelua`
and the Nelua compiler would be available at `/home/user/nelua/bin/nelua`.

Alternatively, if you want to run Nelua directly from the cloned repository,
then you have the following options:
* You could add the cloned `nelua-lang` directory to your `PATH` environment variable,
then the `nelua` command will become available in your terminal.
* You could create symbolic links to `./nelua` and `./nelua-lua`
in one directory of your `PATH` environment variable.
* You could run the `./nelua` file directly.

Proceed to the [testing section](#testing).

## Testing

Nelua should be installed. Run `nelua -h` in your terminal to check if it is working.
If doesn't work, your environment `PATH` variable is missing the `bin` folder of the Nelua installation.
Add it or find and execute the full path to the installed Nelua compiler to use it.

Run the hello world example:

```bash
nelua examples/helloworld.nelua
```

You can run any file in the `examples` or `tests` directories,
play with them to test or to learn how to code in Nelua.

The most interesting examples are perhaps the graphical ones,
such as `snakesdl.nelua` and `condots.nelua`.

To run the Snake SDL game demo, for example, you will need to have the SDL2 library installed.
Install it using your system's package manager and run the example:

```bash
# install SDL2 on MSYS2
pacman -S mingw-w64-x86_64-SDL2
# install SDL2 on Ubuntu
sudo apt-get install libsdl2-dev
# run it
nelua examples/snakesdl.nelua
```

<a href="/tutorial/" class="btn btn-outline-primary btn-lg float-right">Tutorial >></a>

{% endraw %}
