--[[
Syntaxdefs module.

This module define the Nelua syntax for parsing with the Aster module.

The syntax is defined a single PEG rule, for instructions on how to read
the rules please check LPegRex, LPegLabel and LPeg RE manuals:
* https://github.com/edubart/lpegrex
* https://github.com/sqmedeiros/lpeglabel
* http://www.inf.puc-rio.br/~roberto/lpeg/re.html
]]

-- Complete syntax grammar of Nelua defined in a single PEG.
local grammar = [==[
chunk           <-- SHEBANG? SKIP Block (!.)^UnexpectedSyntax

Block           <==(local / global /
                    FuncDef / Return /
                    Do / Defer /
                    If / Switch /
                    for /
                    While / Repeat /
                    Break / Continue /
                    Goto / Label /
                    Preprocess /
                    Assign / call /
                    `;`)*

-- Statements
Label           <== `::` @name @`::`
Return          <== `return` (expr (`,` @expr)*)?
Break           <== `break`
Continue        <== `continue`
Goto            <== `goto` @name
Do              <== `do` Block @`end`
Defer           <== `defer` Block @`end`
While           <== `while` @expr @`do` Block @`end`
Repeat          <== `repeat` Block @`until` @expr
If              <== `if` ifs (`else` Block)? @`end`
ifs             <-| @expr @`then` Block (`elseif` @expr @`then` Block)*
Switch          <== `switch` @expr `do`? @cases (`else` Block)? @`end`
cases           <-| (`case` @exprs @`then` Block)+
for             <-- `for` (ForNum / ForIn)
ForNum          <== IdDecl `=` @expr @`,` forcmp~? @expr (`,` @expr)~? @`do` Block @`end`
ForIn           <== @iddecls @`in` @exprs @`do` Block @`end`
local           <-- `local` (localfunc / localvar)
global          <-- `global` (globalfunc / globalvar)
localfunc  : FuncDef  <== `function` $'local' @namedecl @funcbody
globalfunc : FuncDef  <== `function` $'global' @namedecl @funcbody
FuncDef         <== `function` $false @funcname @funcbody
funcbody        <-- `(` funcargs @`)` (`:` @funcrets)~? annots~? Block @`end`
localvar   : VarDecl  <== $'local' @iddecls (`=` @exprs)?
globalvar  : VarDecl  <== $'global' @globaldecls (`=` @exprs)?
Assign          <== vars `=` @exprs
Preprocess      <== PREPROCESS SKIP

-- Simple expressions
Number          <== NUMBER name? SKIP
String          <== STRING name? SKIP
Boolean         <== `true`->totrue / `false`->tofalse
Nil             <== `nil`
Varargs         <== `...`
Id              <== name
IdDecl          <== name (`:` @typeexpr)~? annots?
iddeclexpr      <-- IdDecl / PreprocessExpr
typeddecl  : IdDecl <== name `:` @typeexpr annots?
globaldecl : IdDecl <== (idsuffixed / name) (`:` @typeexpr)~? annots?
globaldeclexpr  <-- globaldecl / PreprocessExpr
namedecl   : IdDecl <== name
Function        <== `function` @funcbody
InitList        <== `{` (field (fieldsep field)* fieldsep?)? @`}`
field           <-- Pair / expr
Paren           <== `(` @expr @`)`
DoExpr          <== `(` `do` Block @`end` @`)`
Type            <== `@` @typeexpr

Pair            <== `[` @expr @`]` @`=` @expr / name `=` @expr / `=` @Id -> pair_sugar
Annotation      <== name callargs?

-- Preprocessor replaceable nodes
PreprocessExpr  <== `#[` {@expr->0} @`]#`
PreprocessName  <== `#|` {@expr->0} @`|#`

-- Suffixes
Call            <== callargs
CallMethod      <== `:` @name @callargs
DotIndex        <== `.` @name
ColonIndex      <== `:` @name
KeyIndex        <== `[` @expr @`]`

indexsuffix     <-- DotIndex / KeyIndex
callsuffix      <-- Call / CallMethod

var             <-- (exprprim (indexsuffix / callsuffix+ indexsuffix)+)~>rfoldright / Id / deref
call            <-- (exprprim (callsuffix / indexsuffix+ callsuffix)+)~>rfoldright
exprsuffixed    <-- (exprprim (indexsuffix / callsuffix)*)~>rfoldright
idsuffixed      <-- (Id DotIndex+)~>rfoldright
funcname        <-- (Id DotIndex* ColonIndex?)~>rfoldright

-- Lists
callargs        <-| `(` (expr (`,` @expr)*)? @`)` / InitList / String / PreprocessExpr
iddecls         <-| iddeclexpr (`,` @iddeclexpr)*
funcargs        <-| (iddeclexpr (`,` iddeclexpr)* (`,` VarargsType)? / VarargsType)?
globaldecls     <-| globaldeclexpr (`,` @globaldeclexpr)*
exprs           <-| expr (`,` @expr)*
annots          <-| `<` @Annotation (`,` @Annotation)* @`>`
funcrets        <-| `(` typeexpr (`,` @typeexpr)* @`)` / typeexpr
vars            <-| var (`,` @var)*

-- Expression operators
opor      : BinaryOp  <== `or`->'or' @exprand
opand     : BinaryOp  <== `and`->'and' @exprcmp
opcmp     : BinaryOp  <== cmp @exprbor
opbor     : BinaryOp  <== `|`->'bor' @exprbxor
opbxor    : BinaryOp  <== `~`->'bxor' @exprband
opband    : BinaryOp  <== `&`->'band' @exprbshift
opbshift  : BinaryOp  <== (`<<`->'shl' / `>>>`->'asr' / `>>`->'shr') @exprconcat
opconcat  : BinaryOp  <== `..`->'concat' @exprconcat
oparit    : BinaryOp  <== (`+`->'add' / `-`->'sub') @exprfact
opfact    : BinaryOp  <== (`*`->'mul' / `///`->'tdiv' / `//`->'idiv' / `/`->'div' /
                           `%%%`->'tmod' / `%`->'mod') @exprunary
oppow     : BinaryOp  <== `^`->'pow' @exprunary
opunary   : UnaryOp   <== (`not`->'not' / `-`->'unm' / `#`->'len' /
                           `~`->'bnot' / `&`->'ref' / `$`->'deref') @exprunary
deref     : UnaryOp   <== `$`->'deref' @exprunary

-- Expressions
expr            <-- expror
expror          <-- (exprand opor*)~>foldleft
exprand         <-- (exprcmp opand*)~>foldleft
exprcmp         <-- (exprbor opcmp*)~>foldleft
exprbor         <-- (exprbxor opbor*)~>foldleft
exprbxor        <-- (exprband opbxor*)~>foldleft
exprband        <-- (exprbshift opband*)~>foldleft
exprbshift      <-- (exprconcat opbshift*)~>foldleft
exprconcat      <-- (exprarit opconcat*)~>foldleft
exprarit        <-- (exprfact oparit*)~>foldleft
exprfact        <-- (exprunary opfact*)~>foldleft
exprunary       <-- opunary / exprpow
exprpow         <-- (exprsimple oppow*)~>foldleft
exprsimple      <-- Number / String / Type / InitList / Boolean /
                    Function / Nil / DoExpr / Varargs / exprsuffixed
exprprim        <-- Id / Paren / PreprocessExpr

-- Types
RecordType      <== 'record' WORDSKIP @`{` (RecordField (fieldsep RecordField)* fieldsep?)? @`}`
UnionType       <== 'union' WORDSKIP @`{` (UnionField (fieldsep UnionField)* fieldsep?)? @`}`
EnumType        <== 'enum' WORDSKIP (`(` @typeexpr @`)`)~? @`{` @enumfields @`}`
FuncType        <== 'function' WORDSKIP @`(` functypeargs @`)`(`:` @funcrets)?
ArrayType       <== 'array' WORDSKIP @`(` @typeexpr (`,` @expr)? @`)`
PointerType     <== 'pointer' WORDSKIP (`(` @typeexpr @`)`)?
VariantType     <== 'variant' WORDSKIP `(` @typearg (`,` @typearg)* @`)`
VarargsType     <== `...` (`:` @name)?

RecordField     <== name @`:` @typeexpr
UnionField      <== name `:` @typeexpr / $false typeexpr
EnumField       <== name (`=` @expr)?

-- Type lists
enumfields      <-| EnumField (fieldsep EnumField)* fieldsep?
functypeargs    <-| (functypearg (`,` functypearg)* (`,` VarargsType)? / VarargsType)?
typeargs        <-| typearg (`,` @typearg)*

functypearg     <-- typeddecl / typeexpr
typearg         <-- typeexpr / `(` expr @`)` / expr

-- Type expression operators
typeopptr : PointerType   <== `*`
typeopopt : OptionalType  <== `?`
typeoparr : ArrayType     <== `[` expr? @`]`
typeopvar : VariantType   <== typevaris
typeopgen : GenericType   <== `(` @typeargs @`)`
typevaris : VariantType   <== `|` @typeexprunary (`|` @typeexprunary)*

typeopunary     <-- typeopptr / typeopopt / typeoparr

-- Type expressions
typeexpr        <-- (typeexprunary typevaris?)~>foldleft
typeexprunary   <-- (typeopunary* typexprsimple)->rfoldleft
typexprsimple   <-- RecordType / UnionType / EnumType / FuncType / ArrayType / PointerType /
                    VariantType / (typeexprprim typeopgen?)~>foldleft
typeexprprim    <-- idsuffixed / Id / PreprocessExpr

-- Common rules
name            <-- NAME SKIP / PreprocessName
cmp             <-- `==`->'eq' / forcmp
forcmp          <-- `~=`->'ne' / `<=`->'le' / `<`->'lt' / `>=`->'ge' / `>`->'gt'
fieldsep        <-- `,` / `;`

-- String
STRING          <-- STRING_SHRT / STRING_LONG
STRING_LONG     <-- {:LONG_OPEN {LONG_CONTENT} @LONG_CLOSE:}
STRING_SHRT     <-- {:QUOTE_OPEN {~QUOTE_CONTENT~} @QUOTE_CLOSE:}
QUOTE_OPEN      <-- {:qe: ['"] :}
QUOTE_CONTENT   <-- (ESCAPE_SEQ / !(QUOTE_CLOSE / LINEBREAK) .)*
QUOTE_CLOSE     <-- =qe
ESCAPE_SEQ      <-- '\'->'' @ESCAPE
ESCAPE          <-- [\'"] /
                    ('n' $10 / 't' $9 / 'r' $13 / 'a' $7 / 'b' $8 / 'v' $11 / 'f' $12)->tochar /
                    ('x' {HEX_DIGIT^2} $16)->tochar /
                    ('u' '{' {HEX_DIGIT^+1} '}' $16)->toutf8char /
                    ('z' SPACE*)->'' /
                    (DEC_DIGIT DEC_DIGIT^-1 !DEC_DIGIT / [012] DEC_DIGIT^2)->tochar /
                    (LINEBREAK $10)->tochar

-- Number
NUMBER          <-- {HEX_NUMBER / BIN_NUMBER / DEC_NUMBER}
HEX_NUMBER      <-- '0' [xX] @HEX_PREFIX ([pP] @EXP_DIGITS)?
BIN_NUMBER      <-- '0' [bB] @BIN_PREFIX ([pP] @EXP_DIGITS)?
DEC_NUMBER      <-- DEC_PREFIX ([eE] @EXP_DIGITS)?
HEX_PREFIX      <-- HEX_DIGIT+ ('.' HEX_DIGIT*)? / '.' HEX_DIGIT+
BIN_PREFIX      <-- BIN_DIGITS ('.' BIN_DIGITS?)? / '.' BIN_DIGITS
DEC_PREFIX      <-- DEC_DIGIT+ ('.' DEC_DIGIT*)? / '.' DEC_DIGIT+
EXP_DIGITS      <-- [+-]? DEC_DIGIT+

-- Comments
COMMENT         <-- '--' (COMMENT_LONG / COMMENT_SHRT)
COMMENT_LONG    <-- (LONG_OPEN LONG_CONTENT @LONG_CLOSE)->0
COMMENT_SHRT    <-- (!LINEBREAK .)*

-- Preprocess
PREPROCESS      <-- '##' (PREPROCESS_LONG / PREPROCESS_SHRT)
PREPROCESS_LONG <-- {:LONG_OPEN {LONG_CONTENT} @LONG_CLOSE:}
PREPROCESS_SHRT <-- {(!LINEBREAK .)*} LINEBREAK?

-- Long (used by string, comment and preprocess)
LONG_CONTENT    <-- (!LONG_CLOSE .)*
LONG_OPEN       <-- '[' {:eq: '='*:} '[' LINEBREAK?
LONG_CLOSE      <-- ']' =eq ']'

NAME            <-- !KEYWORD {NAME_PREFIX NAME_SUFFIX?}
NAME_PREFIX     <-- [_a-zA-Z%utf8seq]
NAME_SUFFIX     <-- [_a-zA-Z0-9%utf8seq]+

-- Miscellaneous
SHEBANG         <-- '#!' (!LINEBREAK .)* LINEBREAK?
SKIP            <-- (SPACE+ / COMMENT)*
WORDSKIP        <-- !NAME_SUFFIX SKIP
LINEBREAK       <-- %cn %cr / %cr %cn / %cn / %cr
SPACE           <-- %sp
HEX_DIGIT       <-- [0-9a-fA-F]
BIN_DIGITS      <-- [01]+ !DEC_DIGIT
DEC_DIGIT       <-- [0-9]
EXTRA_TOKENS    <-- `[[` `[=` `--` `##` -- Force defining these tokens.
]==]

-- List of syntax errors.
local errors = {
["Expected_do"]             = "expected `do` keyword to begin a statement block",
["Expected_then"]           = "expected `then` keyword to begin a statement block",
["Expected_end"]            = "expected `end` keyword to close a statement block",
["Expected_until"]          = "expected `until` keyword to close a `repeat` statement",
["Expected_cases"]          = "expected `case` keyword in `switch` statement",
["Expected_in"]             = "expected `in` keyword in `for` statement",
["Expected_Annotation"]     = "expected an annotation expression",
["Expected_expr"]           = "expected an expression",
["Expected_exprand"]        = "expected an expression after operator",
["Expected_exprcmp"]        = "expected an expression after operator",
["Expected_exprbor"]        = "expected an expression after operator",
["Expected_exprbxor"]       = "expected an expression after operator",
["Expected_exprband"]       = "expected an expression after operator",
["Expected_exprbshift"]     = "expected an expression after operator",
["Expected_exprconcat"]     = "expected an expression after operator",
["Expected_exprfact"]       = "expected an expression after operator",
["Expected_exprunary"]      = "expected an expression after operator",
["Expected_name"]           = "expected an identifier name",
["Expected_namedecl"]       = "expected an identifier name",
["Expected_Id"]             = "expected an identifier name",
["Expected_IdDecl"]         = "expected an identifier declaration",
["Expected_typearg"]        = "expected an argument in type expression",
["Expected_typeexpr"]       = "expected a type expression",
["Expected_typeexprunary"]  = "expected a type expression",
["Expected_funcbody"]       = "expected function body",
["Expected_funcrets"]       = "expected function return types",
["Expected_funcname"]       = "expected a function name",
["Expected_globaldecl"]     = "expected a global identifier declaration",
["Expected_var"]            = "expected a variable",
["Expected_enumfields"]     = "expected a field in `enum` type",
["Expected_typeargs"]       = "expected arguments in type expression",
["Expected_callargs"]       = "expected call arguments",
["Expected_exprs"]          = "expected expressions",
["Expected_globaldecls"]    = "expected global identifiers declaration",
["Expected_iddecls"]        = "expected identifiers declaration",
["Expected_("]              = "expected parenthesis `(`",
["Expected_,"]              = "expected comma `,`",
["Expected_:"]              = "expected colon `:`",
["Expected_="]              = "expected equals `=`",
["Expected_{"]              = "expected curly brace `{`",
["Expected_)"]              = "unclosed parenthesis, did you forget a `)`?",
["Expected_::"]             = "unclosed label, did you forget a `::`?",
["Expected_>"]              = "unclosed angle bracket, did you forget a `>`?",
["Expected_]"]              = "unclosed square bracket, did you forget a `]`?",
["Expected_}"]              = "unclosed curly brace, did you forget a `}`?",
["Expected_]#"]             = "unclosed preprocess expression, did you forget a `]#`?",
["Expected_|#"]             = "unclosed preprocess name, did you forget a `|#`?",
["Expected_LONG_CLOSE"]     = "unclosed long, did you forget a `]]`?",
["Expected_QUOTE_CLOSE"]    = "unclosed string, did you forget a quote?",
["Expected_ESCAPE"]         = "malformed escape sequence",
["Expected_BIN_PREFIX"]     = "malformed binary number",
["Expected_EXP_DIGITS"]     = "malformed exponential number",
["Expected_HEX_PREFIX"]     = "malformed hexadecimal number",
["UnexpectedSyntax"]        = "unexpected syntax",
}

local defs = {}

-- Auxiliary function for 'Pair' syntax sugar.
function defs.pair_sugar(idnode)
  return idnode[1], idnode
end

return {
  errors = errors,
  grammar = grammar,
  defs = defs
}
