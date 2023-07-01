/*
** $Id: lplprint.h $
*/


#if !defined(lplprint_h)
#define lplprint_h


#include "lpltree.h"
#include "lplvm.h"


#if defined(LPEG_DEBUG)

LUAI_FUNC void printpatt (Instruction *p, int n);
LUAI_FUNC void printtree (TTree *tree, int ident);
LUAI_FUNC void printktable (lua_State *L, int idx);
LUAI_FUNC void printcharset (const byte *st);
LUAI_FUNC void printcaplist (Capture *cap, Capture *limit);
LUAI_FUNC void printinst (const Instruction *op, const Instruction *p);

#else

#define printktable(L,idx)  \
	luaL_error(L, "function only implemented in debug mode")
#define printtree(tree,i)  \
	luaL_error(L, "function only implemented in debug mode")
#define printpatt(p,n)  \
	luaL_error(L, "function only implemented in debug mode")

#endif


#endif

