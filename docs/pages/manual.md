---
layout: docs
title: Manual
permalink: /manual
categories: docs toc
toc: true
order: 4
---

Technical specification of the Nelua language.
{: .lead}

This page is under construction and very incomplete.
{: .callout.callout-info}

## Keywords

All Lua keywords:

```nelua
and       break     do        else      elseif    end
false     for       function  goto      if        in
local     nil       not       or        repeat    return
then      true      until     while
```

Plus keywords used only by Nelua:
```nelua
case continue defer global switch
```

## Tokens

| Symbol| Usage |
|---|---|---|
| `[]`  | array index |
| `{}`  | listing |
| `()`  | surrounding |
| `<>`  | annotation |
| `:`   | method index |
| `.`   | field index |
| `...` | varargs |
| `,`   | separator |
| `;`   | line separator |
| `""`  | string quoting |
| `''`  | alternative string quoting |
| `;`   | statement separator |
| `@`   | type expression |
| `::`  | label definition |
| `--`  | comment |
| `!`   | attribute |
{: .table.table-bordered.table-striped}

<a href="/draft" class="btn btn-outline-primary btn-lg float-right">Draft >></a>