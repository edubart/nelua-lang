--[[
Aster module

The aster module is used to create AST nodes or parse source code into an AST.
It also has AST shape checking system and function to register ASTNode shapes
]]

local class = require 'nelua.utils.class'
local lpegrex = require 'nelua.thirdparty.lpegrex'
local errorer = require 'nelua.utils.errorer'
local metamagic = require 'nelua.utils.metamagic'
local console = require 'nelua.utils.console'
local iters = require 'nelua.utils.iterators'
local ASTNode = require 'nelua.astnode'
local config = require 'nelua.configer'.get()
local shaper = require 'nelua.utils.shaper'
local traits = require 'nelua.utils.traits'
local nanotimer = require 'nelua.utils.nanotimer'
local except = require 'nelua.utils.except'
local bn = require 'nelua.utils.bn'

-- Map of ASTNode classes
local node_klasses = {Node = ASTNode}
-- Map of ASTNode shapes.
local node_shapes = {Node = shaper.shape{}}
-- Map of ASTNode shape checkers.
local ast_shaper = metamagic.setmetaindex({Node = shaper.ast_node_of(ASTNode)}, shaper)

local ASTNode_create_from = ASTNode.create_from
local src -- current parsing source

-- Aster module.
local aster = {
  shaper = ast_shaper, --
  parsing_time = 0 -- cumulative parsing time
}

-- Create a new AST node with name `tag` from arguments `...`.
function aster.create(tag, ...)
  local klass = node_klasses[tag]
  if not klass then
    errorer.errorf("AST with name '%s' is not registered", tag)
  end
  local node = klass(...)
  if config.check_ast_shape then
    local shape = node_shapes[tag]
    local ok, err = shape(node)
    errorer.assertf(ok, 'invalid shape while creating AST node "%s": %s', tag, err)
  end
  return node
end

--[[
Create an AST node with name `tag` from exiting table `node`.
Every time a new AST node is created while parsing this function is called.
]]
function aster.create_from(tag, node)
  node.src = src
  return ASTNode_create_from(node_klasses[tag], node)
end

-- Create an AST node from a Lua value, converting it as necessary.
function aster.create_value(val, srcnode)
  local node
  if traits.is_astnode(val) then
    node = val
  elseif traits.is_type(val) then
    local Symbol = require 'nelua.symbol'
    node = aster.Id{'auto', pattr={
      forcesymbol = Symbol{
        type = require'nelua.typedefs'.primtypes.type,
        value = val,
    }}}
  elseif traits.is_string(val) then
    node = aster.String{val}
  elseif traits.is_symbol(val) then
    node = aster.Id{val.name, pattr={
      forcesymbol = val
    }}
  elseif bn.isnumeric(val) then
    local num = bn.parse(val)
    local neg = false
    if bn.isneg(num) then
      num = bn.abs(num)
      neg = true
    end
    node = aster.Number{bn.todec(num)}
    if neg then
      node = aster.UnaryOp{'unm', node}
    end
  elseif traits.is_boolean(val) then
    node = aster.Boolean{val}
  elseif traits.is_table(val) then
    node = aster.InitList{}
    -- hash part
    for k,v in iters.ospairs(val) do
      node[#node+1] = aster.Pair{
        k,
        aster.create_value(v, srcnode)
      }
    end
    -- integer part
    for _,v in ipairs(val) do
      node[#node+1] = aster.create_value(v, srcnode)
    end
  elseif val == nil then
    node = aster.Nil{}
  end
  if node and srcnode then
    node.src = srcnode.src
    node.pos = srcnode.pos
    node.endpos = srcnode.endpos
  end
  return node
end

function aster.unpack(t)
  t._astunpack = true
  return t
end

-- Register a new AST node with name `tag` described by shape `shape`.
function aster.register(tag, shape)
  if not getmetatable(shape) then -- not a shape yet
    shape.attr = shaper.table:is_optional()
    shape.src = shaper.table:is_optional()
    shape.uid = shaper.number:is_optional()
    shape = shaper.shape(shape)
  end
  -- create a new class for the AST Node
  local klass = class(ASTNode)
  klass.tag = tag
  node_klasses[tag] = klass
  ast_shaper[tag] = shaper.ast_node_of(klass) -- shape checker used in astdefs
  node_shapes[tag] = shape -- shape checker used with 'check_ast_shape'
  -- allow calling the aster for creating any AST node.
  aster[tag] = function(params)
    local node = aster.create(tag, table.unpack(params))
    for k,v in iters.spairs(params) do -- set all string keys
      node[k] = v
    end
    if params.pattr then -- merge persistent attributes
      node.attr:merge(params.pattr)
    end
    return node
  end
  aster[tag] = aster[tag]
  return klass
end

--[[
Parse source code `content` with name `name` returning an AST on success.
In case of a syntax error then an exception is thrown.
]]
function aster.parse(content, name)
  local timer
  if config.timing or config.more_timing then
    timer = nanotimer()
  end
  src = {content=content, name=name}
  local ast, errlabel, errpos = aster.syntax_patt:match(content)
  if not ast then
    local errmsg = aster.syntax_errors[errlabel] or errlabel
    local message = errorer.get_pretty_source_pos_errmsg(src, errpos, nil, errmsg, 'syntax error')
    except.raise({
      label = 'ParseError',
      message = message,
      errlabel = errlabel,
      errpos = errpos,
    })
  end
  src = nil
  if timer then
    local elapsed = timer:elapsed()
    aster.parsing_time = aster.parsing_time + elapsed
    if config.more_timing then
      console.debugf('parsed %s (%.1f ms)', name, elapsed)
    end
  end
  return ast
end

--[[
Set syntax from a PEG grammar `grammar` and error label list `errors`.
]]
function aster.set_syntax(grammar, errors, defs)
  defs = defs or {}
  defs.__options = {tag=aster.create_from}
  aster.grammar = grammar
  aster.syntax_errors = errors
  aster.defs = defs
  aster.syntax_patt = lpegrex.compile(grammar, defs)
end

-- Need to set aster in `package.loaded` because astdefs depends on it.
package.loaded['nelua.aster'] = aster
require 'nelua.astdefs'

-- Set current aster syntax for parsing.
local syntaxdefs = require 'nelua.syntaxdefs'
aster.set_syntax(syntaxdefs.grammar, syntaxdefs.errors, syntaxdefs.defs)

return aster
