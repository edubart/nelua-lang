---
layout: default
title: Tutorial
permalink: /tutorial/
toc: true
categories: sidenav
order: 3
---

{% raw %}

# Tutorial

This is a basic tutorial for the Nelua Programming Language.

## Installing

To install Nelua you first need a C compiler and [luarocks](https://luarocks.org/)
installed. Now in your terminal run the following:

```bash
luarocks install https://raw.githubusercontent.com/edubart/nelua-lang/master/rockspecs/nelua-dev-1.rockspec
```

If the installation was successful the Nelua compiler should reside in the luarocks binary path.
Add the luarocks binary path (usually `~/.luarocks/bin`) to your
$PATH environment variable if you haven't yet to use the Nelua compiler with more ease.
Now run `nelua -h` and if everything is correctly you should see the nelua help.

## Your first program

You can basically code like you would code in Lua, for example the hello world program:

```nelua
print 'Hello world'
```

This example is already in the repository as an example, first clone the language repository
if you haven't yet:

```
git clone git@github.com:edubart/nelua-lang.git
cd nelua-lang
```

Now can run it doing:
```sh
nelua examples/helloworld.nelua 
```

When running you should get an output similar to this:
```
generated /home/bart/nelua-lang/nelua_cache/examples/helloworld.c
gcc -o "/home/bart/nelua-lang/nelua_cache/examples/helloworld.out" "/home/bart/nelua-lang/nelua_cache/examples/helloworld.c" -lm -Wall -Wextra -Wno-missing-field-initializers -Wno-unused-parameter -Wno-unused-const-variable -Wno-unused-function -Wno-missing-braces -g
/home/bart/nelua-lang/nelua_cache/examples/helloworld
hello world
```

Note that the compiler has generated the `helloworld.c`,
this is your program translated to C source code,
if you know how to read C then I encourage to open it and have a look,
the compiler tries to generate very efficient, compact and readable C sources.

After the C source file was generated GCC is invoked to compile the C sources
and then the program is executed.

If your machine does not have GCC you can use other C compiler using the flag `--cc`. 
For example if you are on MacOS you probability want to use Clang then 
do `nelua --cc clang examples/helloworld.nelua`,
or if you are on Windows you probably want to use MinGW then
do `nelua --cc i686-w64-mingw32-gcc examples/helloworld.nelua`.

## Syntax highlighting for editors

Syntax definitions for the language is available for
Visual Studio Code in [nelua-vscode](https://github.com/edubart/nelua-vscode) and
for Sublime Text in [nelua-sublime](https://github.com/edubart/nelua-sublime).
At the moment only Sublime Text have full definition, so I recommend using it.
If you use other code editor you can use Lua syntax highlighting,
as it very similar but of course incomplete.

I recommend using the syntax highlighter, 
it makes the experience of playing around with the language more pleasant because
it can highlight type notations.

## More examples 

As the language is being developed this tutorial still quite short.
However you can see more interesting examples of the language usage in the
[examples](https://github.com/edubart/nelua-lang/tree/master/examples) or
[benchmarks](https://github.com/edubart/nelua-lang/tree/master/benchmarks) folder.

The most interesing examples are:
* `examples/fibonacci.nelua` multiple implementations of the classic [Fibonnaci sequence](https://en.wikipedia.org/wiki/Fibonacci_number)
* `examples/brainfuck.nelua` use of meta-programing to code the esoteric [Brainfuck language](https://en.wikipedia.org/wiki/Brainfuck)
* `examples/snakesdl.nelua` the classic Snake game (requires SDL)
* `examples/condots.nelua` connected dots graphic animation made in parallel (requires SDL and OpenMP)

{% endraw %}
