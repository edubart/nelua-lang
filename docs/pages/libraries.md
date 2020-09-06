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

Arg library allows to use command line arguments from the entry point.

| Variable Name | Description |
|---------------|------|
| `arg`{:.language-nelua} | Array of command line arguments. |
{: .table.table-bordered.table-striped.table-sm}

## basic

Basic library contains common functions. 

| Variable Name | Description |
|---------------|------|
| `condition = likely(condition)`{:.language-nelua} | Binding for GNUC `__builtin_expect(boolean, 1)`. |
| `condition = unlikely(condition)`{:.language-nelua} | Binding for GNUC `__builtin_expect(boolean, 0)`. |
| `panic(errmsg)`{:.language-nelua} | Returns an error message and stops execution. |
| `error(errmsg)`{:.language-nelua} | Alias of `panic`. |
| `assert(condition, errmsg)`{:.language-nelua} | Asserts the condition and errors if it's false. |
| `_VERSION`{:.language-nelua} | A string of Nelua version. |
{: .table.table-bordered.table-striped.table-sm}

## filestream

Filestream library contains filestream object, mainly used for `io` library.

| Variable Name | Description |
|---------------|------|
| `filestream`{:.language-nelua} | Filestream object. |
| `filestream = filestream._from_fp(fileptr)`{:.language-nelua} | Wraps `FILEPtr` into `filestream`. Internal. |
| `fileptr = filestream:_get_fp()`{:.language-nelua} | Returns the `FILEPtr` of `filestream` object. Internal. |
| `file, errstr, status = filestream.open(filepath[, mode])`{:.language-nelua} | Opens a file with given mode (default is `r`). Returns empty filesystem, error message and error code if failed. |
| `result, errstr, errno = filestream:flush()`{:.language-nelua} | Flushes the file. |
| `result, errstr, errno = filestream:close()`{:.language-nelua} | Closes the file. |
| `result, errstr, errno = filestream:seek([whence[, offset]])`{:.language-nelua} | Returns the caret position or goes to given offset or returns the size. |
| `result, errstr, errno = filestream:setvbuf(mode[, size])`{:.language-nelua} | Sets buffer size. |
| `result, errstr, errno = filestream:read([format])`{:.language-nelua} | Reads the content of the file according to the given format. |
| `result, errstr, errno = filestream:write(str)`{:.language-nelua} | Writes text to the file. |
| `result = isopen`{:.language-nelua} | Returns open state of the file. |
{: .table.table-bordered.table-striped.table-sm}

## io

IO library, copies Lua `io`{:.language-nelua} library. 

| Variable Name | Description |
|---------------|------|
| `io.stderr`{:.language-nelua} | Error file. |
| `io.stdout`{:.language-nelua} | Output file used for io.write. |
| `io.stdin`{:.language-nelua} | Input file used for io.read. |
| `file, errstr, status = io.open(filename[, mode])`{:.language-nelua} | Opens a file. Alias of `filestream.open`{:.language-nelua}. |
| `result, errstr, errno = io.flush(file)`{:.language-nelua} |  |
| `result, errstr, errno = io.close([file])`{:.language-nelua} | Alias of `file:close`{:.language-nelua}. Closes `io.stdout`{:.language-nelua} if no file was given. |
| `file = io.input([file])`{:.language-nelua} | Sets, opens or returns the input file. |
| `file = io.output([file])`{:.language-nelua} | Sets, opens or returns the output file. |
| `file, errstr, status = io.tmpfile()`{:.language-nelua} | Returns a temporary file. |
| `result, errstr, errno = io.read([format])`{:.language-nelua} | Alias of `io.stdin:read`{:.language-nelua}. |
| `result, errstr, errno = io.write(str)`{:.language-nelua} | Alias of `io.stdout:write`{:.language-nelua}. |
| `result = io.type(file)`{:.language-nelua} | Returns a type of a file. Returns nil if not a file. |
| `result = io.isopen(file)`{:.language-nelua} | Alias of `file:isopen`{:.language-nelua}. |
{: .table.table-bordered.table-striped.table-sm}

## math

Desc

| Variable Name | Description |
|---------------|------|
| `math.pi`{:.language-nelua} |  |
| `math.huge`{:.language-nelua} |  |
| `math.maxinteger`{:.language-nelua} |  |
| `math.mininteger`{:.language-nelua} |  |
| `result = math.abs(number)`{:.language-nelua} |  |
| `result = math.ceil(number)`{:.language-nelua} |  |
| `result = math.floor(number)`{:.language-nelua} |  |
| `result = math.ifloor(number)`{:.language-nelua} |  |
| `result = math.sqrt(number)`{:.language-nelua} |  |
| `result = math.exp(number)`{:.language-nelua} |  |
| `result = math.acos(number)`{:.language-nelua} |  |
| `result = math.asin(number)`{:.language-nelua} |  |
| `result = math.cos(number)`{:.language-nelua} |  |
| `result = math.sin(number)`{:.language-nelua} |  |
| `result = math.tan(number)`{:.language-nelua} |  |
| `result = math.cosh(number)`{:.language-nelua} |  |
| `result = math.sinh(number)`{:.language-nelua} |  |
| `result = math.tanh(number)`{:.language-nelua} |  |
| `result = math.log10(number)`{:.language-nelua} |  |
| `result = math.max(number, number)`{:.language-nelua} |  |
| `result = math.min(number, number)`{:.language-nelua} |  |
| `result = math.fmod(base, modulator)`{:.language-nelua} |  |
| `result = math.atan2(number, number)`{:.language-nelua} |  |
| `result = math.pow(base, exponent)`{:.language-nelua} |  |
| `result = math.atan(number, number)`{:.language-nelua} |  |
| `result = math.log(number, base)`{:.language-nelua} |  |
| `degrees = math.deg(radians)`{:.language-nelua} |  |
| `radians = math.rad(degrees)`{:.language-nelua} |  |
| `result = math.modf(base)`{:.language-nelua} |  |
| `multiplier, exponent = math.frexp(number)`{:.language-nelua} |  |
| `number = math.ldexp(multiplier, exponent)`{:.language-nelua} |  |
| `integer = math.tointeger(number)`{:.language-nelua} |  |
| `type = math.type(number)`{:.language-nelua} |  |
| `result = math.ult(number, number)`{:.language-nelua} |  |
| `math.randomseed(number[, number])`{:.language-nelua} |  |
| `result = math.random([m[, n]])`{:.language-nelua} |  |
{: .table.table-bordered.table-striped.table-sm}

## memory

Desc

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

Desc

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

Desc

| Variable Name | Description |
|---------------|------|
| `resourcepool`{:.language-nelua} | Resourcepool constructor. |
{: .table.table-bordered.table-striped.table-sm}

## sequence

Desc

| Variable Name | Description |
|---------------|------|
| `sequence`{:.language-nelua} | Sequence constructor. |
{: .table.table-bordered.table-striped.table-sm}

## span

Desc

| Variable Name | Description |
|---------------|------|
| `span`{:.language-nelua} | Span constructor |
{: .table.table-bordered.table-striped.table-sm}

## string

Desc

| Variable Name | Description |
|---------------|------|
| `string`{:.language-nelua} | String type. |
| `tostring`{:.language-nelua} | Converts values to string using `__tostring`{:.language-nelua}. |
| `string._create`{:.language-nelua} |  |
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
| `string.__mod`{:.language-nelua} |  |
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

Desc

| Variable Name | Description |
|---------------|------|
| `stringbuilder.make`{:.language-nelua} | Stringbuilder constructor. |
{: .table.table-bordered.table-striped.table-sm}

## stringview

Desc

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
| `stringview.__mod`{:.language-nelua} |  |
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

Desc

| Variable Name | Description |
|---------------|------|
| `typeid`{:.language-nelua} | Typedef of `uint32`{:.language-nelua}. |
| `valtypeid = typeid_of(val)`{:.language-nelua} | Returns `typeid`{:.language-nelua} of the given value. |
| `str = type(val)`{:.language-nelua} | Returns a type as stringview of the given value. |
| `typeinfo`{:.language-nelua} | Type info record. |
| `valtypeinfo = typeinfo_of(val)`{:.language-nelua} | Return `typeinfo`{:.language-nelua} of the given val. |
{: .table.table-bordered.table-striped.table-sm}

## vector

Desc

| Variable Name | Description |
|---------------|------|
| `vector`{:.language-nelua} | Vector constructor. |
{: .table.table-bordered.table-striped.table-sm}

<a href="/diffs/" class="btn btn-outline-primary btn-lg float-right">Differences >></a>