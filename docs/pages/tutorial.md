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

This is a basic tutorial for the Nelua Programming Language, if you don't have installed
Nelua yet, please see the [installing tutorial](/installing) first.

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
do `nelua --cc x86_64-w64-mingw32-gcc examples/helloworld.nelua`.

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

## Language features

A quick tour of the language features can be seen in the [overview page](/overview).

## More examples 

As the language is being developed this tutorial still quite short.
However you can see more interesting examples of the language usage in the
[examples](https://github.com/edubart/nelua-lang/tree/master/examples),
[benchmarks](https://github.com/edubart/nelua-lang/tree/master/benchmarks) or
[tests](https://github.com/edubart/nelua-lang/tree/master/tests)
 folders.

The most interesing examples are:
* `examples/fibonacci.nelua` multiple implementations of the classic [Fibonnaci sequence](https://en.wikipedia.org/wiki/Fibonacci_number)
* `examples/brainfuck.nelua` use of meta-programing to code the esoteric [Brainfuck language](https://en.wikipedia.org/wiki/Brainfuck)
* `examples/snakesdl.nelua` the classic Snake game (requires SDL)
* `examples/condots.nelua` connected dots graphic animation made in parallel (requires SDL and OpenMP)

{% endraw %}
