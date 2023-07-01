/*
** $Id: lplvm.h $
*/

#if !defined(lplvm_h)
#define lplvm_h

#include "lplcap.h"


/* Virtual Machine's instructions */
typedef enum Opcode {
  IAny, /* if no char, fail */
  IChar,  /* if char != aux, fail */
  ISet,  /* if char not in buff, fail */
  ITestAny,  /* in no char, jump to 'offset' */
  ITestChar,  /* if char != aux, jump to 'offset' */
  ITestSet,  /* if char not in buff, jump to 'offset' */
  ISpan,  /* read a span of chars in buff */
  IUTFR,  /* if codepoint not in range [offset, utf_to], fail */
  IBehind,  /* walk back 'aux' characters (fail if not possible) */
  IRet,  /* return from a rule */
  IEnd,  /* end of pattern */
  IChoice,  /* stack a choice; next fail will jump to 'offset' */
  IPredChoice,  /* labeld failure: stack a choice; changes label env next fail will jump to 'offset' */ /*labeled failure */
  IJmp,  /* jump to 'offset' */
  ICall,  /* call rule at 'offset' */
  IOpenCall,  /* call rule number 'key' (must be closed to a ICall) */
  ICommit,  /* pop choice and jump to 'offset' */
  IPartialCommit,  /* update top choice to current position and jump */
  IBackCommit,  /* backtrack like "fail" but jump to its own 'offset' */
  IFailTwice,  /* pop one choice and then fail */
  IFail,  /* go back to saved state on choice and jump to saved offset */
  IGiveup,  /* internal use */
  IFullCapture,  /* complete capture of last 'off' chars */
  IOpenCapture,  /* start a capture */
  ICloseCapture,
  ICloseRunTime,
  IThrow,    /* fails with a given label */ /*labeled failure */
  IThrowRec, /* fails with a given label and call rule at 'offset' */ /*labeled failure */
  IEmpty  /* to fill empty slots left by optimizations */
} Opcode;



typedef union Instruction {
  struct Inst {
    byte code;
    byte aux;
    short key;
  } i;
  int offset;
  byte buff[1];
} Instruction;


/* extract 24-bit value from an instruction */
#define utf_to(inst)	(((inst)->i.key << 8) | (inst)->i.aux)


LUAI_FUNC void printpatt (Instruction *p, int n);
LUAI_FUNC const char *match (lua_State *L, const char *o, const char *s, const char *e,
                   Instruction *op, Capture *capture, int ptop, short *labelf, const char **sfail); /* labeled failure */

#endif

