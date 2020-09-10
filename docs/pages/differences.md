---
layout: docs
title: Differences
permalink: /diffs/
categories: docs toc
toc: true
order: 6
---

Nelua had to reimplement all Lua libraries. Due to this some functions are not implemented or can't be implemented. This page explains availability of Lua functions in Nelua.

Implemented - ✔

Not Implemented Yet - ❌

Never or N/A - ✖

{: .lead}

## Basic and globals

| Function | Status | Nelua Library | Remarks |
|----------|:------:|---------------|---------|
| `_G`{:.language-nelua} | ❌ | | `_G` doesn't exist in Nelua due to missing dynamic in C (rephrase me please). |
| `_VERSION`{:.language-nelua} | ✔ | `basic`{:.language-nelua} | Returns Nelua version instead of Lua version. |
| `assert`{:.language-nelua} | ✔ | `basic`{:.language-nelua} |  |
| `collectgarbage`{:.language-nelua} | ✔ | `allocators.gc`{:.language-nelua} | Only `collect`, `stop`, `restart`, `count` and `isrunning` arguments. |
| `dofile`{:.language-nelua} | ✖ | | Nelua can't compile at the runtime. |
| `error`{:.language-nelua} | ✔ | `basic`{:.language-nelua} |  |
| `getmetatable`{:.language-nelua} | ❌ | `basic`{:.language-nelua} |  |
| `load`{:.language-nelua} | ✖ | |  |
| `loadfile`{:.language-nelua} | ✖ | |  |
| `next`{:.language-nelua} | ✔ | `iterators`{:.language-nelua} |  |
| `pairs`{:.language-nelua} | ✔ | `iterators`{:.language-nelua} | Aliased to ipairs right now. |
| `ipairs`{:.language-nelua} | ✔ | `iterators`{:.language-nelua} |  |
| `pcall`{:.language-nelua} | ❌ | `basic`{:.language-nelua} |  |
| `print`{:.language-nelua} | ✔ | inlined | Nelua generates print function for each type. |
| `rawequal`{:.language-nelua} | ❌ | `basic`{:.language-nelua} |  |
| `rawget`{:.language-nelua} | ❌ | `basic`{:.language-nelua} |  |
| `rawlen`{:.language-nelua} | ❌ | `basic`{:.language-nelua} |  |
| `rawset`{:.language-nelua} | ❌ | `basic`{:.language-nelua} |  |
| `require`{:.language-nelua} | ✔ | Nelua compiler | Exists as compiler function. |
| `select`{:.language-nelua} | ❌ | `basic`{:.language-nelua} |  |
| `setmetatable`{:.language-nelua} | ❌ | `basic`{:.language-nelua} |  |
| `tonumber`{:.language-nelua} | ✔ | `stringview`{:.language-nelua} |  |
| `tostring`{:.language-nelua} | ✔ | `string`{:.language-nelua} | As Lua this function uses `__tostring`{:.language-nelua}, however Nelua also has `__tostringview`{:.language-nelua} which exists in `stringview`{:.language-nelua} library. |
| `type`{:.language-nelua} | ✔ | `traits`{:.language-nelua} |  |
| `warn`{:.language-nelua} | ❌ | `basic`{:.language-nelua} |  |
| `xpcall`{:.language-nelua} | ❌ | `basic`{:.language-nelua} |  |
{: .table.table-bordered.table-striped.table-sm}

## Coroutine

❌ The library is not implemented yet.

## Debug

❌ The library is not implemented yet.
For debugging use `--debug` flag and a C debugger.

## IO and FILE*

Nelua has additional functions in this library. See [here](/libraries/#io).
{: .callout.callout-info}

| Function | Status | Nelua Library | Remarks |
|----------|:------:|---------------|---------|
| `io.close`{:.language-nelua} | ✔ | `io`{:.language-nelua} |  |
| `io.flush`{:.language-nelua} | ✔ | `io`{:.language-nelua} |  |
| `io.input`{:.language-nelua} | ✔ | `io`{:.language-nelua} |  |
| `io.lines`{:.language-nelua} | ❌ | `io`{:.language-nelua} |  |
| `io.open`{:.language-nelua} | ✔ | `io`{:.language-nelua} |  |
| `io.output`{:.language-nelua} | ✔ | `io`{:.language-nelua} |  |
| `io.popen`{:.language-nelua} | ❌ | `io`{:.language-nelua} |  |
| `io.read`{:.language-nelua} | ✔ | `io`{:.language-nelua} | Doesn't support `*n` format and multiple arguments. |
| `io.stderr`{:.language-nelua} | ✔ | `io`{:.language-nelua} |  |
| `io.stdin`{:.language-nelua} | ✔ | `io`{:.language-nelua} |  |
| `io.stdout`{:.language-nelua} | ✔ | `io`{:.language-nelua} |  |
| `io.tmpfile`{:.language-nelua} | ✔ | `io`{:.language-nelua} |  |
| `io.type`{:.language-nelua} | ✔ | `io`{:.language-nelua} |  |
| `io.write`{:.language-nelua} | ✔ | `io`{:.language-nelua} | Doesn't support multiple arguments. |
| `file:close`{:.language-nelua} | ✔ | `filesystem`{:.language-nelua} |  |
| `file:flush`{:.language-nelua} | ✔ | `filesystem`{:.language-nelua} |  |
| `file:lines`{:.language-nelua} | ✔ | `filesystem`{:.language-nelua} |  |
| `file:read`{:.language-nelua} | ✔ | `filesystem`{:.language-nelua} | Doesn't support `*n` format and multiple arguments. |
| `file:seek`{:.language-nelua} | ✔ | `filesystem`{:.language-nelua} |  |
| `file:setvbuf`{:.language-nelua} | ✔ | `filesystem`{:.language-nelua} |  |
| `file:write`{:.language-nelua} | ✔ | `filesystem`{:.language-nelua} | Doesn't support multiple arguments. Doesn't return the file itself. |
{: .table.table-bordered.table-striped.table-sm}

## Math

Nelua has additional functions in this library. See [here](/libraries/#math).
{: .callout.callout-info}

| Function | Status | Nelua Library | Remarks |
|----------|:------:|---------------|---------|
| `math.abs`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
| `math.acos`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
| `math.asin`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
| `math.atan`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
| `math.atan2`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
| `math.ceil`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
| `math.cos`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
| `math.cosh`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
| `math.deg`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
| `math.exp`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
| `math.floor`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
| `math.fmod`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
| `math.frexp`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
| `math.huge`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
| `math.ldexp`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
| `math.log`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
| `math.log10`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
| `math.max`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
| `math.maxinteger`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
| `math.min`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
| `math.mininteger`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
| `math.modf`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
| `math.pi`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
| `math.pow`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
| `math.rad`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
| `math.random`{:.language-nelua} | ✔ | `math`{:.language-nelua} | The same as in Lua 5.4. |
| `math.randomseed`{:.language-nelua} | ✔ | `math`{:.language-nelua} | The same as in Lua 5.4. |
| `math.sin`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
| `math.sinh`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
| `math.sqrt`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
| `math.tan`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
| `math.tanh`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
| `math.tointeger`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
| `math.type`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
| `math.ult`{:.language-nelua} | ✔ | `math`{:.language-nelua} |  |
{: .table.table-bordered.table-striped.table-sm}

## OS

| Function | Status | Nelua Library | Remarks |
|----------|:------:|---------------|---------|
| `os.clock`{:.language-nelua} | ✔ | `os`{:.language-nelua} |  |
| `os.date`{:.language-nelua} | ✔ | `os`{:.language-nelua} | Doesn't support formats. Only `%c`{:.language-nelua} |
| `os.difftime`{:.language-nelua} | ✔ | `os`{:.language-nelua} |  |
| `os.execute`{:.language-nelua} | ✔ | `os`{:.language-nelua} | POSIX status codes are not translated. |
| `os.exit`{:.language-nelua} | ✔ | `os`{:.language-nelua} |  |
| `os.getenv`{:.language-nelua} | ✔ | `os`{:.language-nelua} |  |
| `os.remove`{:.language-nelua} | ✔ | `os`{:.language-nelua} |  |
| `os.rename`{:.language-nelua} | ✔ | `os`{:.language-nelua} |  |
| `os.setlocale`{:.language-nelua} | ✔ | `os`{:.language-nelua} |  |
| `os.time`{:.language-nelua} | ✔ | `os`{:.language-nelua} | Default value for .hour is 0 not 12. |
| `os.tmpname`{:.language-nelua} | ✔ | `os`{:.language-nelua} | Uses `mkstemp`{:.language-nelua} on POSIX. |
{: .table.table-bordered.table-striped.table-sm}

## Package

✖ Nelua doesn't have a module system.

## String

Nelua has additional functions in this library. See [here](/libraries/#stringview) and [here](/libraries/#string).
{: .callout.callout-info}

| Function | Status | Nelua Library | Remarks |
|----------|:------:|---------------|---------|
| `string.byte`{:.language-nelua} | ✔ | `stringview`{:.language-nelua} | No multiple arguments. Errors on failure. |
| `string.char`{:.language-nelua} | ✔ | `string`{:.language-nelua} | Only for `string`{:.language-nelua}. No multiple arguments. |
| `string.dump`{:.language-nelua} | ✖ | `string`{:.language-nelua} | No interpreted functions. |
| `string.find`{:.language-nelua} | ✔ | `stringview`{:.language-nelua} | Patterns are not supported. Returns `0, 0`{:.language-nelua} instead of `nil`{:.language-nelua} if nothing was found. |
| `string.format`{:.language-nelua} | ✔ | `string`{:.language-nelua} | No multiple arguments. |
| `string.gmatch`{:.language-nelua} | ❌ | `string`{:.language-nelua} |  |
| `string.gsub`{:.language-nelua} | ❌ | `string`{:.language-nelua} |  |
| `string.len`{:.language-nelua} | ✔ | `stringview`{:.language-nelua} |  |
| `string.lower`{:.language-nelua} | ✔ | `string`{:.language-nelua} |  |
| `string.match`{:.language-nelua} | ❌ | `string`{:.language-nelua} |  |
| `string.pack`{:.language-nelua} | ❌ | `string`{:.language-nelua} |  |
| `string.packsize`{:.language-nelua} | ❌ | `string`{:.language-nelua} |  |
| `string.rep`{:.language-nelua} | ✔ | `string`{:.language-nelua} |  |
| `string.reverse`{:.language-nelua} | ✔ | `string`{:.language-nelua} |  |
| `string.sub`{:.language-nelua} | ✔ | `string`{:.language-nelua} |  |
| `string.unpack`{:.language-nelua} | ❌ | `string`{:.language-nelua} |  |
| `string.upper`{:.language-nelua} | ✔ | `string`{:.language-nelua} |  |
| `string.__len`{:.language-nelua} | ✔ | `stringview`{:.language-nelua} |  |
| `string.__eq`{:.language-nelua} | ✔ | `stringview`{:.language-nelua} |  |
| `string.__lt`{:.language-nelua} | ✔ | `stringview`{:.language-nelua} |  |
| `string.__le`{:.language-nelua} | ✔ | `stringview`{:.language-nelua} |  |
| `string.__sub`{:.language-nelua} | ✔ | `stringview`{:.language-nelua} |  |
| `string.__add`{:.language-nelua} | ✔ | `stringview`{:.language-nelua} |  |
| `string.__pow`{:.language-nelua} | ✔ | `stringview`{:.language-nelua} |  |
| `string.__unm`{:.language-nelua} | ✔ | `stringview`{:.language-nelua} |  |
| `string.__div`{:.language-nelua} | ✔ | `stringview`{:.language-nelua} |  |
| `string.__idiv`{:.language-nelua} | ✔ | `stringview`{:.language-nelua} |  |
| `string.__mul`{:.language-nelua} | ✔ | `stringview`{:.language-nelua} |  |
| `string.__mod`{:.language-nelua} | ✔ | `stringview`{:.language-nelua} |  |
{: .table.table-bordered.table-striped.table-sm}

## Table

❌ Dynamic tables are not implemented yet.

## UTF-8

❌ Not implemented yet.

<a href="/faq/" class="btn btn-outline-primary btn-lg float-right">FAQ >></a>