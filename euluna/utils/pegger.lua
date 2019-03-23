local re = require 'relabel'
local errorer = require 'euluna.utils.errorer'
local tabler = require 'euluna.utils.tabler'

local pegger = {}

local quote_patt_begin =  "\
  quote <- {~ (quotechar / .)* ~} \
  quotechar <- \
    '\\' -> '\\\\' /  -- backslash \
    '\a' -> '\\a' /   -- audible bell \
    '\b' -> '\\b' /   -- backspace \
    '\f' -> '\\f' /   -- form feed \
    %nl  -> '\\n' /   -- line feed \
    '\r' -> '\\r' /   -- carriege return \
    '\t' -> '\\t' /   -- horizontal tab \
    '\v' -> '\\v' /   -- vertical tab"
local single_quote_patt = "\"\'\" -> \"\\'\" /\n"
local double_quote_patt = "'\"' -> '\\\"' /\n"
local lua_quote_patt_end = "\
  [^%g%s] -> to_special_character_lua   -- special characters"
local c_quote_patt_end = "\
  ('??' {[=/'%(%)!<>%-]}) -> '?\\?%1' / -- C trigraphs \
  [^%g%s] -> to_special_character_c     -- special characters"

local quotes_defs = {
  to_special_character_lua = function(s)
    return '\\' .. string.byte(s)
  end,
  to_special_character_c = function(s)
    return string.format('\\x%02x', string.byte(s))
  end
}

local c_double_pegger = re.compile(
  quote_patt_begin ..
  double_quote_patt ..
  c_quote_patt_end, quotes_defs)
function pegger.double_quote_c_string(str)
  return '"' .. c_double_pegger:match(str) .. '"'
end

local lua_double_pegger = re.compile(
  quote_patt_begin ..
  double_quote_patt ..
  lua_quote_patt_end, quotes_defs)
function pegger.double_quote_lua_string(str)
  return '"' .. lua_double_pegger:match(str) .. '"'
end

local lua_single_pegger = re.compile(
  quote_patt_begin ..
  single_quote_patt ..
  lua_quote_patt_end, quotes_defs)
function pegger.single_quote_lua_string(str)
  return "'" .. lua_single_pegger:match(str) .. "'"
end

--[[
local c_single_pegger = re.compile(
  quote_patt_begin ..
  single_quote_patt ..
  c_quote_patt_end, quotes_defs)
function pegger.single_quote_c_string(str)
  return "'" .. c_single_pegger:match(str) .. "'"
end
]]

local combined_grammar_peg_pat = re.compile([[
pegs       <- {| (comment/peg)+ |}
peg        <- {| peg_head {peg_char*} |}
peg_head   <- %s* {[-_%w]+} %s* '<-' %s*
peg_char   <- !next_peg .
next_peg   <- linebreak %s* [-_%w]+ %s* '<-' %s*
comment    <- %s* '--' (!linebreak .)* linebreak?
]] ..
"linebreak <- [%nl]'\r' / '\r'[%nl] / [%nl] / '\r'"
)
function pegger.split_grammar_patts(combined_patts)
  local pattdescs = combined_grammar_peg_pat:match(combined_patts)
  errorer.assertf(pattdescs, 'invalid multiple pegs patterns syntax: %s', combined_patts)
  return tabler.imap(pattdescs, function(v)
    return {name = v[1], patt = v[2]}
  end)
end

local combined_parser_peg_pat = re.compile([[
pegs       <- {| (comment/peg)+ |}
peg        <- {| peg_head {peg_char*} |}
peg_head   <- %s* '%' {[-_%w]+} %s* '<-' %s*
peg_char   <- !next_peg .
next_peg   <- linebreak %s* '%' [-_%w]+ %s* '<-' %s*
comment    <- %s* '--' (!linebreak .)* linebreak?
]] ..
"linebreak <- [%nl]'\r' / '\r'[%nl] / [%nl] / '\r'"
)
function pegger.split_parser_patts(combined_patts)
  local pattdescs = combined_parser_peg_pat:match(combined_patts)
  errorer.assertf(pattdescs, 'invalid multiple pegs patterns syntax: %s', combined_patts)
  return tabler.imap(pattdescs, function(v)
    return {name = v[1], patt = v[2]}
  end)
end

return pegger
