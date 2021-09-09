local aster = require 'nelua.aster'
local shaper = aster.shaper
local mydsl = {}

-- Execute new AST node 'Tuple'.
aster.register('Tuple', shaper.array_of(shaper.Node))

-- Grammar of our DSL.
local grammar = [==[
chunk : Tuple   <== SKIP? expr* (!.)^UnexpectedSyntax
expr            <-- Tuple / Number / Boolean / String / Id
Tuple           <== `(` @expr expr* @`)`
Boolean         <== `true`->totrue / `false`->tofalse
Number          <== {[0-9]+ ('.' [0-9]*)?}->tonumber SKIP
String          <== '"' {[^"]+} '"' SKIP
Id              <== {NAME_SUFFIX} SKIP
NAME_SUFFIX     <-- (!')' !';' !%sp .)+
COMMENT         <-- ';' [^%cn]* %cn?
SKIP            <-- (%sp+ / COMMENT)*
]==]

-- List of binary operations that can be used with parenthesis.
local binops = {['+'] = 'add', ['<'] = 'lt', ['..'] = 'concat'}

-- Converts a DSL expression into a Nelua's ASTNode.
function mydsl.make_expr(dslexpr)
  local expr
  if dslexpr.tag == 'Tuple' then
    assert(dslexpr[1].tag == 'Id')
    local funcname = dslexpr[1][1]
    if binops[funcname] then
      expr = aster.BinaryOp{mydsl.make_expr(dslexpr[2]),
                            binops[funcname],
                            mydsl.make_expr(dslexpr[3])}
    else
      expr = aster.Call{mydsl.make_exprs(dslexpr, 2), aster.Id{funcname}}
    end
  else
    expr = aster[dslexpr.tag]{dslexpr[1]} -- String / Number / Boolean / Id
  end
  expr:copy_origin(dslexpr)
  return expr
end

-- Converts a list of DSL expressions into a list of Nelua's expressions.
function mydsl.make_exprs(dslexprs, init, last)
  local exprs = {}
  for i=init,last or #dslexprs do
    table.insert(exprs, mydsl.make_expr(dslexprs[i]))
  end
  return exprs
end

-- Converts a list of DSL ids into a list function parameters.
function mydsl.make_params(dslparams)
  local params = {}
  for _,param in ipairs(dslparams) do
    local paramdecl = aster.IdDecl{param[1], aster.Id{'auto'}}
    paramdecl:copy_origin(param)
    table.insert(params, paramdecl)
  end
  return params
end

-- Transform a list of statements into a block.
function mydsl.make_stmts(dsltuple, init, last)
  local stmts = aster.Block{}
  for i=init or 1,last or #dsltuple do -- loop through all DSL statement nodes
    local dslstmt = dsltuple[i] -- get statement node
    assert(dslstmt.tag == 'Tuple' and dslstmt[1].tag == 'Id') -- we expect only Tuple nodes
    local dslid = dslstmt[1]
    local action = dslid[1] -- action name for the Tuple node
    local stmt
    if action == 'let' then -- variable declaration
      local dslvarid, expr = dslstmt[2], mydsl.make_expr(dslstmt[3])
      local varid = aster.IdDecl{dslvarid[1]}
      varid:copy_origin(dslvarid)
      stmt = aster.VarDecl{'local', {varid}, {expr}}
    elseif action == 'fn' then -- function definition
      local dslfnid = dslstmt[2]
      local fnname, fnparams = dslfnid[1], mydsl.make_params(dslstmt[3])
      local fnid, fnrets, fnannots = aster.IdDecl{fnname}:copy_origin(dslfnid), false, false
      local fnblock = mydsl.make_stmts(dslstmt, 4, #dslstmt-1)
      local fnlastret = mydsl.make_expr(dslstmt[#dslstmt])
      table.insert(fnblock, aster.Return{fnlastret})
      stmt = aster.FuncDef{'local', fnid, fnparams, fnrets, fnannots, fnblock}
    elseif action == 'while' then -- while loop
      local cond, block = mydsl.make_expr(dslstmt[2]), mydsl.make_stmts(dslstmt, 3)
      stmt = aster.While{cond, block}
    elseif action == '=' then -- variable assignment
      local varid, expr = dslstmt[2], mydsl.make_expr(dslstmt[3])
      stmt = aster.Assign{{varid}, {expr}}
    else -- function call
      local args, id = mydsl.make_exprs(dslstmt, 2), dslid
      stmt = aster.Call{args, id}
    end
    stmt:copy_origin(dslstmt)
    table.insert(stmts, stmt)
  end
  stmts:copy_origin(dsltuple)
  return stmts
end

function mydsl.compile(ast)
  -- uncomment the following to debug/preview the input DSL AST
  -- print(ast:pretty())
  ast = mydsl.make_stmts(ast)
  -- uncomment the following to debug/preview the output Nelua AST
  -- print(ast:pretty())
  return ast
end

aster.register_syntax({
  extension = 'lisp',
  grammar = grammar,
  transformcb = mydsl.compile,
  errors = {},
})
