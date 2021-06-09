---
layout: docs
title: Libraries
permalink: /libraries/
categories: docs toc
toc: true
order: 4
---

This is a list of Nelua standard libraries.
{: .lead}

To use a library, use `require 'libraryname'`{:.language-nelua}.
{: .callout.callout-info}


## builtins

The following are builtin functions defined in the Nelua compiler.
Thus this is not really a library and shouldn't be used with `require`.

### require

```nelua
global function require(modname: string <comptime>)
```

Loads the given module `modname`.

The function starts by looking into loaded modules to determine whether `modname` is already loaded.
If it is then require does nothing, otherwise it tries to load the module.

If there is any error loading the module, then the compilation fails.
If there is any error running the module, then the application terminates.

### print

```nelua
global function print(...: varargs): void
```

Receives any number of arguments and prints their values to the standard output,
converting each argument to a string following the same rules of `tostring`.
The values are separated by tabs and a new line is always appended.

The function `print` is not intended for formatted output,
but only as a quick way to show a value, for instance for debugging.
For complete control over the output, use `io.write` or `io.writef`.

### panic

```nelua
global function panic(message: string): void
```

Terminate the application abnormally with message `message`.
Use to raise unrecoverable errors.

### error

```nelua
global function error(msg: string): void
```

Raises an error with message `message`.

Currently this is an alias to `panic` and terminates the application,
but in the future, in case the language get an exception system,
it may be changed to an exception being thrown.

### assert

```nelua
global function assert(v: auto, message: facultative(string))
```

Raises an error if the value `v` is evaluated to `false`, otherwise, returns `v`.
In case of error, `message` is the error message, when absent defaults to `"assertion failed!"`.

### check

```nelua
global function check(cond: boolean, message: facultative(string)): void
```

If `cond` is true it does nothing, otherwise raises an error with `message` and terminates the application.
Similar to `assert` however it's completely omitted when compiling in release mode or with pragma `nochecks`.
Use for assertive programming, to check if conditions are met without impacting performance of production code.

### likely

```nelua
global function likely(cond: boolean): boolean
```

Returns `cond`. This is a branching prediction utility, expecting `cond` to evaluate to `true`.

### unlikely

```nelua
global function unlikely(cond: boolean): boolean
```

Returns `cond`. This is a branching prediction utility, expecting `cond` to evaluate to `false`.

### _VERSION

```nelua
global _VERSION: string
```

A string containing the running Nelua version, such as `"Nelua 0.2-dev"`.


## arg

The arguments library provides the global sequence `arg`,
which is filled with command line arguments on initialization.

### arg

```nelua
global arg: sequence(string, GeneralAllocator)
```

Sequence of command line arguments.

The value at index `0` is usually filled with the program executable name.
The values starting from index `1` up to `#arg` contains each command line argument.


## iterators

The iterators library provides iterators functions such as
`ipairs`, `pairs` and `next` to assist iterating over elements of a container.

The functions provided here can be used with the `for in` construction.

### ipairs

```nelua
global function ipairs(a: contiguous_reference_concept)
```

Returns values so that the construction
```nelua
for i,v in ipairs(a) do body end
```
will iterate over the index–value pairs of `a` from its first element up to the last.
Where `i` is an integer determining the index of the element, and `v` its respective value.

The container `a` must be contiguous, such as `array`, `span`, `vector` or `sequence`.

### mipairs

```nelua
global function mipairs(a: contiguous_reference_concept)
```

Like `ipairs` but yields reference to elements values so that you can modify them in-place.

### next

```nelua
global function next(a: container_reference_concept, k: auto)
```

Gets the next element after key `k` for the container `a`.

In case of success returns `true` plus the next element key and the next element value.
Otherwise returns `false` plus a zeroed key and value.

The container `a` must either have the metamethod `__next` or be a contiguous.

### mnext

```nelua
global function mnext(a: contiguous_reference_concept, k: auto)
```

Like `next` but returns reference to the next element value, so that you can modify it in-place.

### pairs

```nelua
global function pairs(a: container_reference_concept)
```

Returns values so that the construction
```nelua
for k,v in pairs(a) do body end
```
will iterate over all the key–value pairs of `a`.
Where `k` is a key determining the location of the element, and `v` its respective value.

The container `a` must either have the metamethod `__pairs` or be a contiguous.
Should work on any container, such as `array`, `span`, `vector`, `sequence` or `hashmap`.

### mpairs

```nelua
global function mpairs(a: container_reference_concept)
```

Like `pairs` but yields reference to elements values so that you can modify them in-place.


## io

The input and output library provides functions to manipulate files.

The library provides two different styles for file manipulation.
The first one uses implicit file handles,
that is, there are operations to set a default input file and a default output file,
and all input/output operations are done over these default files.
The second style uses explicit file handles.
When using implicit file handles, all operations are supplied by module `io`.

When using explicit file handles,
the operation `io.open` returns a file handle and
then all operations are supplied as methods of the file handle.

The io module also provides three predefined file handles with their usual meanings from C:

* `io.stdin`: default input file handle
* `io.stdout`: default output file handle
* `io.stderr`: default error output file handle

The I/O library never closes these files.

Unless otherwise stated, all I/O functions return a valid value on success,
otherwise an error message as a second result
and a system-dependent error code as a third result.

### io

```nelua
global io: type = @record{}
```

Namespace for I/O module.

### io.stderr

```nelua
global io.stderr: filestream
```

Default error output file handle.

### io.stdout

```nelua
global io.stdout: filestream
```

Default output file handle.

### io.stdin

```nelua
global io.stdin: filestream
```

Default input file handle.

### io.open

```nelua
function io.open(filename: string, mode: facultative(string)) : (filestream, string, integer)
```

Opens a file, in the mode specified in the string `mode`.
In case of success, it returns an open file.

Equivalent to `filestream:open(filename, mode)`.

### io.popen

```nelua
function io.popen(prog: string, mode: facultative(string)) : (filestream, string, integer)
```

Starts the program `prog` in a separated process and
returns a file handle that you can use to read data from this program
(if `mode` is "r", the default) or to write data to this program (if `mode` is "w").
This function is system dependent and is not available on all platforms.

### io.close

```nelua
function io.close(file: overload(filestream, niltype)): (boolean, string, integer)
```

Closes a file.
Without a `file`, closes the default output file.

Equivalent to `file:close()`.

### io.flush

```nelua
function io.flush(): (boolean, string, integer)
```

Save any written data to the default output file.

Equivalent to `io.output():flush()`.

### io.input

```nelua
function io.input(file: overload(string,filestream,niltype)): filestream
```

When called with a file name, it opens the named `file` (in text mode), and sets its handle as the default input file.
When called with a file handle, it simply sets this file handle as the default input file.
When called without arguments, it returns the current default input file.

In case of errors this function raises the error, instead of returning an error code.

### io.output

```nelua
function io.output(file: overload(string,filestream,niltype)): filestream
```

Similar to `io.input`, but operates over the default output file.

### io.tmpfile

```nelua
function io.tmpfile(): (filestream, string, integer)
```

In case of success, returns an open handle for a temporary file.
This file is opened in update mode and it is automatically removed when the program ends.

### io.read

```nelua
function io.read(fmt: overload(integer,string,niltype)): (string, string, integer)
```

Read from default input, according to the given format.

Equivalent to `io.input():read(fmt)`.

### io.write

```nelua
function io.write(...: varargs): (boolean, string, integer)
```

Writes the value of each of its arguments to the standard output.
The arguments must be strings or numbers.
In case of success, this function returns `true`.

Equivalent to `io.output():write(...)`.

### io.writef

```nelua
function io.writef(fmt: string, ...: varargs): (boolean, string, integer)
```

Writes formatted values to the standard output, according to the given format.
In case of success, this function returns `true`.

Equivalent to `io.output():writef(fmt, ...)`.

### io.type

```nelua
function io.type(obj: auto)
```

Checks whether `obj` is a valid file handle.
Returns the string `"file"` if `obj` is an open file handle,
`"closed file"` if `obj` is a closed file handle,
or `nil` if `obj` is not a file handle.

### io.isopen

```nelua
function io.isopen(file: filestream): boolean
```

Checks weather `file` is open.

### io.lines

```nelua
function io.lines(filename: facultative(string), fmt: overload(integer,string,niltype))
```

Opens the given file name in read mode
and returns an iterator function that works like `file:lines(...)` over the opened file.

The call `io.lines()` (with no file name) is equivalent to `io.input():lines("l")`,
that is, it iterates over the lines of the default input file.

It currently never closes the file when the iteration finishes.
In case of errors opening the file, this function raises the error, instead of returning an error code.


## filestream

The file stream library provides the `filestream` record,
mostly used by the `io` library to manage file handles,
but can also be used independently.

### filestream

```nelua
global filestream: type = @record{
  id: uint64
}
```

File stream record, used to store file handles.
Internally it just have an unique `id` for each file handle.

### filestream._fromfp

```nelua
function filestream._fromfp(fp: *FILE, closef: function(fp: *FILE): cint): filestream
```

Initialize a new `filestream` from a given C `FILE` pointer.
`closef` is a callback to call when closing the file handle.

This function is used internally.

### filestream:_getfp

```nelua
function filestream:_getfp(): *FILE
```

Returns a C `FILE` pointer for the filestream.
In case the file is closed, returns `nilptr`.

This function is used internally.

### filestream.open

```nelua
function filestream.open(filename: string, mode: facultative(string)) : (filestream, string, integer)
```

Opens a file, in the mode specified in the string `mode`.
In case of success, it returns an open file.
Otherwise, returns a closed file handle, plus an error message and a system-dependent error code.

The mode string can be any of the following:

* `"r"`: read mode (the default);
* `"w"`: write mode;
* `"a"`: append mode;
* `"r+"`: update mode, all previous data is preserved;
* `"w+"`: update mode, all previous data is erased;
* `"a+"`: append update mode, previous data is preserved, writing is only allowed at the end of file.

The mode string can also have a 'b' at the end, which is needed in some systems to open the file in binary mode.

### filestream:flush

```nelua
function filestream:flush(): (boolean, string, integer)
```

Saves any written data to file.

Returns `true` on success, otherwise `false` plus an error message and a system-dependent error code.

### filestream:close

```nelua
function filestream:close(): (boolean, string, integer)
```

Closes the file.

Returns `true` on success, otherwise `false` plus an error message and a system-dependent error code.

### filestream:seek

```nelua
function filestream:seek(whence: facultative(string), offset: facultative(integer)): (integer, string, integer)
```

Sets and gets the file position, measured from the beginning of the file,
to the position given by `offset` plus a base specified by the string `whence`, as follows:

* `"set"`: base is position 0 (beginning of the file)
* `"cur"`: base is current position
* `"end"`: base is end of file

In case of success, returns the final file position, measured in bytes from the beginning of the file.
If seek fails, it returns `-1`,  plus an error message and a system-dependent error code.

The default value for whence is `"cur"`, and for offset is `0`.
Therefore, the call `filestream:seek()` returns the current file position, without changing it.

The call `filestream:seek("set")` sets the position to the beginning of the file (and returns `0`).
The call `file:seek("end")` sets the position to the end of the file, and returns its size.

### filestream:setvbuf

```nelua
function filestream:setvbuf(mode: string, size: facultative(integer)): (boolean, string, integer)
```

Sets the buffering mode for a file. There are three available modes:

* `"no"`: no buffering.
* `"full"`: full buffering.
* `"line"`: line buffering.

For the last two cases, size is a hint for the size of the buffer, in bytes.
The default is an appropriate size.

The specific behavior of each mode is non portable,
check the underlying ISO C function `setvbuf` in your platform for more details.

Returns `true` on success, otherwise `false` plus an error message and a system-dependent error code.

### filestream:read

```nelua
function filestream:read(fmt: overload(integer,string,niltype)): (string, string, integer)
```

Reads the file file, according to the given formats, which specify what to read.

The function returns a string with the characters read.
Otherwise, if it cannot read data with the specified format, it
returns an empty string plus an error message and a system-dependent error code.

The available formats are:

* `"a"`: reads the whole file, starting at the current position.
On end of file, it returns the empty string, this format never fails.
* `"l"`: reads the next line skipping the end of line, returning fail on end of file.
* `"L"`: reads the next line keeping the end-of-line character (if present), returning fail on end of file.
* `integer`: reads a string with up to this number of bytes, returning fail on end of file.
If number is zero, it reads nothing and returns an empty string, or fail on end of file.

The formats `"l"` and `"L"` should be used only for text files.
When called without arguments, it uses the default format `"l"` that reads the next line.

### filestream:write

```nelua
function filestream:write(...: varargs): (boolean, string, integer)
```

Writes the value of each of its arguments to file.
The arguments must be strings or numbers.

Returns `true` on success, otherwise `false` plus an error message and a system-dependent error code.

### filestream:writef

```nelua
function filestream:writef(fmt: string, ...: varargs): (boolean, string, integer)
```

Writes formatted values to the file, according to the given format.

Returns `true` on success, otherwise `false` plus an error message and a system-dependent error code.

### filestream:lines

```nelua
function filestream:lines(fmt: overload(integer,string,niltype))
```

Returns an iterator function that, each time it is called, reads the file according to the given format.
When no format is given, uses `"l"` as a default. As an example, the construction
```nelua
for c in file:lines(1) do body end
```
will iterate over all characters of the file, starting at the current position.

### filestream:isopen

```nelua
function filestream:isopen(): boolean
```

Checks whether the file is open.

### filestream:__tostring

```nelua
function filestream:__tostring(): string
```

Convert the file handle to a string.
Returns `"filed (closed)"` for invalid or closed files,
and `"file (some address)"` for open files.

This metamethod is used by `tostring`.


## math

The math library provides basic mathematical functions.

### math

```nelua
global math: type = @record{}
```

Namespace for math module.

### math.abs

```nelua
function math.abs(x: an_scalar)
```

Returns the absolute value of `x`, that is, the maximum value between `x` and `-x`.

The argument type is always preserved.

### math.floor

```nelua
function math.floor(x: an_scalar)
```

Returns the largest integral value less than or equal to `x`.

### math.ifloor

```nelua
function math.ifloor(x: an_scalar): integer
```

Like `math.floor`, but the result is always converted to an integer.

### math.ceil

```nelua
function math.ceil(x: an_scalar)
```

Returns the smallest integral value greater than or equal to `x`.

### math.iceil

```nelua
function math.iceil(x: an_scalar): integer
```

Like `math.ceil`, but the result is always converted to an integer.

### math.round

```nelua
function math.round(x: an_scalar)
```

Returns the rounded value of `x` towards the nearest integer.
Halfway cases are rounded away from zero.

### math.trunc

```nelua
function math.trunc(x: an_scalar)
```

Returns the rounded value of `x` towards zero.

### math.sqrt

```nelua
function math.sqrt(x: an_scalar)
```

Returns the square root of `x`.
You can also use the expression `x^0.5` to compute this value.

### math.cbrt

```nelua
function math.cbrt(x: an_scalar)
```

Returns the cubic root of `x`.
You can also use the expression `x^(1/3)` to compute this value.

### math.exp

```nelua
function math.exp(x: an_scalar)
```

Returns the value of `e^x` (where `e` is the base of natural logarithms).

### math.exp2

```nelua
function math.exp2(x: an_scalar)
```

Returns the value of `2^x`.
You can also use the expression `2^x` to compute this value.

### math.pow

```nelua
function math.pow(x: an_scalar, y: an_scalar)
```

Returns `x^y`.
You can also use the expression `x^y` to compute this value.

### math.log

```nelua
function math.log(x: an_scalar, base: an_optional_scalar)
```

Returns the logarithm of `x` in the given `base`.
The default for `base` is *e*, so that the function returns the natural logarithm of `x`.

### math.cos

```nelua
function math.cos(x: an_scalar)
```

Returns the cosine of `x` (assumed to be in radians).

### math.sin

```nelua
function math.sin(x: an_scalar)
```

Returns the sine of `x` (assumed to be in radians).

### math.tan

```nelua
function math.tan(x: an_scalar)
```

Returns the tangent of `x` (assumed to be in radians).

### math.acos

```nelua
function math.acos(x: an_scalar)
```

Returns the arc cosine of `x` (in radians).

### math.asin

```nelua
function math.asin(x: an_scalar)
```

Returns the arc sine of `x` (in radians).

### math.atan

```nelua
function math.atan(y: an_scalar, x: an_optional_scalar)
```

Returns the arc tangent of `y/x` (in radians),
but uses the signs of both arguments to find the quadrant of the result.
It also handles correctly the case of `x` being zero.

The default value for `x` is `1`, so that the call `math.atan(y)` returns the arc tangent of `y`.

### math.atan2

```nelua
function math.atan2(y: an_scalar, x: an_optional_scalar)
```

Returns the arc tangent of `y/x` (in radians),
but uses the signs of both arguments to find the quadrant of the result.
It also handles correctly the case of `x` being zero.

### math.cosh

```nelua
function math.cosh(x: an_scalar)
```

Returns the hyperbolic cosine of `x`.

### math.sinh

```nelua
function math.sinh(x: an_scalar)
```

Returns the hyperbolic sine of `x`.

### math.tanh

```nelua
function math.tanh(x: an_scalar)
```

Returns the hyperbolic tangent of `x`.

### math.log10

```nelua
function math.log10(x: an_scalar)
```

Returns the base-10 logarithm of `x`.

### math.log2

```nelua
function math.log2(x: an_scalar)
```

Returns the base-2 logarithm of `x`.

### math.acosh

```nelua
function math.acosh(x: an_scalar)
```

Returns the inverse hyperbolic cosine of `x`.

### math.asinh

```nelua
function math.asinh(x: an_scalar)
```

Returns the inverse hyperbolic sine of `x`.

### math.atanh

```nelua
function math.atanh(x: an_scalar)
```

Returns the inverse hyperbolic tangent of `x`.

### math.deg

```nelua
function math.deg(x: an_scalar)
```

Converts the angle `x` from radians to degrees.

### math.rad

```nelua
function math.rad(x: an_scalar)
```

Converts the angle `x` from degrees to radians.

### math.sign

```nelua
function math.sign(x: an_scalar)
```

Returns the sign of `x`, that is:
* `-1` if `x < 0`
* `0` if `x == 0`
* `1` if `x > 0`

### math.fract

```nelua
function math.fract(x: an_scalar)
```

Returns the fractional part of `x`.

Computed as `x - math.floor(x)`.

### math.mod

```nelua
function math.mod(x: an_scalar, y: an_scalar)
```

Returns the modulo operation of `x` by `y`, rounded towards minus infinity.

This is equivalent to `x % y`, but faster and subject to rounding errors.
It's computed as `x - math.floor(x / y) * y`.

### math.modf

```nelua
function math.modf(x: an_scalar)
```

Returns the integral part of `x` and the fractional part of `x`.
Its second result is always a float.

### math.fmod

```nelua
function math.fmod(x: an_scalar, y: an_scalar)
```

Returns the remainder of the division of `x` by `y` that rounds the quotient towards zero.
The result can either be an integer or a float depending on the arguments.

### math.frexp

```nelua
function math.frexp(x: an_scalar)
```

Returns `m` and `e` such that `x = m*(2^e)`,
`e` is an integer and the absolute value of `m` is in the range [0.5, 1) or zero (when `x` is zero).

### math.ldexp

```nelua
function math.ldexp(m: an_scalar, e: int32)
```

Returns `m*(2^e)`, that is, `m` multiplied by an integral power of 2.

### math.min

```nelua
function math.min(...: varargs)
```

Returns the argument with the minimum value, according to the operator `<`.

### math.max

```nelua
function math.max(...: varargs)
```

Returns the argument with the maximum value, according to the operator `<`.

### math.clamp

```nelua
function math.clamp(x: an_scalar, min: an_scalar, max: an_scalar)
```

Returns the value of `x` clamped between `min` and `max`.

### math.ult

```nelua
function math.ult(m: an_scalar, n: an_scalar): boolean
```

Returns a boolean, `true` if and only if integer `m` is below integer `n`
when they are compared as unsigned integers.

### math.tointeger

```nelua
function math.tointeger(x: an_scalar)
```

If the value `x` is convertible to an integer, returns that integer. Otherwise, returns `nil`.

### math.type

```nelua
function math.type(x: auto)
```

Returns `"integer"` if `x` is an integer, "float" if `x` is a float, or fail if `x` is not a number.

### math.randomseed

```nelua
function math.randomseed(x: an_optional_integral, y: an_optional_integral): (integer, integer)
```

When called with at least one argument,
the integer parameters `x` and `y` are joined into a 128-bit seed that is used
to reinitialize the pseudo-random generator.
Equal seeds produce equal sequences of numbers. The default for `y` is zero.

When called with no arguments, generates a seed with a weak attempt for randomness.

This function returns the two seed components that were effectively used,
so that setting them again repeats the sequence.

To ensure a required level of randomness to the initial state
(or contrarily, to have a deterministic sequence, for instance when debugging a program),
you should call `math.randomseed` with explicit arguments.

### math.random

```nelua
function math.random(m: an_optional_scalar, n: an_optional_scalar)
```

When called without arguments, returns a pseudo-random float with uniform distribution in the range [`0`,`1`).
When called with two integers `m ` and `n`, returns a pseudo-random integer with uniform distribution in the range [`m`, `n`].

The call `math.random(n)`, for a positive `n`, is equivalent to `math.random(1,n)`.
The call `math.random(0)` produces an integer with all bits (pseudo)random.

This function uses an algorithm based on *xoshiro256* to produce pseudo-random 64-bit integers,
which are the results of calls with argument 0.
Other results (ranges and floats) are unbiased extracted from these integers.

Its pseudo-random generator is initialized with the equivalent of a call to `math.randomseed` with no arguments,
so that `math.random` should generate different sequences of results each time the program runs.

### math.pi

```nelua
global math.pi: number
```

Float value of PI.

### math.huge

```nelua
global math.huge: number
```

Float value greater than any other numeric value (infinite).

### math.mininteger

```nelua
global math.mininteger: integer
```

An integer with the minimum value for an integer.

### math.maxinteger

```nelua
global math.maxinteger: integer
```

An integer with the maximum value for an integer.

### math.maxuinteger

```nelua
global math.maxuinteger: uinteger
```

An integer with the maximum value for an unsigned integer.


## memory

The memory library provides low level memory management utilities.

The user is responsible to use valid pointers and memory regions for the library functions,
otherwise the user may experience crashes or undefined behaviors at runtime.
To assist finding such mistakes some checks are performed where applicable, which can
be disabled with the pragma `nochecks`.

### memory

```nelua
global memory: type = @record{}
```

Namespace for memory module.

### memory.copy

```nelua
function memory.copy(dest: pointer, src: pointer, n: usize): void
```

Copies `n` bytes from memory pointed by `src` into memory pointed by `dest`.

The memory region may not overlap, use `memory.move` in that case.

### memory.move

```nelua
function memory.move(dest: pointer, src: pointer, n: usize): void
```

Copies `n` bytes from memory pointed by `src` into memory pointed by `dest`.
The memory region may overlap.

In case the memory region is guaranteed to not overlap, use `memory.copy`.

### memory.set

```nelua
function memory.set(dest: pointer, x: byte, n: usize): void
```

Fills first `n` bytes of the memory pointed by `dest` with the byte `x`.

### memory.zero

```nelua
function memory.zero(dest: pointer, n: usize): void
```

Fills first `n` bytes of the memory pointed by `dest` with zeros.

### memory.compare

```nelua
function memory.compare(a: pointer, b: pointer, n: usize): int32
```

Compares the first `n` bytes of the memory areas pointed by `a` and `b`.

Returns an integer less than, equal to, or greater than zero if the first `n` bytes
of `a` is found, respectively, to be less than, to match, or be greater than the first `n` bytes of `b`.

The sign is determined by the sign of the difference between the first pair of bytes that differ in `a` and `b`.

If `n` is zero, the return value is zero.

### memory.equals

```nelua
function memory.equals(a: pointer, b: pointer, size: usize): boolean
```

Check if the first `n` bytes of the memory areas pointed by `a` and `b` are equal.

Returns `true` if the first `n` bytes of `a` is equal to the first `n` bytes of `b.
If `n` is zero, the return value is `true`.

### memory.scan

```nelua
function memory.scan(src: pointer, x: byte, size: usize): pointer
```

Scan first `n` bytes from memory pointed by `src` for the first instance of byte `x`.

Returns a pointer to the matching byte when found, otherwise `nilptr`.

### memory.find

```nelua
function memory.find(haystack: pointer, haystacksize: usize, needle: pointer, needlesize: usize): pointer
```

Scan first `haystacksize` bytes from memory pointed by `haystack` for the first instance of
the chunk of memory in the region determined by `needle` and `needlesize`.

Returns a pointer to the matching chunk when found, otherwise `nilptr`.

### memory.spancopy

```nelua
function memory.spancopy(dest: an_span, src: an_span): void
```

Like `memory.copy` but operate over spans.

### memory.spanmove

```nelua
function memory.spanmove(dest: an_span, src: an_span): void
```

Like `memory.move` but operate over spans.

### memory.spanset

```nelua
function memory.spanset(dest: an_span, x: auto): void
```

Like `memory.set` but operate over spans.

### memory.spanzero

```nelua
function memory.spanzero(dest: an_span): void
```

Like `memory.zero` but operate over spans.

### memory.spancompare

```nelua
function memory.spancompare(a: an_span, b: an_span): int32
```

Like `memory.compare` but operate over spans.

### memory.spanequals

```nelua
function memory.spanequals(a: an_span, b: an_span): boolean
```

Like `memory.equals` but operate over spans.

### memory.spanfind

```nelua
function memory.spanfind(s: an_span, x: auto): isize
```

Scan span `s` for value `x` and returns its respective index.
In case `x` is not found -1 is returned.


## os

The operating system library provides some operating system facilities.

Some `os` functions behavior may vary across different operating systems,
or not be supported.

### os

```nelua
global os: type = @record{}
```

Namespace for OS module.

### os.clock

```nelua
function os.clock(): number
```

Returns an approximation of the amount in seconds of CPU time used by the program,
as returned by the underlying ISO C function `clock`.

### os.date

```nelua
function os.date(): string
```

Returns a human-readable date and time representation using the current locale.

### os.difftime

```nelua
function os.difftime(t1: integer, t2: integer): integer
```

Returns the difference, in seconds, from time `t1` to time `t2`
(where the times are values returned by `os.time`).

In POSIX, Windows, and some other systems, this value is exactly `t2 - t1`.

### os.execute

```nelua
function os.execute(command: facultative(string)): (boolean, string, integer)
```

Passes command to be executed by an operating system shell.

Its first result is `true` if the command terminated successfully, or `false` otherwise.
After this first result the function returns a string plus a number, as follows:

 * `"exit"`: the command terminated normally; the following number is the exit status of the command.
 * `"unsupported"`: executing command is not supported in the system.

When called without a command, `os.execute` returns a boolean that is `true` if a shell is available.

This function is equivalent to the ISO C function `system`.
This function is system dependent and is not available on all platforms.

### os.exit

```nelua
function os.exit(code: overload(integer,boolean,niltype)): void
```

Calls the ISO C function `exit` to terminate the host program.

If `code` is `true`, the returned status is `EXIT_SUCCESS`.
If `code` is `false`, the returned status is `EXIT_FAILURE`.
If `code` is a number, the returned status is this number.
The default value for code is `true`.

### os.getenv

```nelua
function os.getenv(varname: string): string
```

Returns the value of the process environment variable `varname`.
In case the variable is not defined, an empty string is returned.

### os.remove

```nelua
function os.remove(filename: string): (boolean, string, integer)
```

Deletes the file (or empty directory, on POSIX systems) with the given name.

Returns `true` on success, otherwise `false` plus an error message and a system-dependent error code.

### os.rename

```nelua
function os.rename(oldname: string, newname: string): (boolean, string, integer)
```

Renames the file or directory named `oldname` to `newname`.

Returns `true` on success, otherwise `false` plus an error message and a system-dependent error code.

### os.setlocale

```nelua
function os.setlocale(locale: string, category: facultative(string)): string
```

Sets the current locale of the program.

`locale` is a system-dependent string specifying a locale.
`category` is an optional string describing which category to change:
`"all"`, `"collate"`, `"ctype"`, `"monetary"`, `"numeric"`, or `"time"`;
the default category is "all".

If locale is the empty string, the current locale is set to an implementation-defined native locale.
If locale is the string `"C"`, the current locale is set to the standard C locale.

The function returns the name of the new locale on success,
or an empty string if the request cannot be honored.

### os.timedesc

```nelua
global os.timedesc: type = @record {
  year: integer, month: integer, day: integer,
  hour: integer, min: integer, sec: integer,
  isdst: boolean
}
```

Time description, used by function `os.time`.

### os.time

```nelua
function os.time(desc: facultative(os.timedesc)): integer
```

Returns the current time when called without arguments,
or a time representing the local date and time specified by the given time description.

When the function is called, the values in these fields do not need to be inside their valid ranges.
For instance, if sec is -10, it means 10 seconds before the time specified by the other fields.
If hour is 1000, it means 1000 hours after the time specified by the other fields.

The returned value is a number, whose meaning depends on your system.
In POSIX, Windows, and some other systems,
this number counts the number of seconds since some given start time (the "epoch").
In other systems, the meaning is not specified,
and the number returned by time can be used only as an argument to `os.date` and `os.difftime`.

When called with a record `os.timedesc`, `os.time` also normalizes all the fields,
so that they represent the same time as before the call but with values inside their valid ranges.

### os.tmpname

```nelua
function os.tmpname(): string
```

Returns a string with a file name that can be used for a temporary file.

The file must be explicitly opened before its use and explicitly removed when no longer needed.
In POSIX systems, this function also creates a file with that name, to avoid security risks.
(Someone else might create the file with wrong permissions in the time between getting the name and creating the file.)
You still have to open the file to use it and to remove it (even if you do not use it).
When possible, you may prefer to use `io.tmpfile`, which automatically removes the file when the program ends.


## string

The string library provides functions to manipulate strings.

String points to an immutable contiguous sequence of characters.
Internally it just holds a pointer to a buffer and a size.
It's buffer is zero terminated (`\0`) by default to have more compatibility with C.

The string type is defined by the compiler, however it does not have
its methods implemented, this module implements all string methods.

When the GC is disabled, you should call `destroy` to free the string memory
of any string returned in by this library, otherwise he memory will leak.
Note that strings can point to a buffer in the program static storage
and such strings should never be destroyed.

### string._create

```nelua
function string._create(size: usize): string
```

Allocate a new string to be filled with length `size`.

The string is guaranteed to be zero terminated,
so it can be safely be used as a `cstring`.

Used internally.

### string.destroy

```nelua
function string.destroy(s: string): void
```

Destroys a string freeing its memory.

When GC is enabled this does nothing, because string references can be shared with GC enabled.
This should never be called on string literals.

### string.copy

```nelua
function string.copy(s: string): string
```

Clone a string, allocating new space.

This is useful in case you want to own the string memory,
so you can modify it or manually manage its memory when GC is disabled.

### string._forward

```nelua
function string._forward(s: string): string
```

Forward a string reference to be used elsewhere.

When GC is enabled this just returns the string itself.
When GC is disabled a string copy is returned, so it can be safely stored and destroyed.

### string.byte

```nelua
function string.byte(s: string, i: facultative(isize)): byte
```

Returns the internal numeric codes of the character at position `i`.

### string.sub

```nelua
function string.sub(s: string, i: isize, j: facultative(isize)): string
```

Returns the substring of `s` that starts at `i` and continues until `j` (both inclusive).
Both `i` and `j` can be negative.
If `j` is absent, then it is assumed to be equal to `-1` (which is the same as the string length).
In particular, the call `string.sub(s,1,j)` returns a prefix of `s` with length `j`,
and `string.sub(s, -i)` (for a positive `i`) returns a suffix of `s` with length `i`.

### string.subview

```nelua
function string.subview(s: string, i: isize, j: facultative(isize)): string
```

Return a view for a sub string in a string.

The main difference between this and `string.sub` is that, here we don't allocate a new string,
instead it reuses its memory as an optimization.
Use this only if you know what you are doing, to be safe use `string.sub` instead.

CAUTION: When using the GC the view will not hold reference of the original string,
thus if you don't hold the original string reference somewhere you will have a dangling reference.
The view string may not be zero terminated, thus you should never
cast it to a `cstring` to use in C functions.

### string.find

```nelua
function string.find(s: string, pattern: string, init: facultative(isize), plain: facultative(boolean)): (isize, isize)
```

Looks for the first match of pattern in the string.

Returns the indices of where this occurrence starts and ends.

The indices will be positive if a match is found, zero otherwise.
A third, optional argument specifies where to start the search, its default value is 1 and can be negative.
A value of true as a fourth, optional argument plain turns off the pattern matching facilities.

### string.gmatch

```nelua
function string.gmatch(s: string, pattern: string, init: facultative(isize))
```

Returns an iterator function that, each time it is called, returns the whole match plus a span of captures.
A third, optional argument specifies where to start the search, its default value is 1 and can be negative.

### string.gmatchview

```nelua
function string.gmatchview(s: string, pattern: string, init: facultative(isize))
```

Like `string.gmatch` but uses sub string views (see also `string.subview`).

### string.rep

```nelua
function string.rep(s: string, n: isize, sep: facultative(string)): string
```

Returns a string that is the concatenation of `n` copies of the string `s` separated by the string `sep`.
The default value for `sep` is the empty string (that is, no separator).
Returns the empty string if `n` is not positive.

### string.match

```nelua
function string.match(s: string, pattern: string, init: facultative(isize)): (boolean, sequence(string))
```

Looks for the first match of pattern in the string.
If it finds one, then returns true plus a sequence with the captured values,
otherwise it returns false plus an empty sequence.
If pattern specifies no captures, then the whole match is captured.
A third, optional argument specifies where to start the search, its default value is 1 and can be negative.

### string.matchview

```nelua
function string.matchview(s: string, pattern: string, init: facultative(isize)): (boolean, sequence(string))
```

Like `string.match` but uses sub string views (see also `string.subview`).

### string.reverse

```nelua
function string.reverse(s: string): string
```

Returns a string that is the string `s` reversed.

### string.upper

```nelua
function string.upper(s: string): string
```

Receives a string and returns a copy of this string with all lowercase letters changed to uppercase.
All other characters are left unchanged.
The definition of what a lowercase letter is depends on the current locale.

### string.lower

```nelua
function string.lower(s: string): string
```

Receives a string and returns a copy of this string with all uppercase letters changed to lowercase.
All other characters are left unchanged.
The definition of what an uppercase letter is depends on the current locale.

### string.char

```nelua
function string.char(...: varargs): string
```

Receives zero or more integers and returns a string with length equal to the number of arguments,
in which each character has the internal numeric code equal to its corresponding argument.
Numeric codes are not necessarily portable across platforms.

### string.format

```nelua
function string.format(fmt: string, ...: varargs): string
```

Returns a formatted version of its variable number of arguments following the description
given in its first argument, which must be a string.
The format string follows the same rules as the ISO C function `sprintf`.
The only differences are that the conversion specifiers and modifiers `*, h, L, l` are not supported.

### string.len

```nelua
function string.len(s: string): isize
```

Receives a string and returns its length.
The empty string "" has length 0. Embedded zeros are counted.

### string.__concat

```nelua
function string.__concat(a: string_coercion_concept, b: string_coercion_concept): string
```

Concatenate two strings. Used by the concatenation operator (`..`).

### string.__len

```nelua
function string.__len(a: string): isize
```

Return length of a string. Used by the length operator (`#`).

### string.__eq

```nelua
function string.__eq(a: string, b: string): boolean
```

Compare two strings. Used by the equality operator (`==`).

### string.__lt

```nelua
function string.__lt(a: string, b: string): boolean
```

Compare if string `a` is less than string `b` in lexicographical order.
Used by the less than operator (`<`).

### string.__le

```nelua
function string.__le(a: string, b: string): boolean
```

Compare if string `a` is less or equal than string `b` in lexicographical order.
Used by the less or equal than operator (`<=`).

### string.__add

```nelua
function string.__add(a: scalar_coercion_concept, b: scalar_coercion_concept): number
```

Converts input strings to numbers and returns the result of addition.
Use by the add operator (`+`).

### string.__sub

```nelua
function string.__sub(a: scalar_coercion_concept, b: scalar_coercion_concept): number
```

Converts input strings to numbers and returns the result of subtraction.
Use by the subtract operator (`-`).

### string.__mul

```nelua
function string.__mul(a: scalar_coercion_concept, b: scalar_coercion_concept): number
```

Converts input strings to numbers and returns the result of multiplication.
Use by the multiply operator (`*`).

### string.__div

```nelua
function string.__div(a: scalar_coercion_concept, b: scalar_coercion_concept): number
```

Converts input strings to numbers and returns the result of division.
Use by the division operator (`/`).

### string.__idiv

```nelua
function string.__idiv(a: scalar_coercion_concept, b: scalar_coercion_concept): number
```

Converts input strings to numbers and returns the result of floor division.
Use by the integer division operator (`//`).

### string.__tdiv

```nelua
function string.__tdiv(a: scalar_coercion_concept, b: scalar_coercion_concept): number
```

Converts input strings to numbers and returns the result of truncate division.
Use by the truncate division operator (`///`).

### string.__mod

```nelua
function string.__mod(a: scalar_coercion_concept, b: scalar_coercion_concept): number
```

Converts input strings to numbers and returns the result of floor division remainder.
Use by the modulo operator (`%`).

### string.__tmod

```nelua
function string.__tmod(a: scalar_coercion_concept, b: scalar_coercion_concept): number
```

Converts input strings to numbers and returns the result of truncate division remainder.
Use by the truncate module operator (`%%%`).

### string.__pow

```nelua
function string.__pow(a: scalar_coercion_concept, b: scalar_coercion_concept): number
```

Converts input strings to numbers and returns the result of exponentiation.
Use by the pow operator (`^`).

### string.__unm

```nelua
function string.__unm(a: scalar_coercion_concept): number
```

Converts the input string to a number and returns its negation.
Use by the negation operator (`-`).

### string.__band

```nelua
function string.__band(a: scalar_coercion_concept, b: scalar_coercion_concept): integer
```

Converts input strings to integers and returns the result of bitwise AND.
Use by the bitwise AND operator (`&`).

### string.__bor

```nelua
function string.__bor(a: scalar_coercion_concept, b: scalar_coercion_concept): integer
```

Converts input strings to integers and returns the result of bitwise OR.
Use by the bitwise OR operator (`|`).

### string.__bxor

```nelua
function string.__bxor(a: scalar_coercion_concept, b: scalar_coercion_concept): integer
```

Converts input strings to integers and returns the result of bitwise XOR.
Use by the bitwise XOR operator (`~`).

### string.__shl

```nelua
function string.__shl(a: scalar_coercion_concept, b: scalar_coercion_concept): integer
```

Converts input strings to integers and returns the result of bitwise logical left shift.
Use by the bitwise logical left shift operator (`<<`).

### string.__shr

```nelua
function string.__shr(a: scalar_coercion_concept, b: scalar_coercion_concept): integer
```

Converts input strings to integers and returns the result of bitwise logical right shift.
Use by the bitwise logical right shift operator (`>>`).

### string.__asr

```nelua
function string.__asr(a: scalar_coercion_concept, b: scalar_coercion_concept): integer
```

Converts input strings to integers and returns the result of bitwise arithmetic right shift.
Use by the bitwise arithmetic right shift operator (`>>>`).

### string.__bnot

```nelua
function string.__bnot(a: scalar_coercion_concept): integer
```

Converts the input string to an integer and returns its bitwise NOT.
Use by the bitwise NOT operator (`~`).

### tocstring

```nelua
global function tocstring(buf: *[0]cchar, buflen: usize, s: string): boolean
```

Convert a string to a `cstring` through a temporary buffer.
This is mainly used to ensure the string is zero terminated.

Returns `true` in case of success.

### tostring

```nelua
global function tostring(x: auto): string
```

Convert a value to a string.

### tonumber

```nelua
global function tonumber(x: auto, base: facultative(integer))
```

Convert a value to a number.

### tointeger

```nelua
global function tointeger(x: auto, base: facultative(integer)): integer
```

Convert a value to an integer.


## traits

The traits library provides utilities to gather type information.

### traits

```nelua
global traits: type = @record{}
```

Namespace for traits module.

### traits.typeid

```nelua
global traits.typeid: type = @uint32
```

Type of the identifier for types.

### traits.typeinfo

```nelua
global traits.typeinfo: type = @record{
  id: traits.typeid,
  name: string,
  codename: string
}
```

Record for type information.

### traits.typeidof

```nelua
function traits.typeidof(v: auto): traits.typeid
```

Returns the `typeid` of `v`.
The given `v` can be either a runtime value or a compile-time type.

### traits.typeinfoof

```nelua
function traits.typeinfoof(v: auto): traits.typeinfo
```

Returns type information of `v`.
The given `v` can be either a runtime value or a compile-time type.

### type

```nelua
global function type(v: auto): string
```

Returns the type of `v`, coded as a string, as follows:
* `"nil"` for `niltype`
* `"pointer"` for pointers and `nilptr`
* `"number"` for scalar types
* `"string"` for types that can represent a string

other types not listed here returns the underlying type name.

This function behaves as describe to be compatible with Lua APIs.


## utf8

The UTF-8 library provides basic support for UTF-8 encoding.

The library does not provide any support for Unicode other than the handling of the encoding.
Any operation that needs the meaning of a character,
such as character classification, is outside its scope.

Unless stated otherwise, all functions that expect a byte position as a parameter
assume that the given position is either the start of a byte sequence
or one plus the length of the subject string.
As in the string library, negative indices count from the end of the string.

Functions that create byte sequences accept all values up to `0x7FFFFFFF`,
as defined in the original UTF-8 specification,
that implies byte sequences of up to six bytes.

Functions that interpret byte sequences only accept valid sequences (well formed and not overlong)
By default, they only accept byte sequences that result in valid Unicode code points,
rejecting values greater than `0x10FFFF` and surrogates.
A boolean argument `relax`, when available, lifts these checks,
so that all values up to `0x7FFFFFFF` are accepted.
(Not well formed and overlong sequences are still rejected.)

### utf8

```nelua
global utf8: type = @record{}
```

Namespace for UTF-8 module.

### utf8.charpattern

```nelua
global utf8.charpattern: string
```

Pattern to match exactly one UTF-8 byte sequence, assuming that the subject is a valid UTF-8 string.

### utf8.char

```nelua
function utf8.char(...: varargs): string
```

Receives zero or more integers, converts each one to its corresponding UTF-8 byte sequence,
and returns a string with the concatenation of all these sequences.

### utf8.codes

```nelua
function utf8.codes(s: string, relax: facultative(boolean))
  : (function(string, isize): (boolean, isize, uint32), string, isize)
```

UTF-8 iterator, use to iterate over UTF-8 codes.
It returns values so that the construction
```nelua
for p, c in utf8.codes(s) do end
```
will iterate over all UTF-8 characters in string `s`,
with `p` being the position (in bytes) and `c` the code point of each character.
It raises an error if it meets any invalid byte sequence.

### utf8.codepoint

```nelua
function utf8.codepoint(s: string, i: facultative(isize), relax: facultative(boolean)): uint32
```

Returns the code point (as integer) from the characters in `s` at position `i`.
The default for `i` is `1`.
It raises an error if it meets any invalid byte sequence.

### utf8.offset

```nelua
function utf8.offset(s: string, n: isize, i: facultative(isize)): isize
```

Returns the position (in bytes) where the encoding of the n-th character of `s` starts (counting from position `i`).
A negative `n` gets characters before position `i`.
The default for `i` is `1` when `n` is non-negative and `#s + 1` otherwise,
so that `utf8.offset(s, -n)` gets the offset of the n-th character from the end of the string.
If the specified character is neither in the subject nor right after its end,
the function returns `-1`.

### utf8.len

```nelua
function utf8.len(s: string, i: facultative(isize), j: facultative(isize), relax: facultative(boolean)): (isize, isize)
```

Returns the number of UTF-8 characters in string `s` that start between positions `i` and `j` (both inclusive).
The default for `i` is `1` and for `j` is `-1`.
If it finds any invalid byte sequence, returns `-1` plus the position of the first invalid byte.


## coroutine

The coroutine library provides functions to manipulate coroutines.

A coroutine represents an independent "green" thread of execution.
Unlike threads in multithread systems, however,
a coroutine only suspends its execution by explicitly calling a yield function.

You create a coroutine by calling `coroutine.create`.
Its sole argument is a function that is the body function of the coroutine.
The `create` function only creates a new coroutine and returns a handle to it, it does not start the coroutine.

You execute a coroutine by calling `coroutine.resume`.
When calling a resume function the coroutine starts its execution by calling its body function.
After the coroutine starts running, it runs until it terminates or yields.

A coroutine yields by calling `coroutine.yield`.
When a coroutine yields, the corresponding resume returns immediately,
even if the yield happens inside nested function calls (that is, not in the main function).
In the case of a yield, resume also returns true.
The next time you resume the same coroutine, it continues its execution from the point where it yielded.

At the moment Nelua does not support variable arguments in `yield` and `resume` (unlikely Lua).
To pass values between resume and yield, you must use `coroutine.push` and `coroutine.pop`
with the input and output types known at compile-time.

### coroutine

```nelua
global coroutine: type = @*mco_coro
```

The coroutine handle.

### coroutine.create

```nelua
function coroutine.create(f: auto): coroutine
```

Returns a new coroutine with body function `f`.
The function allocates stack memory and resources for the coroutine.
It only creates a new coroutine and returns a handle to it, it does not start the coroutine.

### coroutine.destroy

```nelua
function coroutine.destroy(co: coroutine): void
```

Destroy the coroutine `co`, freeing its stack memory and resources.

Note that this is only needed to be called when the GC is disabled.

CAUTION: Destroying a coroutine before `"dead"` state will not execute its defer statements.

### coroutine.isyieldable

```nelua
function coroutine.isyieldable(co: coroutine): boolean
```

Checks weather the coroutine `co` can yield.

A coroutine is yieldable if it isn't the main thread.

### coroutine.resume

```nelua
function coroutine.resume(co: coroutine): (boolean, string)
```

Starts or continues the execution of the coroutine `co`.

The first time you resume a coroutine, it starts running its body function.
If the coroutine has yielded, resume continues it.
If the coroutine runs without any errors, resume returns `true` plus an empty error message.
If there is any error, resume returns `false` plus the error message.

### coroutine.yield

```nelua
function coroutine.yield(co: facultative(coroutine)): void
```

Suspends the execution of the coroutine `co`.

On failure raises an error.

### coroutine.push

```nelua
function coroutine.push(co: coroutine, input: auto): (boolean, string)
```

Pushes a value into the coroutine storage.

The value can be received in the next `coroutine.pop` or in the body function arguments (when coroutine starts).
In case of an error returns `false` plus the error message.
The user is responsible to always use the right types and push/pop order and count.

### coroutine.pop

```nelua
function coroutine.pop(co: coroutine, T: type)
```

Pops a value of type `T` from the coroutine `co` storage.

The returned value was send by the last `coroutine.pop` or returned by its body function (when coroutine finishes).
In case of an error returns a zeroed `T`, `false` plus the error message.
The user is responsible to always use the right types and push/pop order and count.

### coroutine.running

```nelua
function coroutine.running(): (coroutine, boolean)
```

Returns the running coroutine plus a boolean that is true when the running coroutine is the main one.

### coroutine.status

```nelua
function coroutine.status(co: coroutine): string
```

Returns the status of the coroutine `co`.

The status string can be any of the following:

* `"running"`, if the coroutine is running (that is, it is the one that called status).
* `"suspended"`, if the coroutine is suspended in a call to yield, or if it has not started running yet.
* `"normal"` if the coroutine is active but not running (that is, it has resumed another coroutine).
* `"dead"` if the coroutine has finished its body function, or if it has been destroyed.


## hash

The hash library provides utilities to generate hash for values.

The included hash functions in this library are intended to be used containers such as `hashmap` and `table`,
thus the hash functions are designed to be fast, and are not necessarily equal across platforms
and may skip bytes.
Use a better hash algorithm in case you need deterministic hash across platforms
and with better quality.

### hash

```nelua
global hash: type = @record{}
```

Namespace for hash module.

### hash.short

```nelua
function hash.short(data: span(byte)): usize
```

Hashes a span of bytes, iterating over all bytes.
This function can be slow for long spans.

### hash.long

```nelua
function hash.long(data: span(byte)): usize
```

Hashes a span of bytes, iterating at most 32 bytes evenly spaced.
This function can be fast to hash long spans, at cost of hash quality.

### hash.combine

```nelua
function hash.combine(seed: usize, value: usize): usize
```

Returns the combination of the hashes `seed` and `value`.

### hash.hash

```nelua
function hash.hash(v: auto): usize
```

Hashes value `v`, used to hash anything.

To customize a hash for a specific record you can define `__hash` metamethod,
and it will be used when calling this function.


## vector

The vector library provides an efficient dynamic sized array or values.

Vector elements starts at index 0 and go up to length-1.

A vector should never be passed by value while being modified, otherwise the behavior is undefined,
in case this is needed then try the `sequence` library.

Any failure when growing a vector raises a panic error.
When checks are enabled, invalid operations (such as out of bounds access) raises a panic error.
When checks are disabled (on release builds or when pragma `nochecks` is active),
invalid operations causes an undefined behavior.

Vectors by default uses the default allocator unless explicitly told not to do so.

### vectorT

```nelua
local vectorT: type = @record {
    data: span(T),
    size: usize,
    allocator: Allocator
  }
```

Vector record defined when instantiating the generic `vector` with type `T`.

### vectorT.make

```nelua
function vectorT.make(allocator: Allocator): vectorT
```

Create a vector using a custom allocator instance.
Useful only when using instanced allocators.

### vectorT:clear

```nelua
function vectorT:clear(): void
```

Removes all elements from the vector.

### vectorT:destroy

```nelua
function vectorT:destroy(): void
```

Free all vector resources and resets it to a zeroed state.
Useful only when not using the garbage collector.

### vectorT:reserve

```nelua
function vectorT:reserve(n: usize): void
```

Reserve at least `n` elements in the vector storage.

### vectorT:resize

```nelua
function vectorT:resize(n: usize): void
```

Resizes the vector so that it contains `n` elements.
When expanding new elements are initialized to zeros.

### vectorT:copy

```nelua
function vectorT:copy(): vectorT
```

Returns a shallow copy of the vector, allocating a new vector.

### vectorT:push

```nelua
function vectorT:push(v: T): void
```

Inserts a element `v` at the end of the vector.

### vectorT:pop

```nelua
function vectorT:pop(): T
```

Removes the last element in the vector and returns its value.
The vector must not be empty.

### vectorT:insert

```nelua
function vectorT:insert(pos: usize, v: T): void
```

Inserts element `v` at position `pos` in the vector.
Elements with index greater or equal than `pos` are shifted up.
The index `pos` must be valid (in the vector bounds).

### vectorT:remove

```nelua
function vectorT:remove(pos: usize): T
```

Removes element at position `pos` in the vector and returns its value.
Elements with index greater than `pos` are shifted down.
The index `pos` must be valid (in the vector bounds).

### vectorT:removevalue

```nelua
function vectorT:removevalue(v: T): boolean
```

Removes the first item from the vector whose value is `v`.
The remaining elements are shifted.
Returns `true` if an element was removed, otherwise `false`.

### vectorT:removeif

```nelua
function vectorT:removeif(pred: function(v: T): boolean): void
```

Removes all elements from the vector where `pred` function returns `true`.
The remaining elements are shifted.

### vectorT:capacity

```nelua
function vectorT:capacity(): isize
```

Returns the number of elements the vector can store before triggering a reallocation.

### vectorT:__atindex

```nelua
function vectorT:__atindex(i: usize): *T
```

Returns reference to element at index `pos`, the index must be valid.
Used when indexing elements with square brackets (`[]`).

### vectorT:__len

```nelua
function vectorT:__len(): isize
```

Returns the number of elements in the vector.
Used by the length operator (`#`).

### vectorT.__convert

```nelua
function vectorT.__convert(values: an_arrayT): vectorT
```

Initializes vector elements from a fixed array.
Used to initialize vector elements with curly braces (`{}`).

### vector

```nelua
global vector: type
```

Generic used to instantiate a vector type in the form of `vector(T, Allocator)`.

Argument `T` is the value type that the vector will store.
Argument `Allocator` is an allocator type for the container storage,
in case absent then `DefaultAllocator` is used.


## list

The list library provides a double linked list container.

A double linked list is a dynamic sized container that supports
constant time insertion and removal from anywhere in the container.

However doubled linked lists don't support fast random access,
use a vector or sequence in that case.

### listnodeT

```nelua
local listnodeT: type = @record {
    prev: *listnodeT,
    next: *listnodeT,
    value: T
  }
```

List node record defined when instantiating the generic `list`.

### listT

```nelua
local listT: type = @record{
    front: *listnodeT,
```

List record defined when instantiating the generic `list`.

### listT.make

```nelua
function listT.make(allocator: Allocator): listT
```

Creates a list using a custom allocator instance.
This is only to be used when not using the default allocator.

### listT:clear

```nelua
function listT:clear(): void
```

Remove all elements from the list.

*Complexity*: O(n).

### listT:destroy

```nelua
function listT:destroy(): void
```

Resets the list to zeroed state, freeing all used resources.

This is more useful to free resources when not using the garbage collector.

### listT:pushfront

```nelua
function listT:pushfront(value: T): void
```

Inserts an element at beginning of the list.

*Complexity*: O(1).

### listT:pushback

```nelua
function listT:pushback(value: T): void
```

Adds an element at the end of the list.

*Complexity*: O(1).

### listT:popfront

```nelua
function listT:popfront(): T
```

Removes the first element and returns it.
If the list is empty, then throws a runtime error on debug builds.

*Complexity*: O(1).

### listT:popback

```nelua
function listT:popback(): T
```

Removes the first element and returns it.
If the list is empty, then throws a runtime error on debug builds.

*Complexity*: O(1).

### listT:find

```nelua
function listT:find(value: T): *listnodeT
```

Find an element in the list, returning it's node reference when found.

*Complexity*: O(1).

### listT:erase

```nelua
function listT:erase(node: *listnodeT): *listnodeT
```

Erases a node from the list.
If the node not in the list, then throws a runtime error on debug builds.

*Complexity*: O(1).

### listT:empty

```nelua
function listT:empty(): boolean
```

Returns whether the list is empty.

### listT:__len

```nelua
function listT:__len(): isize
```

Returns the number of elements in the list.

*Complexity*: O(n).

### listT:__next

```nelua
function listT:__next(node: *listnodeT): (boolean, *listnodeT, T)
```

Returns the next node of the list and its element.
Used with `pairs()` iterator.

### listT:__mnext

```nelua
function listT:__mnext(node: *listnodeT): (boolean, *listnodeT, *T)
```

Returns the next node of the list and its element by reference.
Used with `pairs()` iterator.

### listT:__pairs

```nelua
function listT:__pairs()
```

Allow using `pairs()` to iterate the container.

### listT:__mpairs

```nelua
function listT:__mpairs()
```

Allow using `mpairs()` to iterate the container.

### list

```nelua
global list: type
```

Generic used to instantiate a list type in the form of `list(T, Allocator)`.

Argument `T` is the value type that the list will store.
Argument `Allocator` is an allocator type for the container storage,
in case absent then then `DefaultAllocator` is used.


## hashmap

Hash map is an associative container that contains key-value pairs with unique keys.
Search, insertion, and removal of elements have average constant-time complexity.

The hash map share similarities with Lua tables but should not be used like them,
main differences:
 * There is no array part.
 * The length operator returns number of elements in the map.
 * Indexing automatically inserts a key-value pair, to avoid this use `peek()` or `has()` methods.
 * Values cannot be nil or set to nil.
 * Can only use `pairs()` to iterate.

### hashmapnodeT

```nelua
local hashmapnodeT: type = @record {
    key: K,
    value: V,
    next: usize
  }
```

Hash map node record defined when instantiating the generic `hashmap`.

### hashmapT

```nelua
local hashmapT: type = @record{
    buckets: span(usize),
    nodes: span(hashmapnodeT),
    size: usize,
    allocator: Allocator
  }
```

Hash map record defined when instantiating the generic `hashmap`.

### hashmapT.make

```nelua
function hashmapT.make(allocator: Allocator): hashmapT
```

Creates a hash map using a custom allocator instance.
This is only to be used when not using the default allocator.

### hashmapT:destroy

```nelua
function hashmapT:destroy(): void
```

Resets the container to a zeroed state, freeing all used resources.

*Complexity*: O(1).

### hashmapT:clear

```nelua
function hashmapT:clear(): void
```

Remove all elements from the container.

*Complexity*: O(n).

### hashmapT:_find

```nelua
function hashmapT:_find(key: K): (usize, usize, usize)
```

Used internally to find a value at a key returning it's node index.

### hashmapT:rehash

```nelua
function hashmapT:rehash(count: usize): void
```

Sets the number of buckets to at least `count` and rehashes the container when needed.

*Complexity*: Average case O(n).

### hashmapT:reserve

```nelua
function hashmapT:reserve(count: usize): void
```

Sets the number of buckets to the number needed to accommodate at least `count` elements
without exceeding maximum load factor and rehashes the container when needed.

*Complexity*: Average case O(n).

### hashmapT:_at

```nelua
function hashmapT:_at(key: K): usize
```

Used internally to find or make a value at a key returning it's node index.

### hashmapT:__atindex

```nelua
function hashmapT:__atindex(key: K): *V
```

Returns a reference to the value that is mapped to a key,
performing an insertion if such key does not exist.
This allows indexing the hash map with square brackets `[]`.

*Complexity*: Average case O(1).

### hashmapT:has

```nelua
function hashmapT:has(key: K): boolean
```

Checks if there is an element with a key in the container.

*Complexity*: Average case O(1).

### hashmapT:peek

```nelua
function hashmapT:peek(key: K): *V
```

Returns a reference to the value that is mapped to a key.
If no such element exists, returns `nilptr`.

*Complexity*: Average case O(1).

### hashmapT:remove

```nelua
function hashmapT:remove(key: K): boolean
```

Removes an element with a key from the container (if it exists).
Returns `true` if an element was actually removed.

*Complexity*: Average case O(1).

### hashmapT:loadfactor

```nelua
function hashmapT:loadfactor(): number
```

Returns the average number of elements per bucket.

### hashmapT:bucketcount

```nelua
function hashmapT:bucketcount(): usize
```

Returns the number of buckets in the container.

### hashmapT:capacity

```nelua
function hashmapT:capacity(): usize
```

Returns the number of elements the container can store before triggering a rehash.

### hashmapT:__len

```nelua
function hashmapT:__len(): isize
```

Returns the number of elements in the container.

### hashmapT:__pairs

```nelua
function hashmapT:__pairs()
```

Allow using `pairs()` to iterate the container.

### hashmapT:__mpairs

```nelua
function hashmapT:__mpairs()
```

Allow using `mpairs()` to iterate the container.

### hashmap

```nelua
global hashmap: type
```

Generic used to instantiate a hash map type in the form of `hashmap(K, V, HashFunc, Allocator)`.

Argument `K` is the key type for the hash map.
Argument `V` is the value type for the hash map.
Argument `HashFunc` is a function to hash a key,
in case absent then a default hash function is used.
Argument `Allocator` is an allocator type for the container storage,
in case absent then then `DefaultAllocator` is used.


<a href="/diffs/" class="btn btn-outline-primary btn-lg float-right">Differences >></a>
