--[[
LPegRex - LPeg Regular Expression eXtended
v0.2.2 - 3/Jun/2021
Eduardo Bart - edub4rt@gmail.com
https://github.com/edubart/lpegrex

Check the project page for documentation on how to use.

See end of file for LICENSE.
]]

-- LPegRex depends on LPegLabel.
local lpeg = require 'lpeglabel'

-- Increase LPEG max stack, because the default is too low to use with complex grammars.
lpeg.setmaxstack(1024)

-- The LPegRex module table.
local lpegrex = {}

-- Cache tables for `match`, `find` and `gsub`.
local mcache, fcache, gcache

-- Global LPegRex options.
local defrexoptions = {
  tag = 'tag',
  pos = 'pos',
  endpos = 'endpos',
  SKIP = 'SKIP',
  NAME_SUFFIX = 'NAME_SUFFIX',
}
local rexoptions

-- LPeGRex syntax errors.
local ErrorInfo = {
  NoPatt = "no pattern found",
  ExtraChars = "unexpected characters after the pattern",

  ExpPatt1 = "expected a pattern after '/'",
  ExpPatt2 = "expected a pattern after '&'",
  ExpPatt3 = "expected a pattern after '!'",
  ExpPatt4 = "expected a pattern after '('",
  ExpPatt5 = "expected a pattern after ':'",
  ExpPatt6 = "expected a pattern after '{~'",
  ExpPatt7 = "expected a pattern after '{|'",
  ExpPatt8 = "expected a pattern after '<-'",

  ExpPattOrClose = "expected a pattern or closing '}' after '{'",

  ExpNumName = "expected a number, '+', '-' or a name (no space) after '^'",
  ExpCap = "expected a string, number, '{}' or name after '->'",

  ExpName1 = "expected the name of a rule after '=>'",
  ExpName2 = "expected the name of a rule after '=' (no space)",
  ExpName3 = "expected the name of a rule after '<' (no space)",
  ExpName4 = "expected a name, number or string rule after '$' (no space)",
  ExpName5 = "expected a name or string rule after '@' (no space)",

  ExpLab1 = "expected a label after '{'",

  ExpTokOrKey = "expected a keyword or token string after '`'",
  ExpNameOrLab = "expected a name or label after '%' (no space)",

  ExpItem = "expected at least one item after '[' or '^'",

  MisClose1 = "missing closing ')'",
  MisClose2 = "missing closing ':}'",
  MisClose3 = "missing closing '~}'",
  MisClose4 = "missing closing '|}'",
  MisClose5 = "missing closing '}'",  -- for the captures
  MisClose6 = "missing closing '>'",
  MisClose7 = "missing closing '}'",  -- for the labels
  MisClose8 = "missing closing ']'",

  MisTerm1 = "missing terminating single quote",
  MisTerm2 = "missing terminating double quote",
  MisTerm3 = "missing terminating backtick quote",
}

-- Localize some functions used in compiled PEGs.
local char = string.char
local utf8char = utf8 and utf8.char
local select, tonumber = select, tonumber
local insert = table.insert

-- Pattern matching any character.
local Any = lpeg.P(1)

-- Predefined patterns.
local Predef = {
  nl = lpeg.P"\n", -- new line
  ca = lpeg.P"\a", -- audible bell
  cb = lpeg.P"\b", -- back feed
  ct = lpeg.P"\t", -- horizontal tab
  cn = lpeg.P"\n", -- new line
  cv = lpeg.P"\v", -- vertical tab
  cf = lpeg.P"\f", -- form feed
  cr = lpeg.P"\r", -- carriage return
  sp = lpeg.S" \n\r\t\f\v",
  utf8 = lpeg.R("\0\x7F", "\xC2\xFD") * lpeg.R("\x80\xBF")^0,
  utf8seq = lpeg.R("\xC2\xFD") * lpeg.R("\x80\xBF")^0,
  ascii = lpeg.R("\0\x7F"),
  tonil = function() return nil end,
  totrue = function() return true end,
  tofalse = function() return false end,
  toemptytable = function() return {} end,
  tochar = function(s, base) return char(tonumber(s, base)) end,
  toutf8char = function(s, base) return utf8char(tonumber(s, base)) end,
  tonumber = tonumber,
}

-- Fold tables to the left (use only with `~>`).
-- Example: ({1}, {2}, {3}) -> {{{1}, 2}, 3}
function Predef.foldleft(lhs, rhs)
  insert(rhs, 1, lhs)
  return rhs
end

-- Fold tables to the right (use only with `->`).
-- Example: ({1}, {2}, {3}) -> {1, {2, {3}}}}
function Predef.foldright(first, ...)
  if ... then
    local lhs = first
    for i=1,select('#', ...) do
      local rhs = select(i, ...)
      lhs[#lhs+1] = rhs
      lhs = rhs
    end
  end
  return first
end

-- Fold tables to the left in reverse order (use only with `->`).
-- Example: ({1}, {2}, {3}) -> {{{3}, 2}, 1}
function Predef.rfoldleft(first, ...)
  if ... then
    local rhs = first
    for i=1,select('#', ...) do
      local lhs = select(i, ...)
      insert(rhs, 1, lhs)
      rhs = lhs
    end
  end
  return first
end

-- Fold tables to the right in reverse order (use only with `~>`)
-- Example: ({1}, {2}, {3}) -> {3, {2, {1}}
function Predef.rfoldright(lhs, rhs)
  rhs[#rhs+1] = lhs
  return rhs
end

-- Updates the pre-defined character classes to the current locale.
function lpegrex.updatelocale()
  lpeg.locale(Predef)
  -- fill default pattern classes
  Predef.a = Predef.alpha
  Predef.c = Predef.cntrl
  Predef.d = Predef.digit
  Predef.g = Predef.graph
  Predef.l = Predef.lower
  Predef.p = Predef.punct
  Predef.s = Predef.space
  Predef.u = Predef.upper
  Predef.w = Predef.alnum
  Predef.x = Predef.xdigit
  Predef.A = Any - Predef.a
  Predef.C = Any - Predef.c
  Predef.D = Any - Predef.d
  Predef.G = Any - Predef.g
  Predef.L = Any - Predef.l
  Predef.P = Any - Predef.p
  Predef.S = Any - Predef.s
  Predef.U = Any - Predef.u
  Predef.W = Any - Predef.w
  Predef.X = Any - Predef.x
  -- clear the cache because the locale changed
  mcache, fcache, gcache = {}, {}, {}
  -- don't hold references in cached patterns
  local weakmt = {__mode = "v"}
  setmetatable(mcache, weakmt)
  setmetatable(fcache, weakmt)
  setmetatable(gcache, weakmt)
end

-- Fill predefined classes using the default locale.
lpegrex.updatelocale()

-- Create LPegRex syntax pattern.
local function mkrex()
  local l = lpeg
  local lmt = getmetatable(Any)

  local function expect(pattern, label)
    return pattern + l.T(label)
  end

  local function mult(p, n)
    local np = l.P(true)
    while n >= 1 do
      if n % 2 >= 1 then
        np = np * p
      end
      p = p * p
      n = n / 2
    end
    return np
  end

  local function equalcap(s, i, c)
    local e = #c + i
    if s:sub(i, e - 1) == c then
      return e
    end
  end

  local function getuserdef(id, defs)
    local v = defs and defs[id] or Predef[id]
    if not v then
      error("name '" .. id .. "' undefined")
    end
    return v
  end

  local function getopt(id)
    if rexoptions and rexoptions[id] ~= nil then
      return rexoptions[id]
    end
    return defrexoptions[id]
  end

  -- current grammar being generated
  local G, Gkeywords, Gtokens

  local function begindef()
    G, Gkeywords, Gtokens = {}, {}, {}
    return G
  end

  local function enddef(t)
    -- generate TOKEN rule
    if Gtokens and #Gtokens > 0 then
      local TOKEN = Gtokens[Gtokens[1]]
      for i=2,#Gtokens do
        TOKEN = TOKEN + Gtokens[Gtokens[i]]
      end
      G.TOKEN = TOKEN
    end
    -- cleanup grammar context
    G, Gkeywords, Gtokens = nil, nil, nil
    return l.P(t)
  end

  local function adddef(t, k, exp)
    if t[k] then
      error("'"..k.."' already defined as a rule")
    else
      t[k] = exp
    end
    return t
  end

  local function firstdef(t, n, r)
    t[1] = n
    return adddef(t, n, r)
  end

  local function NT(n, b)
    if not b then
      error("rule '"..n.."' used outside a grammar")
    end
    return l.V(n)
  end

  local S = (Predef.space + "--" * (Any - Predef.nl)^0)^0
  local NamePrefix = l.R("AZ", "az", "__")
  local WordSuffix = l.R("AZ", "az", "__", "09")
  local NameSuffix = (WordSuffix + (l.P"-" * #WordSuffix))^0
  local Name = l.C(NamePrefix * NameSuffix)
  local TokenDigit = Predef.punct - "_"
  local NodeArrow = S * "<=="
  local TableArrow = S * "<-|"
  local RuleArrow = S * (l.P"<--" + "<-")
  local Arrow = NodeArrow + TableArrow + RuleArrow
  local Num = l.C(l.R"09"^1) * S / tonumber
  local SignedNum = l.C(l.P"-"^-1 * l.R"09"^1) * S / tonumber
  local String = "'" * l.C((Any - "'")^0) * expect("'", "MisTerm1")
               + '"' * l.C((Any - '"')^0) * expect('"', "MisTerm2")
  local Token = "`" * l.C(TokenDigit * (TokenDigit - '`')^0) * expect("`", "MisTerm3")
  local Keyword = "`" * l.C(NamePrefix * (Any - "`")^0) * expect('`', "MisTerm3")
  local Range = l.Cs(Any * (l.P"-"/"") * (Any - "]")) / l.R
  local Defs = l.Carg(1)
  local NamedDef = Name * Defs -- a defined name only have meaning in a given environment
  local Defined = "%" * NamedDef / getuserdef
  local Item = (Defined + Range + l.C(Any)) / l.P
  local Class =
      "["
    * (l.C(l.P"^"^-1)) -- optional complement symbol
    * l.Cf(expect(Item, "ExpItem") * (Item - "]")^0, lmt.__add)
      / function(c, p) return c == "^" and Any - p or p end
    * expect("]", "MisClose8")

  local function defwithfunc(f)
    return l.Cg(NamedDef / getuserdef * l.Cc(f))
  end

  local function updatetokens(s)
    for _,toks in ipairs(Gtokens) do
      if toks ~= s then
        if toks:find(s, 1, true) == 1 then
          G[s] = -G[toks] * G[s]
        elseif s:find(toks, 1, true) == 1 then
          G[toks] = -G[s] * G[toks]
        end
      end
    end
  end

  local function maketoken(s, cap)
    local p = Gtokens[s]
    if not p then
      p = l.V(s)
      Gtokens[s] = p
      Gtokens[#Gtokens+1] = s
      G[s] = l.P(s) * l.V(getopt("SKIP"))
      updatetokens(s)
    end
    if cap then
      p = p * l.Cc(s)
    end
    return p
  end

  local function updatekeywords(kp)
    local p = G.KEYWORD
    if not p then
      p = kp
    else
      p = p + kp
    end
    G.KEYWORD = p
  end

  local function makekeyword(s, cap)
    local p = Gkeywords[s]
    if not p then
      p = l.P(s) * -l.V(getopt("NAME_SUFFIX")) * l.V(getopt("SKIP"))
      Gkeywords[s] = p
      updatekeywords(p)
    end
    if cap then
      p = p * l.Cc(s)
    end
    return p
  end

  local function makenode(n, tag, p)
    local tagfield, posfield, endposfield = getopt('tag'), getopt('pos'), getopt('endpos')
    local istagfunc = type(tagfield) == 'function'
    if tagfield and not istagfunc then
      p = l.Cg(l.Cc(tag), tagfield) * p
    end
    if posfield then
      p = l.Cg(l.Cp(), posfield) * p
    end
    if endposfield then
      p = p * l.Cg(l.Cp(), endposfield)
    end
    local rp = l.Ct(p)
    if istagfunc then
      rp = l.Cc(tag) * rp / tagfield
    end
    return n, rp
  end

  local exp = l.P{ "Exp",
    Exp = S * ( l.V"Grammar"
                + l.Cf(l.V"Seq" * (S * "/" * expect(S * l.V"Seq", "ExpPatt1"))^0, lmt.__add) );
    Seq = l.Cf(l.Cc(l.P"") * l.V"Prefix" * (S * l.V"Prefix")^0, lmt.__mul);
    Prefix = "&" * expect(S * l.V"Prefix", "ExpPatt2") / lmt.__len
           + "!" * expect(S * l.V"Prefix", "ExpPatt3") / lmt.__unm
           + l.V"Suffix";
    Suffix = l.Cf(l.V"Primary" *
            ( S * ( l.P"+" * l.Cc(1, lmt.__pow)
                  + l.P"*" * l.Cc(0, lmt.__pow)
                  + l.P"?" * l.Cc(-1, lmt.__pow)
                  + l.P"~?" * l.Cc(l.Cc(false), lmt.__add)
                  + "^" * expect( l.Cg(Num * l.Cc(mult))
                                + l.Cg(l.C(l.S"+-" * l.R"09"^1) * l.Cc(lmt.__pow)
                                + Name * l.Cc"lab"
                                ),
                            "ExpNumName")
                  + "->" * expect(S * ( l.Cg((String + Num) * l.Cc(lmt.__div))
                                      + l.P"{}" * l.Cc(nil, l.Ct)
                                      + defwithfunc(lmt.__div)
                                      ),
                             "ExpCap")
                  + "=>" * expect(S * defwithfunc(l.Cmt),
                             "ExpName1")
                  + "~>" * S * defwithfunc(l.Cf)
                  ) --* S
            )^0, function(a,b,f) if f == "lab" then return a + l.T(b) end return f(a,b) end );
    Primary = "(" * expect(l.V"Exp", "ExpPatt4") * expect(S * ")", "MisClose1")
            + String / l.P
            + #l.P'`' * expect(
                  Token / maketoken
                + Keyword / makekeyword
              , "ExpTokOrKey")
            + Class
            + Defined
            + "%" * expect(l.P"{", "ExpNameOrLab")
              * expect(S * l.V"Label", "ExpLab1")
              * expect(S * "}", "MisClose7") / l.T
            + "{:" * (Name * ":" + l.Cc(nil)) * expect(l.V"Exp", "ExpPatt5")
              * expect(S * ":}", "MisClose2")
              / function(n, p) return l.Cg(p, n) end
            + "=" * expect(Name, "ExpName2")
              / function(n) return l.Cmt(l.Cb(n), equalcap) end
            + l.P"{}" / l.Cp
            + l.P"$" * expect(
                  l.P"nil" / function() return l.Cc(nil) end
                + l.P"false" / function() return l.Cc(false) end
                + l.P"true" / function() return l.Cc(true) end
                + l.P"{}" / function() return l.Cc({}) end
                + SignedNum / function(s) return l.Cc(tonumber(s)) end
                + String / function(s) return l.Cc(s) end
                + (NamedDef / getuserdef) / l.Cc,
                "ExpName4")
            + l.P"@" * expect(
                  String / function(s) return l.P(s) + l.T('Expected_'..s) end
                + Token / function(s)
                  return maketoken(s) + l.T('Expected_'..s)
                end
                + Keyword / function(s)
                  return makekeyword(s) + l.T('Expected_'..s)
                end
                + Name * l.Cb("G") / function(n, b)
                  return NT(n, b) + l.T('Expected_'..n)
                end,
                "ExpName5")
            + "{~" * expect(l.V"Exp", "ExpPatt6") * expect(S * "~}", "MisClose3") / l.Cs
            + "{|" * expect(l.V"Exp", "ExpPatt7") * expect(S * "|}", "MisClose4") / l.Ct
            + "{" * #l.P'`' * expect(
                  Token * l.Cc(true) / maketoken
                + Keyword * l.Cc(true) / makekeyword
              , "ExpTokOrKey") * expect(S * "}", "MisClose5")
            + "{" * expect(l.V"Exp", "ExpPattOrClose") * expect(S * "}", "MisClose5") / l.C
            + l.P"." * l.Cc(Any)
            + (Name * -(Arrow + (S * ":" * S * Name * Arrow)) + "<" * expect(Name, "ExpName3")
               * expect(">", "MisClose6")) * l.Cb("G") / NT;
    Label = Num + Name;
    RuleDefinition = Name * RuleArrow * expect(l.V"Exp", "ExpPatt8");
    TableDefinition = Name * TableArrow * expect(l.V"Exp", "ExpPatt8") /
      function(n, p) return n, l.Ct(p) end;
    NodeDefinition = Name * NodeArrow * expect(l.V"Exp", "ExpPatt8") /
      function(n, p) return makenode(n, n, p) end;
    TaggedNodeDefinition = Name * S * l.P":" * S * Name * NodeArrow * expect(l.V"Exp", "ExpPatt8") / makenode;
    Definition = l.V"TaggedNodeDefinition" + l.V"NodeDefinition" + l.V"TableDefinition" + l.V"RuleDefinition";
    Grammar = l.Cg(l.Cc(true), "G")
              * l.Cf(l.P"" / begindef
                  * (l.V"Definition") / firstdef
                  * (S * (l.Cg(l.V"Definition")))^0, adddef) / enddef;
  }

  return S * l.Cg(l.Cc(false), "G") * expect(exp, "NoPatt") / l.P
           * S * expect(-Any, "ExtraChars")
end


local rexpatt = mkrex()

--[[
Compiles the given `pattern` string and returns an equivalent LPeg pattern.

The given string may define either an expression or a grammar.
The optional `defs` table provides extra Lua values to be used by the pattern.
The optional `options table can provide the following options for node captures:
* `tag` name of the node tag field, if `false` it's omitted (default "tag").
* `pos` name of the node initial position field, if `false` it's omitted (default "pos").
* `endpos` name of the node final position field, if `false` it's omitted (default "endpos").
]]
function lpegrex.compile(pattern, defs)
  if lpeg.type(pattern) == 'pattern' then -- already compiled
    return pattern
  end
  rexoptions = defs and defs.__options
  local ok, cp, errlabel, errpos = pcall(function()
    return rexpatt:match(pattern, 1, defs)
  end)
  rexoptions = nil
  if not ok and cp then
    if type(cp) == "string" then
      cp = cp:gsub("^[^:]+:[^:]+: ", "")
    end
    error(cp, 3)
  end
  if not cp then
    local lineno, colno, line, linepos = lpegrex.calcline(pattern, errpos)
    local err = {"syntax error(s) in pattern\n"}
    table.insert(err, "L"..lineno..":C"..colno..": "..ErrorInfo[errlabel])
    table.insert(err, line)
    table.insert(err, (" "):rep(colno-1)..'^')
    error(table.concat(err, "\n"), 3)
  end
  return cp
end

--[[
Matches the given `pattern` against the `subject` string.

If the match succeeds, returns the index in the `subject` of the first character after the match,
or the captured values (if the pattern captured any value).

An optional numeric argument `init` makes the match start at that position in the subject string.
]]
function lpegrex.match(subject, pattern, init)
  local cp = mcache[pattern]
  if not cp then
    cp = lpegrex.compile(pattern)
    mcache[pattern] = cp
  end
  return cp:match(subject, init or 1)
end

--[[
Searches the given `pattern` in the given `subject`.

If it finds a match, returns the index where this occurrence starts and the index where it ends.
Otherwise, returns nil.

An optional numeric argument `init` makes the search starts at that position in the `subject` string.
]]
function lpegrex.find(subject, pattern, init)
 local cp = fcache[pattern]
  if not cp then
    cp = lpegrex.compile(pattern)
    cp = cp / 0
    cp = lpeg.P{lpeg.Cp() * cp * lpeg.Cp() + 1 * lpeg.V(1)}
    fcache[pattern] = cp
  end
  local i, e = cp:match(subject, init or 1)
  if i then
    return i, e - 1
  else
    return i
  end
end

--[[
Does a global substitution,
replacing all occurrences of `pattern` in the given `subject` by `replacement`.
]]
function lpegrex.gsub(subject, pattern, replacement)
  local cache = gcache[pattern] or {}
  gcache[pattern] = cache
  local cp = cache[replacement]
  if not cp then
    cp = lpegrex.compile(pattern)
    cp = lpeg.Cs((cp / replacement + 1)^0)
    cache[replacement] = cp
  end
  return cp:match(subject)
end

local calclinepatt = lpeg.Ct(((Any - Predef.nl)^0 * lpeg.Cp() * Predef.nl)^0)

--[[
Extract line information from `position` in `subject`.
Returns line number, column number, line content, line start position and line end position.
]]
function lpegrex.calcline(subject, position)
  if position < 0 then error 'invalid position' end
  local sublen = #subject
  if position > sublen then position = sublen end
  local caps = calclinepatt:match(subject:sub(1,position))
  local ncaps = #caps
  local lineno = ncaps + 1
  local lastpos = caps[ncaps] or 0
  local linestart = lastpos + 1
  local colno = position - lastpos
  local lineend = subject:find("\n", position+1, true)
  lineend = lineend and lineend-1 or #subject
  local line = subject:sub(linestart, lineend)
  return lineno, colno, line, linestart, lineend
end

-- Auxiliary function for `prettyast`
local function ast2string(node, indent, ss)
  if node.tag then
    ss[#ss+1] = indent..node.tag
  else
    ss[#ss+1] = indent..'-'
  end
  indent = indent..'| '
  for i=1,#node do
    local child = node[i]
    local ty = type(child)
    if ty == 'table' then
      ast2string(child, indent, ss)
    elseif ty == 'string' then
      local escaped = child
        :gsub([[\]], [[\\]])
        :gsub([["]], [[\"]])
        :gsub('\n', '\\n')
        :gsub('\t', '\\t')
        :gsub('\r', '\\r')
        :gsub('[^ %w%p]', function(s)
          return string.format('\\x%02x', string.byte(s))
        end)
      ss[#ss+1] = indent..'"'..escaped..'"'
    else
      ss[#ss+1] = indent..tostring(child)
    end
  end
end

-- Convert an AST into a human readable string.
function lpegrex.prettyast(node)
  local ss = {}
  ast2string(node, '', ss)
  return table.concat(ss, '\n')
end

return lpegrex

--[[
The MIT License (MIT)

Copyright (c) 2021 Eduardo Bart
Copyright (c) 2014-2020 Sérgio Medeiros
Copyright (c) 2007-2019 Lua.org, PUC-Rio.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]
