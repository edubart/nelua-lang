---
layout: docs
title: Libraries
permalink: /libraries/
categories: docs toc
toc: true
order: 4
---

This is a list of built-in libraries in Nelua.
{: .lead}

To use a library, use `require 'libraryname'`{:.language-nelua}.
{: .callout.callout-info}

This page is under construction and is very incomplete.
{: .callout.callout-info}

## arg

The [arg library](https://github.com/edubart/nelua-lang/blob/master/lib/arg.nelua) allows to use command line arguments from the entry point.

| Variable Name | Description |
|---------------|------|
| `global arg: sequence(stringview, GeneralAllocator)`{:.language-nelua} | Sequence of command line arguments. |
{: .table.table-bordered.table-striped.table-sm}

## builtins

Builtins defined in the compiler. 

| Variable Name | Description |
|---------------|------|
| `global print(...: varargs)`{:.language-nelua} | Print values to `stdout` separated by tabs and with a new line. |
| `global panic([msg: stringview])`{:.language-nelua} | Exit application with a fatal unrecoverable error. |
| `global error([msg: stringview])`{:.language-nelua} | Like `panic` but prints source location. |
| `global warn(msg: stringview)`{:.language-nelua} | Print a warning to `stderr`. |
| `global assert([cond: T [, msg: stringview]]): T`{:.language-nelua} | Thrown a runtime error if `cond` evaluates to false, otherwise returns it. |
| `global check([cond: boolean [, msg: stringview]])`{:.language-nelua} | Similar to `assert` but can be disabled with `-Pnochecks`. |
| `global likely(x: boolean): boolean`{:.language-nelua} | Branching prediction utility. |
| `global unlikely(x: boolean): boolean`{:.language-nelua} | Branching prediction utility. |
| `global _VERSION: stringview`{:.language-nelua} | A string of Nelua version. |
{: .table.table-bordered.table-striped.table-sm}

## iterators

The [iterators library](https://github.com/edubart/nelua-lang/blob/master/lib/iterators.nelua) contains iterator-related functions.

| Variable Name | Description |
|---------------|------|
| `ipairs(list: L): (Next, *L, integer)`{:.language-nelua} | Use with `for in`{:.language-nelua} to iterate contiguous containers. Works with `vector`, `sequence`, `span` and `array`. |
| `mipairs(list: L): (Next, *L, integer)`{:.language-nelua} | Like `ipairs` but yields reference to elements so that you can modify. |
| `pairs(list: L): (Next, *L, K)`{:.language-nelua} | Use with `for in`{:.language-nelua} to iterate containers. |
| `mpairs(list: L): (Next, *L, K)`{:.language-nelua} | Like `pairs` but yields reference to elements so that you can modify. |
| `next(list: L, [index: K]): (boolean, K, T)`{:.language-nelua} | Get the next element from a container. Works with `vector`, `sequence`, `span` and `array`. |
| `mnext(list: L, [index: K]): (boolean, K, *T)`{:.language-nelua} | Like `next` but returns reference to elements so that you can modify. |
{: .table.table-bordered.table-striped.table-sm}

## filestream

The [filestream library](https://github.com/edubart/nelua-lang/blob/master/lib/filestream.nelua) contains filestream records, mainly used for the [`io`](https://nelua.io/libraries/#io) library.

| Variable Name | Description |
|---------------|------|
| `global filestream`{:.language-nelua} | `filestream` record. |
| `filestream.id: uint64`{:.language-nelua} | file id. |
| `filestream.open(filename: stringview[, mode: stringview]): (filestream, stringview, integer)`{:.language-nelua} | Opens a file with given mode (default is `"r"`{:.language-nelua}). Returns empty filesystem, error message and error code if failed. |
| `filestream:flush(): (boolean, stringview, integer)`{:.language-nelua} | Flushes the file. |
| `filestream:close(): (boolean, stringview, integer)`{:.language-nelua} | Closes the file. |
| `filestream:seek([whence: stringview[, offset: integer]]): (integer, stringview, integer)`{:.language-nelua} | Returns the caret position or goes to given offset or returns the size. |
| `filestream:setvbuf(mode: stringview[, size: integer])`{:.language-nelua} | Sets buffer size. |
| `filestream:read(fmt: [integer, stringview, niltype]): (string, stringview, integer)`{:.language-nelua} | Reads the content of the file according to the given format. |
| `filestream:write(s: stringview): (boolean, stringview, integer)`{:.language-nelua} | Writes text to the file. |
| `filestream:lines(fmt: [integer,stringview,niltype]): (function(state: LinesState, prevstr: string): (boolean, string), LinesState, string)`{:.language-nelua} | Returns an iterator function that, each time it is called, reads the file according to the given formats. When no format is given, uses `"l"`{:.language-nelua} as a default. |
| `filestream:isopen(): boolean`{:.language-nelua} | Returns open state of the file. |
| `filestream:__tostring(): string`{:.language-nelua} | converts the handled `*FILE` to `string`. |
{: .table.table-bordered.table-striped.table-sm}

## io

The [IO library](https://github.com/edubart/nelua-lang/blob/master/lib/io.nelua) copies Lua's `io`{:.language-nelua} library. 

| Variable Name | Description |
|---------------|------|
| `global io`{:.language-nelua} | `io` record. |
| `global io.stderr: filestream`{:.language-nelua} | Error file. |
| `global io.stdout: filestream`{:.language-nelua} | Output file used for io.write. |
| `global io.stdin: filestream`{:.language-nelua} | Input file used for io.read. |
| `io.open(filename: stringview[, mode: stringview]) : (filestream, stringview, integer)`{:.language-nelua} | Opens a file. Alias of `filestream.open`. |
| `io.popen(command: stringview[, mode: stringview]) : (filestream, stringview, integer)`{:.language-nelua} | Execute a command and returns it's filestream. |
| `io.flush(): boolean`{:.language-nelua} | Flushes stdout. |
| `io.close([file])`{:.language-nelua} | Alias of `file:close`. Closes `io.stdout` if no file was given. |
| `io.input(file: [stringview, filestream, niltype]): filestream`{:.language-nelua} | Sets, opens or returns the input file. |
| `io.output(file: [stringview, filestream, niltype]): filestream`{:.language-nelua} | Sets, opens or returns the output file. |
| `io.tmpfile(): (filestream, stringview, integer)`{:.language-nelua} | In case of success, returns a handle for a temporary file. This file will automatically removed when the program ends. |
| `io.read(fmt: [integer, stringview, niltype]): (string, stringview, integer)`{:.language-nelua} | Alias of `io.stdin:read`. |
| `io.write(s: stringview): (boolean, stringview, integer)`{:.language-nelua} | Alias of `io.stdout:write`. |
| `io.type(x: auto)`{:.language-nelua} | Returns a type of a file as a string. Returns `nil` if not a file. |
| `io.isopen(file: filestream): boolean`{:.language-nelua} | Alias of `file:isopen`. |
| `io.lines([filename: stringview, fmt: [integer,stringview,niltype]])`{:.language-nelua} | When no `filename` is given, is an alias of `io.stdin:lines()`{:.language-nelua}, otherwise, it opens the given `filename` and returns an iterator function of `file:lines(fmt)`{:.language-nelua} over the opened file. |
{: .table.table-bordered.table-striped.table-sm}

## math

The [math library](https://github.com/edubart/nelua-lang/blob/master/lib/math.nelua) copies Lua's `math`{:.language-nelua} library with extra functions.

| Variable Name | Description |
|---------------|------|
| `global math`{:.language-nelua} | `math` record |
| `global math.pi`{:.language-nelua} | The compile-time value of `#[math.pi]#`{:.language-nelua}, which is the the value of π. |
| `global math.huge`{:.language-nelua} | The compile-time value of `#[math.huge]#`{:.language-nelua}, which is a value greater than any other numeric value. |
| `global math.maxinteger`{:.language-nelua} | The maximum possible compile-time value of `integer`. |
| `global math.mininteger`{:.language-nelua} | The minimum possible compile-time value of `integer`. |
| `math.abs(x)`{:.language-nelua} | Returns the absolute value of `x`. |
| `math.ceil(x)`{:.language-nelua} | Returns the smallest integral value greater than or equal to `x`. |
| `math.floor(x)`{:.language-nelua} | Returns the largest integral value less than or equal to `x`. |
| `math.ifloor(x): integer`{:.language-nelua} | Returns the result of `math.floor(x)`{:.language-nelua}, but returns an `integer`. |
| `math.sqrt(x)`{:.language-nelua} | Returns the square root of `x`. |
| `math.exp(x)`{:.language-nelua} | Returns the value eˣ (where e is the base of natural logarithms). |
| `math.acos(x)`{:.language-nelua} | Returns the arc cosine of `x` (in radians). |
| `math.asin(x)`{:.language-nelua} | Returns the arc sine of `x` (in radians). |
| `math.cos(x)`{:.language-nelua} | Returns the cosine of `x` (assumed to be in radians). |
| `math.sin(x)`{:.language-nelua} | Returns the sine of `x` (assumed to be in radians). |
| `math.tan(x)`{:.language-nelua} | Returns the tangent of `x` (assumed to be in radians). |
| `math.cosh(x)`{:.language-nelua} | Returns the hyperbolic cosine of `x`. |
| `math.sinh(x)`{:.language-nelua} | Returns the hyperbolic sine of `x`. |
| `math.tanh(x)`{:.language-nelua} | Returns the hyperbolic tangent of `x`. |
| `math.log10(x)`{:.language-nelua} | Returns the base-10 logarithm of `x`. |
| `math.max(x, y)`{:.language-nelua} | Returns the argument with the maximum value, according to the Nelua operator <. |
| `math.min(x, y)`{:.language-nelua} | Returns the argument with the minimum value, according to the Nelua operator <. |
| `math.fmod(x, y)`{:.language-nelua} | Returns the remainder of the division of `x` by `y` that rounds the quotient towards zero. |
| `math.atan2(y, x)`{:.language-nelua} | Returns the arc tangent of `y`/`x` (in radians), but uses the signs of both parameters to find the quadrant of the result. (It also handles correctly the case of `x` being zero.). |
| `math.pow(x, y)`{:.language-nelua} | Returns xʸ. (You can also use the expression `x^y`{:.language-nelua} to compute this value.). |
| `math.atan(y[, x])`{:.language-nelua} | If `x` argument is passed, it returns the same value as `math.atan2(y, x)`{:.language-nelua}, otherwise it returns the arc tangent of `y` (in radians). |
| `math.log(x[, base])`{:.language-nelua} | If `base` argument is passed, it returns the logarithm of `x` in the given `base`, otherwise it returns the natural logarithm of `x`). |
| `math.deg(x)`{:.language-nelua} | Converts the angle `x` from radians to degrees. |
| `math.rad(x)`{:.language-nelua} | Returns the angle `x` (given in degrees) in radians. |
| `math.modf(x)`{:.language-nelua} | Returns the integral part of `x` and the fractional part of `x`. |
| `math.frexp(x)`{:.language-nelua} | Returns `m` (multiplier) and `e` (exponent) such that _x = m2ᵉ_, `e` is an `integer` and the absolute value of `m` is in the range [0.5, 1) (or zero when `x` is zero). |
| `math.ldexp(m, e)`{:.language-nelua} | Returns _m2ᵉ_ (`e` should be an integral). |
| `math.tointeger(x)`{:.language-nelua} | If the value `x` is convertible to an `integer`, returns that integer. Otherwise, returns `nil`. |
| `math.type(x)`{:.language-nelua} | Returns `"integer"`{:.language-nelua} if `x` is an integral, `"float"`{:.language-nelua} if it is a float, or `"nil"`{:.language-nelua} if `x` is not a number. |
| `math.ult(m, n)`{:.language-nelua} | Both `m` and `n` should be convertible to an `integer`; returns `true` if and only if integer `m` is below integer `n` when they are compared as unsigned integers. |
| `math.randomseed(x)`{:.language-nelua} | Sets `x` as the "seed" for the pseudo-random generator: equal seeds produce equal sequences of numbers. |
| `math.random([m[, n]])`{:.language-nelua} | When called without arguments, returns a pseudo-random float with uniform distribution in the range [0,1). When called with two integers `m` and `n`, it returns a pseudo-random `integer` with uniform distribution in the range [`m`, `n`]. The call `math.random(n)`{:.language-nelua}, for a positive `n`, is equivalent to `math.random(1,n)`{:.language-nelua}. |
{: .table.table-bordered.table-striped.table-sm}

## memory

[Memory library](https://github.com/edubart/nelua-lang/blob/master/lib/memory.nelua) description (TODO)

| Variable Name | Description |
|---------------|------|
| `global memory`{:.language-nelua} | `memory` record |
| `memory.copy(dest: pointer, src: pointer, size: usize)`{:.language-nelua} |  |
| `memory.move(dest: pointer, src: pointer, size: usize)`{:.language-nelua} |  |
| `memory.set(dest: pointer, x: byte, size: usize)`{:.language-nelua} |  |
| `memory.zero(dest: pointer, size: usize) `{:.language-nelua} |  |
| `memory.compare(a: pointer, b: pointer, size: usize): int32`{:.language-nelua} |  |
| `memory.equals(a: pointer, b: pointer, size: usize): boolean`{:.language-nelua} |  |
| `memory.scan(p: pointer, x: byte, size: usize): pointer`{:.language-nelua} |  |
| `memory.find(haystack: pointer, haystacksize: usize, needle: pointer, needlesize: usize): pointer`{:.language-nelua} |  |
| `memory.spancopy(dest: is_span, src: is_span)`{:.language-nelua} |  |
| `emory.spanmove(dest: is_span, src: is_span)`{:.language-nelua} |  |
| `memory.spanset(dest: is_span, x: auto)`{:.language-nelua} |  |
| `memory.spanzero(dest: is_span)`{:.language-nelua} |  |
| `memory.spancompare(a: is_span, b: is_span): int32`{:.language-nelua} |  |
| `memory.spanequals(a: is_span, b: is_span): boolean`{:.language-nelua} |  |
| `memory.spanfind(s: is_span, x: auto): isize`{:.language-nelua} |  |
| `memory.spancontains(s: is_span, x: auto): boolean`{:.language-nelua} |  |
{: .table.table-bordered.table-striped.table-sm}

## os

The [OS library](https://github.com/edubart/nelua-lang/blob/master/lib/os.nelua) copies Lua's `os`{:.language-nelua} library. 

| Variable Name | Description |
|---------------|------|
| `global os`{:.language-nelua} | `os` record. |
| `os.clock(): number`{:.language-nelua} | Returns an approximation of the amount in seconds of CPU time used by the program, as returned by the underlying ISO C function `clock`. |
| `os.date(): string`{:.language-nelua} | Returns a human-readable date and time representation `string` using the current locale. |
| `os.difftime(t1: integer, t2: integer): integer`{:.language-nelua} | Returns the difference, in seconds, from time `t1` to time `t2` (where the times are values returned by `os.time`{:.language-nelua}) |
| `os.execute([command: stringview])`{:.language-nelua} |  This function is equivalent to the ISO C function `system`. It passes `command` to be executed by an operating system shell. It returns three values, the first value is a boolean indicating if the command terminated successfully; the second and third values are a `stringview` (either `"exit"`{:.language-nelua} or `"signal"`{:.language-nelua}) and a `cint` (either correspondent exit status of the command or the signal that terminated the command). When called without a `command`, `os.execute`{:.language-nelua} returns a boolean that is true if a shell is available. |
| `os.exit(code: [integer, boolean, niltype])`{:.language-nelua} | Calls the ISO C function `exit` to terminate the host program. If code is `true`, the returned status is `EXIT_SUCCESS`; if code is `false`, the returned status is `EXIT_FAILURE`; if code is a `number`, the returned status is this number. When called without a `code`, the returned status is `EXIT_SUCCESS`. |
| `os.getenv(varname: stringview): string`{:.language-nelua} | Returns the value of the process environment variable `varname` or an empty string if the variable is not defined. |
| `os.remove(filename: stringview): (boolean, stringview, integer)`{:.language-nelua} | Deletes the file (or empty directory, on POSIX systems) with the given name. If this function fails, it returns `false` plus a string describing the error and the error code. Otherwise, it returns `true`, an empty string and `0`. |
| `os.rename(oldname: stringview, newname: stringview): (boolean, stringview, integer)`{:.language-nelua} | Renames the file or directory named oldname to newname. If this function fails, it returns `false` plus a string describing the error and the error code. Otherwise, it returns `true`, an empty string and `0`. |
| `os.setlocale(locale: stringview[, category: stringview]): string`{:.language-nelua} | Sets the current locale of the program. `locale` is a system-dependent string specifying a locale; category is an optional string describing which category to change: `"all"`, `"collate"`, `"ctype"`, `"monetary"`, `"numeric"`, or `"time"`; the default category is "all". The function returns the name of the new locale, or an empty string if the request cannot be honored. If locale is the empty string, the current locale is set to an implementation-defined native locale. If locale is the string "C", the current locale is set to the standard C locale. This function may be not thread safe because of its reliance on C function setlocale. |
| `global os_time_desc`{:.language-nelua} | the `os_time_desc` record, contains, declared in that order, `year`, `month`, `day`, `hour`, `min` and `sec` `integer` fields and a `isdst` `boolean` field. |
| `os.time([desc: os_time_desc]): integer`{:.language-nelua} | Returns the current time when called without arguments, or a time representing the local date and time specified by the given `desc`. |
| `os.tmpname(): string`{:.language-nelua} |  Returns a `string` with a file name that can be used for a temporary file. The file must be explicitly opened before its use and explicitly removed when no longer needed. In POSIX systems, this function also creates a file with that name, to avoid security risks. (Someone else might create the file with wrong permissions in the time between getting the name and creating the file.) You still have to open the file to use it and to remove it (even if you do not use it). When possible, you may prefer to use `io.tmpfile`{:.language-nelua}, which automatically removes the file when the program ends. |
{: .table.table-bordered.table-striped.table-sm}

## resourcepool

[Resource Pool](https://github.com/edubart/nelua-lang/blob/master/lib/resourcepool.nelua) library description (TODO)

| Variable Name | Description |
|---------------|------|
| `resourcepool`{:.language-nelua} | Resourcepool constructor. |
{: .table.table-bordered.table-striped.table-sm}

## sequence

[Sequence library](https://github.com/edubart/nelua-lang/blob/master/lib/sequence.nelua) description (TODO)

| Variable Name | Description |
|---------------|------|
| `sequence`{:.language-nelua} | Sequence constructor. |
{: .table.table-bordered.table-striped.table-sm}

## span

[Span library](https://github.com/edubart/nelua-lang/blob/master/lib/span.nelua) description (TODO)

| Variable Name | Description |
|---------------|------|
| `span`{:.language-nelua} | Span constructor |
{: .table.table-bordered.table-striped.table-sm}

## string

[String library](https://github.com/edubart/nelua-lang/blob/master/lib/string.nelua) description (TODO)

| Variable Name | Description |
|---------------|------|
| `string`{:.language-nelua} | String type. |
| `tostring`{:.language-nelua} | Converts values to string using `__tostring`{:.language-nelua}. |
| `string.__tocstring`{:.language-nelua} |  |
| `string.__tostringview`{:.language-nelua} |  |
| `string.__convert`{:.language-nelua} |  |
| `string.sub`{:.language-nelua} |  |
| `string.rep`{:.language-nelua} |  |
| `string.reverse`{:.language-nelua} |  |
| `string.upper`{:.language-nelua} |  |
| `string.lower`{:.language-nelua} |  |
| `string.char`{:.language-nelua} |  |
| `string.format`{:.language-nelua} |  |
| `string.__concat`{:.language-nelua} |  |
| `string.__len`{:.language-nelua} |  |
| `string.__eq`{:.language-nelua} |  |
| `string.__lt`{:.language-nelua} |  |
| `string.__le`{:.language-nelua} |  |
| `string.__add`{:.language-nelua} |  |
| `string.__sub`{:.language-nelua} |  |
| `string.__mul`{:.language-nelua} |  |
| `string.__div`{:.language-nelua} |  |
| `string.__idiv`{:.language-nelua} |  |
| `string.__tdiv`{:.language-nelua} |  |
| `string.__mod`{:.language-nelua} |  |
| `string.__tmod`{:.language-nelua} |  |
| `string.__pow`{:.language-nelua} |  |
| `string.__unm`{:.language-nelua} |  |
| `string.__band`{:.language-nelua} |  |
| `string.__bor`{:.language-nelua} |  |
| `string.__bxor`{:.language-nelua} |  |
| `string.__shl`{:.language-nelua} |  |
| `string.__shr`{:.language-nelua} |  |
| `string.__bnot`{:.language-nelua} |  |
| `string.len`{:.language-nelua} |  |
| `string.byte`{:.language-nelua} |  |
| `string.find`{:.language-nelua} |  |
| `string.subview`{:.language-nelua} |  |
| `stringview.__concat`{:.language-nelua} |  |
| `stringview.rep`{:.language-nelua} |  |
| `stringview.sub`{:.language-nelua} |  |
| `stringview.reverse`{:.language-nelua} |  |
| `stringview.upper`{:.language-nelua} |  |
| `stringview.lower`{:.language-nelua} |  |
| `stringview.format`{:.language-nelua} |  |
{: .table.table-bordered.table-striped.table-sm}

## stringbuilder

[String Builder library](https://github.com/edubart/nelua-lang/blob/master/lib/stringbuilder.nelua) description (TODO)

| Variable Name | Description |
|---------------|------|
| `stringbuilder.make`{:.language-nelua} | Stringbuilder constructor. |
{: .table.table-bordered.table-striped.table-sm}

## stringview

[String View library](https://github.com/edubart/nelua-lang/blob/master/lib/stringview.nelua) description (TODO)

| Variable Name | Description |
|---------------|------|
| `tostringview`{:.language-nelua} |  |
| `tonumber`{:.language-nelua} |  |
| `tointeger`{:.language-nelua} |  |
| `stringview.__len`{:.language-nelua} |  |
| `stringview.__eq`{:.language-nelua} |  |
| `stringview.__lt`{:.language-nelua} |  |
| `stringview.__le`{:.language-nelua} |  |
| `stringview.len`{:.language-nelua} |  |
| `stringview.byte`{:.language-nelua} |  |
| `stringview.subview`{:.language-nelua} |  |
| `stringview.find`{:.language-nelua} |  |
| `stringview.__add`{:.language-nelua} |  |
| `stringview.__sub`{:.language-nelua} |  |
| `stringview.__mul`{:.language-nelua} |  |
| `stringview.__div`{:.language-nelua} |  |
| `stringview.__idiv`{:.language-nelua} |  |
| `stringview.__tdiv`{:.language-nelua} |  |
| `stringview.__mod`{:.language-nelua} |  |
| `stringview.__tmod`{:.language-nelua} |  |
| `stringview.__pow`{:.language-nelua} |  |
| `stringview.__unm`{:.language-nelua} |  |
| `stringview.__band`{:.language-nelua} |  |
| `stringview.__bor`{:.language-nelua} |  |
| `stringview.__bxor`{:.language-nelua} |  |
| `stringview.__shl`{:.language-nelua} |  |
| `stringview.__shr`{:.language-nelua} |  |
| `stringview.__bnot`{:.language-nelua} |  |
{: .table.table-bordered.table-striped.table-sm}

## traits

The [traits library](https://github.com/edubart/nelua-lang/blob/master/lib/traits.nelua) contains useful functions to get information about types at runtime.

| Variable Name | Description |
|---------------|------|
| `global typeid: type`{:.language-nelua} | type alias of `uint32`. |
| `global typeid_of(val: auto): typeid`{:.language-nelua} | Returns the `typeid` of the given `val`. |
| `global type(x: auto): stringview`{:.language-nelua} | Returns the type of its only argument, coded as a string. |
| `global typeinfo`{:.language-nelua} | `typeinfo` record. |
| `global typeinfo_of(x: auto): typeinfo`{:.language-nelua} | Return the `typeinfo` of the given `x`. |
{: .table.table-bordered.table-striped.table-sm}

## vector

The [Vector library](https://github.com/edubart/nelua-lang/blob/master/lib/vector.nelua) is an efficient vector implementation.

| Variable Name | Description |
|---------------|------|
| `vector(T)`{:.language-nelua} | Generic vector type expression. |
| `vectorT.data: span(T)`{:.language-nelua} | Elements storage of the vector. |
| `vectorT.size: usize`{:.language-nelua} | Number of elements in the vector. |
| `vectorT.allocator: Allocator`{:.language-nelua} | Allocator of the vector. |
| `vectorT.make(allocator)`{:.language-nelua} | Create a vector using a custom allocator instance. |
| `vectorT:clear()`{:.language-nelua} | Removes all elements from the vector. |
| `vectorT:destroy()`{:.language-nelua} | Resets the vector to zeroed state, freeing all used resources. |
| `vectorT:reserve(n: usize)`{:.language-nelua} | Reserve at least `n` elements in the vector storage. |
| `vectorT:resize(n: usize)`{:.language-nelua} | Resizes the vector so that it contains `n` elements. |
| `vectorT:copy(): vectorT`{:.language-nelua} | Returns a shallow copy of the vector, allocating new space. |
| `vectorT:push(v: T)`{:.language-nelua} | Adds a element `v` at the end of the vector. |
| `vectorT:pop(): T`{:.language-nelua} | Removes the last element in the vector and returns its value. |
| `vectorT:insert(pos: usize, v: T)`{:.language-nelua} | Inserts element `v` at position `pos` in the vector. |
| `vectorT:remove(pos: usize): T`{:.language-nelua} | Removes element at position `pos` in the vector and returns its value. |
| `vectorT:remove_value(v: T)`{:.language-nelua} | Removes the first item from the vector whose value is given. |
| `vectorT:remove_if(pred)`{:.language-nelua} | Removes all elements from the vector where `pred` function returns true. |
| `vectorT:capacity(): isize`{:.language-nelua} | Returns the number of elements the vector can store before triggering a reallocation. |
| `vectorT:__atindex(i: usize): *T`{:.language-nelua} | Returns reference to element at index `pos`. |
| `vectorT:__len(): isize`{:.language-nelua} | Returns the number of elements in the vector. |
{: .table.table-bordered.table-striped.table-sm}

<a href="/diffs/" class="btn btn-outline-primary btn-lg float-right">Differences >></a>
