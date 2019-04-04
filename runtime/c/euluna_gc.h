/* {% if context.has_gc then %} */

#ifndef EULUNA_GC_H
#define EULUNA_GC_H

#ifndef EULUNA_COMPILER
#include "euluna_core.h"
#endif

enum {
  EULUNA_GC_MARK = 0x01,
  EULUNA_GC_ROOT = 0x02,
  EULUNA_GC_LEAF = 0x04
};

typedef struct euluna_gc_ptr_t {
  void *ptr;
  int flags;
  size_t size, hash;
  void (*dtor)(void*);
} euluna_gc_ptr_t;

typedef struct euluna_gc_t {
  void *bottom;
  int paused;
  uintptr_t minptr, maxptr;
  euluna_gc_ptr_t *items, *frees;
  double loadfactor, sweepfactor;
  size_t nitems, nslots, mitems, nfrees;
} euluna_gc_t;

void euluna_gc_start(euluna_gc_t *gc, void *stk);
void euluna_gc_stop(euluna_gc_t *gc);
void euluna_gc_pause(euluna_gc_t *gc);
void euluna_gc_resume(euluna_gc_t *gc);
void euluna_gc_run(euluna_gc_t *gc);

void *euluna_gc_alloc(euluna_gc_t *gc, size_t size);
void *euluna_gc_calloc(euluna_gc_t *gc, size_t num, size_t size);
void *euluna_gc_realloc(euluna_gc_t *gc, void *ptr, size_t size);
void euluna_gc_free(euluna_gc_t *gc, void *ptr);

void *euluna_gc_alloc_opt(euluna_gc_t *gc, size_t size, int flags, void(*dtor)(void*));
void *euluna_gc_calloc_opt(euluna_gc_t *gc, size_t num, size_t size, int flags, void(*dtor)(void*));

void euluna_gc_set_dtor(euluna_gc_t *gc, void *ptr, void(*dtor)(void*));
void euluna_gc_set_flags(euluna_gc_t *gc, void *ptr, int flags);
int euluna_gc_get_flags(euluna_gc_t *gc, void *ptr);
void(*euluna_gc_get_dtor(euluna_gc_t *gc, void *ptr))(void*);
size_t euluna_gc_get_size(euluna_gc_t *gc, void *ptr);

extern euluna_gc_t euluna_gc;

#endif

/* {% end %} */
