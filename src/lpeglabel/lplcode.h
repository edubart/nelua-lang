/*
** $Id: lplcode.h $
*/

#if !defined(lplcode_h)
#define lplcode_h

#include "lua.h"

#include "lpltypes.h"
#include "lpltree.h"
#include "lplvm.h"

LUAI_FUNC int tocharset (TTree *tree, Charset *cs);
LUAI_FUNC int checkaux (TTree *tree, int pred);
LUAI_FUNC int fixedlen (TTree *tree);
LUAI_FUNC int hascaptures (TTree *tree);
LUAI_FUNC int lp_gc (lua_State *L);
LUAI_FUNC Instruction *compile (lua_State *L, Pattern *p);
LUAI_FUNC void realloccode (lua_State *L, Pattern *p, int nsize);
LUAI_FUNC int sizei (const Instruction *i);


#define PEnullable      0
#define PEnofail        1

/*
** nofail(t) implies that 't' cannot fail with any input
*/
#define nofail(t)	checkaux(t, PEnofail)

/*
** (not nullable(t)) implies 't' cannot match without consuming
** something
*/
#define nullable(t)	checkaux(t, PEnullable)



#endif
