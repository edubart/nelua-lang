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
| `global arg: sequence(string, GeneralAllocator)`{:.language-nelua} | Sequence of command line arguments. |
{: .table.table-bordered.table-striped.table-sm}

## builtins

Builtins defined in the compiler. 

| Variable Name | Description |
|---------------|------|
| `global print(...: varargs)`{:.language-nelua} | Print values to `stdout` separated by tabs and with a new line. |
| `global panic([msg: string])`{:.language-nelua} | Exit application with a fatal unrecoverable error. |
| `global error([msg: string])`{:.language-nelua} | Like `panic` but prints source location. |
| `global warn(msg: string)`{:.language-nelua} | Print a warning to `stderr`. |
| `global assert([cond: T [, msg: string]]): T`{:.language-nelua} | Thrown a runtime error if `cond` evaluates to false, otherwise returns it. |
| `global check([cond: boolean [, msg: string]])`{:.language-nelua} | Similar to `assert` but can be disabled with `-Pnochecks`. |
| `global likely(x: boolean): boolean`{:.language-nelua} | Branching prediction utility. |
| `global unlikely(x: boolean): boolean`{:.language-nelua} | Branching prediction utility. |
| `global _VERSION: string`{:.language-nelua} | A string of Nelua version. |
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
| `filestream.open(filename: string[, mode: string]): (filestream, string, integer)`{:.language-nelua} | Opens a file with given mode (default is `"r"`{:.language-nelua}). Returns empty filesystem, error message and error code if failed. |
| `filestream:flush(): (boolean, string, integer)`{:.language-nelua} | Flushes the file. |
| `filestream:close(): (boolean, string, integer)`{:.language-nelua} | Closes the file. |
| `filestream:seek([whence: string[, offset: integer]]): (integer, string, integer)`{:.language-nelua} | Returns the caret position or goes to given offset or returns the size. |
| `filestream:setvbuf(mode: string[, size: integer])`{:.language-nelua} | Sets buffer size. |
| `filestream:read(fmt: [integer, string, niltype]): (string, string, integer)`{:.language-nelua} | Reads the content of the file according to the given format. |
| `filestream:write(s: string): (boolean, string, integer)`{:.language-nelua} | Writes text to the file. |
| `filestream:lines(fmt: [integer,string,niltype]): (function(state: LinesState, prevstr: string): (boolean, string), LinesState, string)`{:.language-nelua} | Returns an iterator function that, each time it is called, reads the file according to the given formats. When no format is given, uses `"l"`{:.language-nelua} as a default. |
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
| `io.open(filename: string[, mode: string]) : (filestream, string, integer)`{:.language-nelua} | Opens a file. Alias of `filestream.open`. |
| `io.popen(command: string[, mode: string]) : (filestream, string, integer)`{:.language-nelua} | Execute a command and returns it's filestream. |
| `io.flush(): boolean`{:.language-nelua} | Flushes stdout. |
| `io.close([file])`{:.language-nelua} | Alias of `file:close`. Closes `io.stdout` if no file was given. |
| `io.input(file: [string, filestream, niltype]): filestream`{:.language-nelua} | Sets, opens or returns the input file. |
| `io.output(file: [string, filestream, niltype]): filestream`{:.language-nelua} | Sets, opens or returns the output file. |
| `io.tmpfile(): (filestream, string, integer)`{:.language-nelua} | In case of success, returns a handle for a temporary file. This file will automatically removed when the program ends. |
| `io.read(fmt: [integer, string, niltype]): (string, string, integer)`{:.language-nelua} | Alias of `io.stdin:read`. |
| `io.write(s: string): (boolean, string, integer)`{:.language-nelua} | Alias of `io.stdout:write`. |
| `io.type(x: auto)`{:.language-nelua} | Returns a type of a file as a string. Returns `nil` if not a file. |
| `io.isopen(file: filestream): boolean`{:.language-nelua} | Alias of `file:isopen`. |
| `io.lines([filename: string, fmt: [integer,string,niltype]])`{:.language-nelua} | When no `filename` is given, is an alias of `io.stdin:lines()`{:.language-nelua}, otherwise, it opens the given `filename` and returns an iterator function of `file:lines(fmt)`{:.language-nelua} over the opened file. |
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
| `os.execute([command: string])`{:.language-nelua} |  This function is equivalent to the ISO C function `system`. It passes `command` to be executed by an operating system shell. It returns three values, the first value is a boolean indicating if the command terminated successfully; the second and third values are a `string` (either `"exit"`{:.language-nelua} or `"signal"`{:.language-nelua}) and a `cint` (either correspondent exit status of the command or the signal that terminated the command). When called without a `command`, `os.execute`{:.language-nelua} returns a boolean that is true if a shell is available. |
| `os.exit(code: [integer, boolean, niltype])`{:.language-nelua} | Calls the ISO C function `exit` to terminate the host program. If code is `true`, the returned status is `EXIT_SUCCESS`; if code is `false`, the returned status is `EXIT_FAILURE`; if code is a `number`, the returned status is this number. When called without a `code`, the returned status is `EXIT_SUCCESS`. |
| `os.getenv(varname: string): string`{:.language-nelua} | Returns the value of the process environment variable `varname` or an empty string if the variable is not defined. |
| `os.remove(filename: string): (boolean, string, integer)`{:.language-nelua} | Deletes the file (or empty directory, on POSIX systems) with the given name. If this function fails, it returns `false` plus a string describing the error and the error code. Otherwise, it returns `true`, an empty string and `0`. |
| `os.rename(oldname: string, newname: string): (boolean, string, integer)`{:.language-nelua} | Renames the file or directory named oldname to newname. If this function fails, it returns `false` plus a string describing the error and the error code. Otherwise, it returns `true`, an empty string and `0`. |
| `os.setlocale(locale: string[, category: string]): string`{:.language-nelua} | Sets the current locale of the program. `locale` is a system-dependent string specifying a locale; category is an optional string describing which category to change: `"all"`, `"collate"`, `"ctype"`, `"monetary"`, `"numeric"`, or `"time"`; the default category is "all". The function returns the name of the new locale, or an empty string if the request cannot be honored. If locale is the empty string, the current locale is set to an implementation-defined native locale. If locale is the string "C", the current locale is set to the standard C locale. This function may be not thread safe because of its reliance on C function setlocale. |
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

String points to an immutable contiguous sequence of characters.
Internally it just holds a pointer to a buffer and a size.
It's buffer is null terminated (`\0`) by default to have more compatibility with C.

The string type is defined by the compiler, however it does not have
its methods implemented, this module implements all string methods.

Some methods may allocate a new string and you should call
`destroy` to free the string memory when the GC is disabled.
Note that strings can point  to a buffer in the program static storage
and such strings should never be destroyed.

### string._create
```nelua
function string._create(size: usize): string
```

Allocate a new string to be filled. Used internally.

### string.destroy
```nelua
function string.destroy(s: string): void
```

Must be required later because it depends on `string._create`
Destroys a string freeing its resources.
When GC is enabled this does nothing, because string references can be shared with GC enabled.

### string.copy
```nelua
function string.copy(s: string): string
```

Clone a string, allocating new space.

### string._forward
```nelua
function string._forward(s: string): string <inline>
```

Forward a string reference to be used elsewhere.
When GC is enabled this just returns the string itself.
When GC is disabled a string copy is returned, so it can be safely stored and destroyed.

### string.byte
```nelua
function string.byte(s: string, i: facultative(isize)): byte
```

Returns the internal numeric codes of the character at position `i`.

### string.subview
```nelua
function string.subview(s: string, i: isize, j: facultative(isize)): string
```

Return a view for sub string for a string.
The main difference between this and `string.sub` is that, here we don't allocate a new string,
instead it reuses its memory as an optimization.
Use this only if you know what you are doing, to be safe use `string.sub` instead.
CAUTION: When using the GC the view will not hold reference of the original string allocated at
runtime and the data may be collected.
The view string will may not be null terminated, thus you should never
convert it to a cstring and use in C functions.

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

### string.sub
```nelua
function string.sub(s: string, i: isize, j: facultative(isize)): string
```

Returns the substring of `s` that starts at `i` and continues until `j` (both inclusive).
Both `i` and `j` can be negative.
If `j` is absent, then it is assumed to be equal to `-1` (which is the same as the string length).
In particular, the call `string.sub(s,1,j)` returns a prefix of `s` with length `j`,
and `string.sub(s, -i)` (for a positive `i`) returns a suffix of `s` with length `i`.

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
function string.len(s: string): isize <inline>
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
function string.__len(a: string): isize <inline>
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


### string.__sub
```nelua
function string.__sub(a: scalar_coercion_concept, b: scalar_coercion_concept): number
```


### string.__mul
```nelua
function string.__mul(a: scalar_coercion_concept, b: scalar_coercion_concept): number
```


### string.__div
```nelua
function string.__div(a: scalar_coercion_concept, b: scalar_coercion_concept): number
```


### string.__idiv
```nelua
function string.__idiv(a: scalar_coercion_concept, b: scalar_coercion_concept): number
```


### string.__tdiv
```nelua
function string.__tdiv(a: scalar_coercion_concept, b: scalar_coercion_concept): number
```


### string.__mod
```nelua
function string.__mod(a: scalar_coercion_concept, b: scalar_coercion_concept): number
```


### string.__tmod
```nelua
function string.__tmod(a: scalar_coercion_concept, b: scalar_coercion_concept): number
```


### string.__pow
```nelua
function string.__pow(a: scalar_coercion_concept, b: scalar_coercion_concept): number
```


### string.__unm
```nelua
function string.__unm(a: scalar_coercion_concept): number
```


### string.__band
```nelua
function string.__band(a: scalar_coercion_concept, b: scalar_coercion_concept): integer
```


### string.__bor
```nelua
function string.__bor(a: scalar_coercion_concept, b: scalar_coercion_concept): integer
```


### string.__bxor
```nelua
function string.__bxor(a: scalar_coercion_concept, b: scalar_coercion_concept): integer
```


### string.__shl
```nelua
function string.__shl(a: scalar_coercion_concept, b: scalar_coercion_concept): integer
```


### string.__shr
```nelua
function string.__shr(a: scalar_coercion_concept, b: scalar_coercion_concept): integer
```


### string.__asr
```nelua
function string.__asr(a: scalar_coercion_concept, b: scalar_coercion_concept): integer
```


### string.__bnot
```nelua
function string.__bnot(a: scalar_coercion_concept): integer
```


### tocstring
```nelua
global function tocstring(buf: *[0]cchar, buflen: usize, s: string): boolean
```

Convert a string to a `cstring` using a temporary buffer,
this is mainly used to ensure the string is null terminated ('\0').

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

## stringbuilder

[String Builder library](https://github.com/edubart/nelua-lang/blob/master/lib/stringbuilder.nelua) description (TODO)

| Variable Name | Description |
|---------------|------|
| `stringbuilder.make`{:.language-nelua} | Stringbuilder constructor. |
{: .table.table-bordered.table-striped.table-sm}

## traits

The [traits library](https://github.com/edubart/nelua-lang/blob/master/lib/traits.nelua) contains useful functions to get information about types at runtime.

| Variable Name | Description |
|---------------|------|
| `global typeid: type`{:.language-nelua} | type alias of `uint32`. |
| `global typeid_of(val: auto): typeid`{:.language-nelua} | Returns the `typeid` of the given `val`. |
| `global type(x: auto): string`{:.language-nelua} | Returns the type of its only argument, coded as a string. |
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

## utf8

```nelua
global utf8: type = @record{}
```

This library provides basic support for UTF-8 encoding.
It provides all its functions inside the record utf8.
This library does not provide any support for Unicode other than the handling of the encoding.
Any operation that needs the meaning of a character,
such as character classification, is outside its scope.

Unless stated otherwise, all functions that expect a byte position as a parameter
assume that the given position is either the start of a byte sequence
or one plus the length of the subject string.
As in the string library, negative indices count from the end of the string.

Functions that create byte sequences accept all values up to 0x7FFFFFFF,
as defined in the original UTF-8 specification,
that implies byte sequences of up to six bytes.

Functions that interpret byte sequences only accept valid sequences (well formed and not overlong)
By default, they only accept byte sequences that result in valid Unicode code points,
rejecting values greater than 10FFFF and surrogates.
A boolean argument `relax`, when available, lifts these checks,
so that all values up to 0x7FFFFFFF are accepted.
(Not well formed and overlong sequences are still rejected.)

### utf8.charpattern
```nelua
global utf8.charpattern: string <comptime> = "[\0-\x7F\xC2-\xFD][\x80-\xBF]*"
```

Pattern to match exactly one UTF-8 byte sequence,
assuming that the subject is a valid UTF-8 string.

### utf8.char
```nelua
function utf8.char(...: varargs): string
```

Receives zero or more integers, converts each one to its corresponding UTF-8 byte sequence,
and returns a string with the concatenation of all these sequences.

### utf8.codes
```nelua
function utf8.codes(s: string, relax: facultative(boolean)): (function(string, isize): (boolean, isize, uint32), string, isize) <inline>
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

<a href="/diffs/" class="btn btn-outline-primary btn-lg float-right">Differences >></a>
