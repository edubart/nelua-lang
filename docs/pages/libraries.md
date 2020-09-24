---
layout: docs
title: Libraries
permalink: /libraries/
categories: docs toc
toc: true
order: 5
---

This is a list of built-in libraries in Nelua.
{: .lead}

To use a library use `require 'libraryname'`{:.language-nelua}.
{: .callout.callout-info}

This page is under construction and very incomplete.
{: .callout.callout-info}

## arg

[Arg library](https://github.com/edubart/nelua-lang/blob/master/lib/arg.nelua) allows to use command line arguments from the entry point.

| Variable Name | Description |
|---------------|------|
| `global arg: sequence(stringview, GeneralAllocator)`{:.language-nelua} | Sequence of command line arguments. |
{: .table.table-bordered.table-striped.table-sm}

## basic

[Basic library](https://github.com/edubart/nelua-lang/blob/master/lib/basic.nelua) contains common functions. 

| Variable Name | Description |
|---------------|------|
| `global likely(x: boolean): boolean`{:.language-nelua} | Binding for GNUC `__builtin_expect(x, 1)`. |
| `global unlikely(x: boolean): boolean`{:.language-nelua} | Binding for GNUC `__builtin_expect(x, 0)`. |
| `global panic(msg: stringview)`{:.language-nelua} | Returns an error message and stops execution. |
| `global error(msg: stringview)`{:.language-nelua} | Alias of `panic`. |
| `global assert(cond: auto, msg: auto)`{:.language-nelua} | Asserts the condition `cond`and errors if it's false. |
| `global _VERSION: stringview`{:.language-nelua} | A string of Nelua version. |
{: .table.table-bordered.table-striped.table-sm}

## iterators

[Iterators library](https://github.com/edubart/nelua-lang/blob/master/lib/iterators.nelua) contains iterator related functions.

| Variable Name | Description |
|---------------|------|
| `ipairs(list: L): (Next, *L, integer)`{:.language-nelua} | Work with vector, sequence, span and array. |
| `mipairs(list: L): (Next, *L, integer)`{:.language-nelua} | Like `ipairs` but yields reference to elements so that you can modify. |
| `pairs(list: L): (Next, *L, K)`{:.language-nelua} | Currently is an alias to `ipairs`. |
| `mpairs(list: L): (Next, *L, K)`{:.language-nelua} | Like `mpairs` but yields reference to elements so that you can modify. |
| `next(list: L, [index: K]): (boolean, K, T)`{:.language-nelua} | Works with vector, sequence, span and array. |
| `mnext(list: L, [index: K]): (boolean, K, *T)`{:.language-nelua} | Like `next` but returns reference to elements so that you can modify. |
{: .table.table-bordered.table-striped.table-sm}

## filestream

[Filestream library](https://github.com/edubart/nelua-lang/blob/master/lib/filestream.nelua) contains filestream record, mainly used for [`io`](https://nelua.io/libraries/#io) library.

| Variable Name | Description |
|---------------|------|
| `global filestream`{:.language-nelua} | `filestream` record. |
| `filestream.id: uint64`{:.language-nelua} | file id. |
| `filestream.open(filename: stringview[, mode: stringview]): (filestream, stringview, integer)`{:.language-nelua} | Opens a file with given mode (default is `r`). Returns empty filesystem, error message and error code if failed. |
| `filestream:flush(): (boolean, stringview, integer)`{:.language-nelua} | Flushes the file. |
| `filestream:close(): (boolean, stringview, integer)`{:.language-nelua} | Closes the file. |
| `filestream:seek([whence: stringview[, offset: integer]]): (integer, stringview, integer)`{:.language-nelua} | Returns the caret position or goes to given offset or returns the size. |
| `filestream:setvbuf(mode: stringview[, size: integer])`{:.language-nelua} | Sets buffer size. |
| `filestream:read(fmt: [integer, stringview, niltype]): (string, stringview, integer)`{:.language-nelua} | Reads the content of the file according to the given format. |
| `filestream:write(s: stringview): (boolean, stringview, integer)`{:.language-nelua} | Writes text to the file. |
| `filestream:isopen(): boolean`{:.language-nelua} | Returns open state of the file. |
| `filestream:__tostring(): string`{:.language-nelua} | converts the handled `FILEptr` to `string`. |
{: .table.table-bordered.table-striped.table-sm}

## io

[IO library](https://github.com/edubart/nelua-lang/blob/master/lib/io.nelua), copies Lua `io`{:.language-nelua} library. 

| Variable Name | Description |
|---------------|------|
| `global io`{:.language-nelua} | `io` record. |
| `global io.stderr: filestream`{:.language-nelua} | Error file. |
| `global io.stdout: filestream`{:.language-nelua} | Output file used for io.write. |
| `global io.stdin: filestream`{:.language-nelua} | Input file used for io.read. |
| `io.open(filename: stringview[, mode: stringview]) : (filestream, stringview, integer)`{:.language-nelua} | Opens a file. Alias of `filestream.open`. |
| `io.flush(file: filestream): boolean`{:.language-nelua} | Flushes the `file` |
| `io.close([file])`{:.language-nelua} | Alias of `file:close`. Closes `io.stdout` if no file was given. |
| `io.input(file: [stringview, filestream, niltype]): filestream`{:.language-nelua} | Sets, opens or returns the input file. |
| `io.output(file: [stringview, filestream, niltype]): filestream`{:.language-nelua} | Sets, opens or returns the output file. |
| `io.tmpfile(): (filestream, stringview, integer)`{:.language-nelua} | Returns a temporary file. |
| `io.read(fmt: [integer, stringview, niltype]): (string, stringview, integer)`{:.language-nelua} | Alias of `io.stdin:read`. |
| `io.write(s: stringview): (boolean, stringview, integer)`{:.language-nelua} | Alias of `io.stdout:write`. |
| `io.type(x: auto)`{:.language-nelua} | Returns a type of a file. Returns nil if not a file. |
| `io.isopen(file: filestream): boolean`{:.language-nelua} | Alias of `file:isopen`. |
{: .table.table-bordered.table-striped.table-sm}

## math

[Math library](https://github.com/edubart/nelua-lang/blob/master/lib/math.nelua), copies Lua `math`{:.language-nelua} library with extra functions.

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
| `memory.copy(dest, src, size)`{:.language-nelua} |  |
| `memory.move(dest, src, size)`{:.language-nelua} |  |
| `memory.set(dest, x, size)`{:.language-nelua} |  |
| `memory.zero(dest, size)`{:.language-nelua} |  |
| `diff = memory.compare(a, b, size)`{:.language-nelua} |  |
| `result = memory.equals(a, b, size)`{:.language-nelua} |  |
| `ptr = memory.scan(p, x, size)`{:.language-nelua} |  |
| `ptr = memory.find(heystack, heystacksize, needle, needlesize)`{:.language-nelua} |  |
| `memory.spancopy(dest, src)`{:.language-nelua} |  |
| `memory.spanmove(dest, src)`{:.language-nelua} |  |
| `memory.spanset(dest, x)`{:.language-nelua} |  |
| `memory.spanzero(dest)`{:.language-nelua} |  |
| `memory.spancompare(a, b)`{:.language-nelua} |  |
| `result = memory.spanequals(a, b)`{:.language-nelua} |  |
| `size = memory.spanfind(s, x)`{:.language-nelua} |  |
| `result = memory.spancontains(s, x)`{:.language-nelua} |  |
| `newa = memory.moveval(a)`{:.language-nelua} | Returns a memory copy of the dereference of pointer `a` leaving its contents zero filled. Deprecated. |
| `memory.swapval(a, b)`{:.language-nelua} | Swaps memory of the dereference of pointer `a` and `b`. Deprecated. |
{: .table.table-bordered.table-striped.table-sm}

## os

[OS library](https://github.com/edubart/nelua-lang/blob/master/lib/os.nelua) description (TODO)

| Variable Name | Description |
|---------------|------|
| `clock = os.clock()`{:.language-nelua} |  |
| `strdate = os.date()`{:.language-nelua} |  |
| `diff = os.difftime(time1, time2)`{:.language-nelua} |  |
| `status, errstr, errno = os.execute(command)`{:.language-nelua} |  |
| `os.exit(code)`{:.language-nelua} |  |
| `envval = os.getenv(varname)`{:.language-nelua} |  |
| `result, errstr, errno = os.remove(filename)`{:.language-nelua} |  |
| `result, errstr, errno = os.rename(filename)`{:.language-nelua} |  |
| `result = os.setlocale(locale, category)`{:.language-nelua} |  |
| `os_time_desc`{:.language-nelua} |  |
| `timestamp = os.time(desc)`{:.language-nelua} |  |
| `name = os.tmpname()`{:.language-nelua} |  |
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

[Traits library](https://github.com/edubart/nelua-lang/blob/master/lib/traits.nelua) description (TODO)

| Variable Name | Description |
|---------------|------|
| `typeid`{:.language-nelua} | Typedef of `uint32`{:.language-nelua}. |
| `valtypeid = typeid_of(val)`{:.language-nelua} | Returns `typeid`{:.language-nelua} of the given value. |
| `str = type(val)`{:.language-nelua} | Returns a type as stringview of the given value. |
| `typeinfo`{:.language-nelua} | Type info record. |
| `valtypeinfo = typeinfo_of(val)`{:.language-nelua} | Return `typeinfo`{:.language-nelua} of the given val. |
{: .table.table-bordered.table-striped.table-sm}

## vector

[Vector library](https://github.com/edubart/nelua-lang/blob/master/lib/vector.nelua), typically used as an efficient vector.

| Variable Name | Description |
|---------------|------|
| `vector(T)`{:.language-nelua} | Generic vector type expression. |
| `vectorT.size: usize`{:.language-nelua} | Number of elements in the vector. |
| `vectorT.data: span(T)`{:.language-nelua} | Elements storage of the vector. |
| `vectorT.allocator: Allocator`{:.language-nelua} | Allocator of the vector. |
| `vectorT.make(allocator)`{:.language-nelua} | Create a vector using a custom allocator instance. |
| `vectorT:clear()`{:.language-nelua} | Removes all elements from the vector. |
| `vectorT:destroy()`{:.language-nelua} | Resets the vector to zeroed state, freeing all used resources. |
| `vectorT:reserve(n: usize)`{:.language-nelua} | Reserve at least `n` elements in the vector storage. |
| `vectorT:resize(n: usize)`{:.language-nelua} | Resizes the vector so that it contains `n` elements. |
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