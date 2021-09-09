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
local shaper = require 'nelua.utils.shaper'
local traits = require 'nelua.utils.traits'
local nanotimer = require 'nelua.utils.nanotimer'
local except = require 'nelua.utils.except'
local bn = require 'nelua.utils.bn'
local tabler = require 'nelua.utils.tabler'
local config = require 'nelua.configer'.get()

-- Map of ASTNode classes.
local astklasses = {Node = ASTNode}
-- Map of ASTNode shape checkers.
local astshaper = metamagic.setmetaindex({Node = shaper.ast_node_of(ASTNode)}, shaper)
-- Current parsing source code.
local src
-- Localize some functions used in hot code paths (optimization).
local ASTNode_create_from = ASTNode.create_from

-- Aster module.
local aster = {
  -- Shaper with AST nodes shapes.
  shaper = astshaper,
  -- Cumulative parsing time.
  parsing_time = 0,
  -- List of syntax definitions.
  syntaxes = {}
}

-- Create a new AST node with name `tag` from arguments `...`.
function aster.create(tag, ...)
  local klass = astklasses[tag]
  if not klass then
    errorer.errorf("AST with name '%s' is not registered", tag)
  end
  local node = klass(...)
  if config.check_ast_shape then
    local ok, err = node.shape(node)
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
  return ASTNode_create_from(astklasses[tag], node)
end

-- Create an AST node from a Lua value, converting it as necessary.
function aster.value(value, srcnode)
  local node
  if traits.is_astnode(value) then -- already a node
    node = value
  elseif traits.is_type(value) then -- a type
    local symbol = value.symbol
    if symbol and symbol.value == value and symbol.type.is_type then -- try to reuse symbol
      return aster.Id{'auto', pattr={forcesymbol = symbol}}
    else -- create and use a new symbol for the type
      node = aster.Id{'auto', pattr={
        forcesymbol = require 'nelua.symbol'{
          type = require'nelua.typedefs'.primtypes.type,
          value = value,
      }}}
    end
  elseif traits.is_string(value) then -- a string
    node = aster.String{value}
  elseif traits.is_symbol(value) then -- a symbol
    node = aster.Id{value.name, pattr={forcesymbol = value}}
  elseif traits.is_scalar(value) then -- a number
    local num = bn.parse(value)
    local neg = false
    if bn.isneg(num) then
      num = bn.abs(num)
      neg = true
    end
    node = aster.Number{bn.todec(num)}
    if neg then
      node = aster.UnaryOp{'unm', node}
    end
  elseif traits.is_boolean(value) then -- a boolean
    node = aster.Boolean{value}
  elseif traits.is_table(value) then -- a table
    node = aster.InitList{}
    for k,v in iters.ospairs(value) do -- copy hash part
      node[#node+1] = aster.Pair{k, aster.value(v, srcnode)}
    end
    for _,v in ipairs(value) do -- copy array part
      node[#node+1] = aster.value(v, srcnode)
    end
  elseif value == nil then -- nil
    node = aster.Nil{}
  else
    ASTNode.raisef(srcnode, 'cannot convert preprocess value of type "%s" to an AST node', type(value))
  end
  if srcnode and srcnode.src and srcnode.pos then -- preserve source position
    node:recursive_update_location(srcnode.src, srcnode.pos, srcnode.endpos)
  end
  return node
end

-- Marks a list of nodes to be unpacked.
function aster.unpack(t)
  t._astunpack = true
  return t
end

-- Register a new AST node with name `tag` described by shape `shape`.
function aster.register(tag, shape, props)
  if not getmetatable(shape) then -- not a shape yet
    tabler.update(shape, ASTNode.baseshape.shape)
    shape = shaper.shape(shape)
  end
  -- create a new class for the AST Node
  local klass = class(ASTNode)
  klass.tag = tag
  klass['is_'..tag] = true
  klass.shape = shape
  if props then
    tabler.update(klass, props)
  end
  astklasses[tag] = klass
  astshaper[tag] = shaper.ast_node_of(klass) -- shape checker used in astdefs
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
  return klass
end

--[[
Parse source code `content` with name `name` returning an AST on success.
In case of a syntax error then an exception is thrown.
]]
function aster.parse(content, name, extension)
  local timer
  if config.timing or config.more_timing then
    timer = nanotimer()
  end
  src = {content=content, name=name}
  extension = extension or (name and name:match('%.([^.]+)$')) or 'nelua'
  local syntax = aster.syntaxes[extension] or aster.syntaxes.nelua
  local ast, errlabel, errpos = syntax.patt:match(content)
  if ast and syntax.transformcb then
    ast, errlabel, errpos = syntax.transformcb(ast, content, name)
  end
  if not ast then
    local errmsg = syntax.errors[errlabel] or errlabel
    local message = errorer.get_pretty_source_pos_errmsg(src, errpos, nil, errmsg, 'syntax error')
    except.raise({label = 'ParseError', message = message, errlabel = errlabel, errpos = errpos})
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
Register a new syntax from a PEG grammar, where `syntax` is a table with the fields:
- `extension` is the file extension, used to detect syntax from input names (e.g 'nelua').
- `grammar` is a textual PEG grammar, following LPegRex rules.
- `errors` is a table of syntax errors labels with their description.
- `defs` is a table of default values to be passed to the grammar.
- `transformcb` is a function to be called after successfully parsing a chunk,
it receives arguments `(ast, content, name)`,
it should return the transformed ast back or nil plus an error label and error pos.
]]
function aster.register_syntax(syntax)
  syntax.errors = syntax.errors or {}
  syntax.defs = syntax.defs or {}
  syntax.defs.__options = {tag=aster.create_from}
  if not syntax.patt then
    syntax.patt = lpegrex.compile(syntax.grammar, syntax.defs)
  end
  aster.syntaxes[syntax.extension] = syntax
end

-- Clones an AST or a list of ASTs.
function aster.clone(node)
  if node._astnode then
    return node:clone()
  end
  return ASTNode.clone_nodes(node)
end

-- Converts an AST or a list of ASTs into pretty human readable string.
function aster.pretty(node)
  return ASTNode.pretty(node)
end

-- Need to set aster in `package.loaded` because astdefs depends on it.
package.loaded['nelua.aster'] = aster
require 'nelua.astdefs'

-- Set current aster syntax for parsing.
local syntaxdefs = require 'nelua.syntaxdefs'
aster.register_syntax(syntaxdefs)

return aster
