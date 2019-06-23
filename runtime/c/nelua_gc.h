enum {
  Nelua_GC_MARK = 0x01,
  Nelua_GC_ROOT = 0x02,
  Nelua_GC_LEAF = 0x04
};

typedef struct nelua_gc_ptr_t {
  void *ptr;
  int flags;
  size_t size, hash;
  void (*dtor)(void*);
} nelua_gc_ptr_t;

typedef struct nelua_gc_t {
  void *bottom;
  int paused;
  uintptr_t minptr, maxptr;
  nelua_gc_ptr_t *items, *frees;
  double loadfactor, sweepfactor;
  size_t nitems, nslots, mitems, nfrees;
} nelua_gc_t;

void nelua_gc_start(nelua_gc_t *gc, void *stk);
void nelua_gc_stop(nelua_gc_t *gc);
void nelua_gc_pause(nelua_gc_t *gc);
void nelua_gc_resume(nelua_gc_t *gc);
void nelua_gc_run(nelua_gc_t *gc);

void *nelua_gc_alloc(nelua_gc_t *gc, size_t size);
void *nelua_gc_calloc(nelua_gc_t *gc, size_t num, size_t size);
void *nelua_gc_realloc(nelua_gc_t *gc, void *ptr, size_t size);
void nelua_gc_free(nelua_gc_t *gc, void *ptr);

void *nelua_gc_alloc_opt(nelua_gc_t *gc, size_t size, int flags, void(*dtor)(void*));
void *nelua_gc_calloc_opt(nelua_gc_t *gc, size_t num, size_t size, int flags, void(*dtor)(void*));

void nelua_gc_set_dtor(nelua_gc_t *gc, void *ptr, void(*dtor)(void*));
void nelua_gc_set_flags(nelua_gc_t *gc, void *ptr, int flags);
int nelua_gc_get_flags(nelua_gc_t *gc, void *ptr);
void(*nelua_gc_get_dtor(nelua_gc_t *gc, void *ptr))(void*);
size_t nelua_gc_get_size(nelua_gc_t *gc, void *ptr);

extern nelua_gc_t nelua_gc;
