/*
** $Id: lplprint.c $
** Copyright 2007, Lua.org & PUC-Rio  (see 'lpeg.html' for license)
*/

#include <ctype.h>
#include <limits.h>
#include <stdio.h>


#include "lpltypes.h"
#include "lplprint.h"
#include "lplcode.h"


#if defined(LPEG_DEBUG)

/*
** {======================================================
** Printing patterns (for debugging)
** =======================================================
*/


void printcharset (const byte *st) {
  int i;
  printf("[");
  for (i = 0; i <= UCHAR_MAX; i++) {
    int first = i;
    while (testchar(st, i) && i <= UCHAR_MAX) i++;
    if (i - 1 == first)  /* unary range? */
      printf("(%02x)", first);
    else if (i - 1 > first)  /* non-empty range? */
      printf("(%02x-%02x)", first, i - 1);
  }
  printf("]");
}


static const char *capkind (int kind) {
  const char *const modes[] = {
    "close", "position", "constant", "backref",
    "argument", "simple", "table", "function",
    "query", "string", "num", "substitution", "fold",
    "runtime", "group"};
  return modes[kind];
}


static void printjmp (const Instruction *op, const Instruction *p) {
  printf("-> %d", (int)(p + (p + 1)->offset - op));
}


void printinst (const Instruction *op, const Instruction *p) {
  const char *const names[] = {
    "any", "char", "set",
    "testany", "testchar", "testset",
    "span", "utf-range", "behind",
    "ret", "end",
    "choice", "pred_choice", "jmp", "call", "open_call", /* labeled failure */
    "commit", "partial_commit", "back_commit", "failtwice", "fail", "giveup",
     "fullcapture", "opencapture", "closecapture", "closeruntime",
    "throw", "throw_rec",  /* labeled failure */
     "--"
  };
  printf("%02ld: %s ", (long)(p - op), names[p->i.code]);
  switch ((Opcode)p->i.code) {
    case IChar: {
      printf("'%c' (%02x)", p->i.aux, p->i.aux);
      break;
    }
    case ITestChar: {
      printf("'%c' (%02x)", p->i.aux, p->i.aux); printjmp(op, p);
      break;
    }
    case IUTFR: {
      printf("%d - %d", p[1].offset, utf_to(p));
      break;
    }
    case IFullCapture: {
      printf("%s (size = %d)  (idx = %d)",
             capkind(getkind(p)), getoff(p), p->i.key);
      break;
    }
    case IOpenCapture: {
      printf("%s (idx = %d)", capkind(getkind(p)), p->i.key);
      break;
    }
    case ISet: {
      printcharset((p+1)->buff);
      break;
    }
    case ITestSet: {
      printcharset((p+2)->buff); printjmp(op, p);
      break;
    }
    case ISpan: {
      printcharset((p+1)->buff);
      break;
    }
    case IOpenCall: {
      printf("-> %d", (p + 1)->offset);
      break;
    }
    case IBehind: {
      printf("%d", p->i.aux);
      break;
    }
    case IJmp: case ICall: case ICommit: case IChoice:
    case IPartialCommit: case IBackCommit: case ITestAny:
    case IPredChoice: { /* labeled failure */
      printjmp(op, p);
      break;
    }
    case IThrow: { /* labeled failure */
      printf("(idx = %d)", (p + 1)->i.key);
      break;
    }
    case IThrowRec: { /* labeled failure */
      printjmp(op, p); printf(" (idx = %d)", (p + 2)->i.key);
      break;
    }
    default: break;
  }
  printf("\n");
}


void printpatt (Instruction *p, int n) {
  Instruction *op = p;
  while (p < op + n) {
    printinst(op, p);
    p += sizei(p);
  }
}


#if defined(LPEG_DEBUG)
static void printcap (Capture *cap) {
  printf("%s (idx: %d - size: %d) -> %p\n",
         capkind(cap->kind), cap->idx, cap->siz, cap->s);
}


void printcaplist (Capture *cap, Capture *limit) {
  printf(">======\n");
  for (; cap->s && (limit == NULL || cap < limit); cap++)
    printcap(cap);
  printf("=======\n");
}
#endif

/* }====================================================== */


/*
** {======================================================
** Printing trees (for debugging)
** =======================================================
*/

static const char *tagnames[] = {
  "char", "set", "any",
  "true", "false", "utf8.range",
  "rep",
  "seq", "choice",
  "not", "and",
  "call", "opencall", "rule", "xinfo", "grammar",
  "behind",
  "capture", "run-time",
  "throw"  /* labeled failure */
};


void printtree (TTree *tree, int ident) {
  int i;
  int sibs = numsiblings[tree->tag];
  for (i = 0; i < ident; i++) printf(" ");
  printf("%s", tagnames[tree->tag]);
  switch (tree->tag) {
    case TChar: {
      int c = tree->u.n;
      if (isprint(c))
        printf(" '%c'\n", c);
      else
        printf(" (%02X)\n", c);
      break;
    }
    case TSet: {
      printcharset(treebuffer(tree));
      printf("\n");
      break;
    }
    case TUTFR: {
      assert(sib1(tree)->tag == TXInfo);
      printf(" %d (%02x %d) - %d (%02x %d) \n",
        tree->u.n, tree->key, tree->cap,
        sib1(tree)->u.n, sib1(tree)->key, sib1(tree)->cap);
      break;
    }
    case TOpenCall: case TCall: {
      assert(sib1(sib2(tree))->tag == TXInfo);
      printf(" key: %d  (rule: %d)\n", tree->key, sib1(sib2(tree))->u.n);
      break;
    }
    case TBehind: {
      printf(" %d\n", tree->u.n);
      break;
    }
    case TCapture: {
      printf(" kind: '%s'  key: %d\n", capkind(tree->cap), tree->key);
      break;
    }
    case TRule: {
      printf(" key: %d\n", tree->key);
      sibs = 1;  /* do not print 'sib2' (next rule) as a sibling */
      break;
    }
    case TXInfo: {
      printf(" n: %d\n", tree->u.n);
      break;
    }
    case TGrammar: {
      TTree *rule = sib1(tree);
      printf(" %d\n", tree->u.n);  /* number of rules */
      for (i = 0; i < tree->u.n; i++) {
        printtree(rule, ident + 2);
        rule = sib2(rule);
      }
      assert(rule->tag == TTrue);  /* sentinel */
      sibs = 0;  /* siblings already handled */
      break;
    }
    case TThrow: { /* labeled failure */
      if (tree->u.ps != 0) 
        assert(sib2(tree)->tag == TRule);
      printf(" key: %d  (rule: %d)\n", tree->key, sib2(tree)->cap);
      break;
    }
    default:
      printf("\n");
      break;
  }
  if (sibs >= 1) {
    printtree(sib1(tree), ident + 2);
    if (sibs >= 2)
      printtree(sib2(tree), ident + 2);
  }
}


void printktable (lua_State *L, int idx) {
  int n, i;
  lua_getuservalue(L, idx);
  if (lua_isnil(L, -1))  /* no ktable? */
    return;
  n = lua_rawlen(L, -1);
  printf("[");
  for (i = 1; i <= n; i++) {
    printf("%d = ", i);
    lua_rawgeti(L, -1, i);
    if (lua_isstring(L, -1))
      printf("%s  ", lua_tostring(L, -1));
    else
      printf("%s  ", lua_typename(L, lua_type(L, -1)));
    lua_pop(L, 1);
  }
  printf("]\n");
  /* leave ktable at the stack */
}

/* }====================================================== */

#endif
