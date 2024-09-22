--[[
Pegger module

This module defines miscellaneous PEG (Parse Expression Grammars)
for parsing or transforming large strings. It uses the LPEG library.

For more information how these patterns works see
http://www.inf.puc-rio.br/~roberto/lpeg/re.html
]]

local re = require 'nelua.thirdparty.lpegrex'
local metamagic = require 'nelua.utils.metamagic'

local pegger = {}

local double_patt_begin = [[quote <- {~ ''->'"' (quotechar / .)* ''->'"' ~}]] .. '\n'
local single_patt_begin = [[quote <- {~ ''->"'" (quotechar / .)* ''->"'" ~}]] .. '\n'
local quote_patt_begin =  "\
  quotechar <- \
    '\\' -> '\\\\' /  -- backslash \
    '\a' -> '\\a' /   -- audible bell \
    '\b' -> '\\b' /   -- backspace \
    '\f' -> '\\f' /   -- form feed \
    %nl  -> '\\n' /   -- line feed \
    '\r' -> '\\r' /   -- carriege return \
    '\t' -> '\\t' /   -- horizontal tab \
    '\v' -> '\\v' /   -- vertical tab\
"
local single_quote_patt = "\"\'\" -> \"\\'\" /\n"
local double_quote_patt = "'\"' -> '\\\"' /\n"
local lua_quote_patt_end = "\
  [^%g%s] -> to_special_character_lua   -- special characters"
local c_quote_patt_end = "\
  ('??' {[=/'%(%)!<>%-]}) -> '?\\?%1' / -- C trigraphs \
  [^%g%s] -> to_special_character_c     -- special characters"
local quotes_defs = {
  to_special_character_lua = function(s)
    return string.format('\\%03d', string.byte(s))
  end,
  to_special_character_c = function(s)
    return string.format('\\%03o', string.byte(s))
  end
}
local c_double_peg = re.compile(
  double_patt_begin ..
  quote_patt_begin ..
  double_quote_patt ..
  c_quote_patt_end, quotes_defs)
local c_single_peg = re.compile(
  single_patt_begin ..
  quote_patt_begin ..
  single_quote_patt ..
  c_quote_patt_end, quotes_defs)
local lua_double_peg = re.compile(
  double_patt_begin ..
  quote_patt_begin ..
  double_quote_patt ..
  lua_quote_patt_end, quotes_defs)
local lua_single_peg = re.compile(
  single_patt_begin ..
  quote_patt_begin ..
  single_quote_patt ..
  lua_quote_patt_end, quotes_defs)

--[[
Quote a string using double quotes to be used in C code,
escaping special characters as necessary.
]]
function pegger.double_quote_c_string(str)
  return c_double_peg:match(str)
end

--[[
Quote a string using single quotes to be used in C code,
escaping special characters as necessary.
]]
function pegger.single_quote_c_string(str)
  return c_single_peg:match(str)
end

--[[
Quote a string using double quotes to be used in Lua code,
escaping special characters as necessary.
]]
function pegger.double_quote_lua_string(str)
  return lua_double_peg:match(str)
end

--[[
Quote a string using single quotes to be used in Lua code,
escaping special characters as necessary.
]]
function pegger.single_quote_lua_string(str)
  return lua_single_peg:match(str)
end

local substitute_vars = {}
local substitute_defs = { to_var = function(k) return substitute_vars[k] or '' end }
local substitute_patt = re.compile([[
  pat <- {~ (var / .)* ~}
  var <- ('$(' {[_%a]+} ')') -> to_var
]], substitute_defs)

--[[
Substitute keywords between '$()' from a text using values from table.
E.g. substitute('$(cc) $(cflags)', {cc='gcc', cflags='-w'}) -> 'gcc -w'.
]]
function pegger.substitute(format, vars)
  metamagic.setmetaindex(substitute_vars, vars, true)
  return substitute_patt:match(format)
end

local split_execargs_patt = re.compile[[
  args <- %s* {| arg+ |}
  arg <- ({~ squoted_arg ~} / {~ dquoted_arg ~} / {~ simple_arg ~}) %s*
  simple_arg <- (!%s (squoted_arg / dquoted_arg / .))+
  squoted_arg <- "'"->'' (!"'" .)+ "'"->''
  dquoted_arg <- '"'->'' (!'"' .)+ '"'->''
]]

--[[
Split arguments from a command line into a table, removing quotes as necessary.
E.g. split_execargs('./a.out -a "b"') -> {'./a.out', '-a', 'b'}
]]
function pegger.split_execargs(s)
  if not s then return {} end
  return split_execargs_patt:match(s)
end

local filename_to_unitname_patt = re.compile[[
  p <- {~ filebeg? numprefix? c* ~}
  c <- extend -> '' / [_%w] / (%s+ / [_/\.-]) -> '_' / . -> 'X'
  filebeg <- [./\]+ -> ''
  numprefix <- '' -> 'n' [0-9]+
  extend <- '.' [_%w]+ !.
]]

--[[
Convert a file name to an unit name. Used for prefixing functions in C generated code.
E.g. filename_to_unitname('app/utils/tools.nelua') -> 'app_utils_tools'
]]
function pegger.filename_to_unitname(s)
  return filename_to_unitname_patt:match(s)
end

local c_defines_peg = re.compile([[
  defines   <- %s* {| define* |}
  define    <- '#define ' {| {define_name} (' '+ {define_content} / define_content) |} linebreak?
  define_name <- [_%w]+
  define_content <- (!linebreak .)*
]]..
"linebreak <- [%nl]'\r' / '\r'[%nl] / [%nl] / '\r'")

-- Parse C defines from a C header into a table.
function pegger.parse_c_defines(text)
  local t = c_defines_peg:match(text)
  local defs = {}
  for _,v in ipairs(t) do
    local name = v[1]
    local value = v[2]
    if not value or value == '' then
      -- define without content, treat as boolean
      value = true
    else
      -- try to convert to a number
      local numvalue = tonumber(value)
      if numvalue and tostring(numvalue) == value then
        value = numvalue
      end
    end
    defs[name] = value
  end
  return defs
end

local crlf_to_lf_peg = re.compile([[
  text <- {~ (linebreak / .)* ~}
]]..
"linebreak <- ([%nl]'\r' / '\r'[%nl] / [%nl] / '\r') -> ln",
{ln = function() return '\n' end})

--[[
Normalize new lines for different platforms.
Converting LF-CR / CR-LF / CR -> LF.
]]
function pegger.normalize_newlines(text)
  return crlf_to_lf_peg:match(text)
end

return pegger
