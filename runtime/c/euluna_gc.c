#ifndef EULUNA_COMPILER
#include "euluna_gc.h"
#endif

#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <setjmp.h>

euluna_gc_t euluna_gc;

static size_t euluna_gc_hash(void *ptr) {
  return ((uintptr_t)ptr) >> 3;
}

static size_t euluna_gc_probe(euluna_gc_t* gc, size_t i, size_t h) {
  long v = i - (h-1);
  if (v < 0) { v = gc->nslots + v; }
  return v;
}

static euluna_gc_ptr_t *euluna_gc_get_ptr(euluna_gc_t *gc, void *ptr) {
  size_t i, j, h;
  i = euluna_gc_hash(ptr) % gc->nslots; j = 0;
  while (1) {
    h = gc->items[i].hash;
    if (h == 0 || j > euluna_gc_probe(gc, i, h)) { return NULL; }
    if (gc->items[i].ptr == ptr) { return &gc->items[i]; }
    i = (i+1) % gc->nslots; j++;
  }
  return NULL;
}

static void euluna_gc_add_ptr(
  euluna_gc_t *gc, void *ptr, size_t size,
  int flags, void(*dtor)(void*)) {

  euluna_gc_ptr_t item, tmp;
  size_t h, p, i, j;

  i = euluna_gc_hash(ptr) % gc->nslots; j = 0;

  item.ptr = ptr;
  item.flags = flags;
  item.size = size;
  item.hash = i+1;
  item.dtor = dtor;

  while (1) {
    h = gc->items[i].hash;
    if (h == 0) { gc->items[i] = item; return; }
    if (gc->items[i].ptr == item.ptr) { return; }
    p = euluna_gc_probe(gc, i, h);
    if (j >= p) {
      tmp = gc->items[i];
      gc->items[i] = item;
      item = tmp;
      j = p;
    }
    i = (i+1) % gc->nslots; j++;
  }

}

static void euluna_gc_rem_ptr(euluna_gc_t *gc, void *ptr) {
  size_t i, j, h, nj, nh;

  if (gc->nitems == 0) { return; }

  for (i = 0; i < gc->nfrees; i++) {
    if (gc->frees[i].ptr == ptr) { gc->frees[i].ptr = NULL; }
  }

  i = euluna_gc_hash(ptr) % gc->nslots; j = 0;

  while (1) {
    h = gc->items[i].hash;
    if (h == 0 || j > euluna_gc_probe(gc, i, h)) { return; }
    if (gc->items[i].ptr == ptr) {
      memset(&gc->items[i], 0, sizeof(euluna_gc_ptr_t));
      j = i;
      while (1) {
        nj = (j+1) % gc->nslots;
        nh = gc->items[nj].hash;
        if (nh != 0 && euluna_gc_probe(gc, nj, nh) > 0) {
          memcpy(&gc->items[ j], &gc->items[nj], sizeof(euluna_gc_ptr_t));
          memset(&gc->items[nj],              0, sizeof(euluna_gc_ptr_t));
          j = nj;
        } else {
          break;
        }
      }
      gc->nitems--;
      return;
    }
    i = (i+1) % gc->nslots; j++;
  }

}


enum {
  EULUNA_GC_PRIMES_COUNT = 24
};

static const size_t euluna_gc_primes[EULUNA_GC_PRIMES_COUNT] = {
  0,       1,       5,       11,
  23,      53,      101,     197,
  389,     683,     1259,    2417,
  4733,    9371,    18617,   37097,
  74093,   148073,  296099,  592019,
  1100009, 2200013, 4400021, 8800019
};

static size_t euluna_gc_ideal_size(euluna_gc_t* gc, size_t size) {
  size_t i, last;
  size = (size_t)((double)(size+1) / gc->loadfactor);
  for (i = 0; i < EULUNA_GC_PRIMES_COUNT; i++) {
    if (euluna_gc_primes[i] >= size) { return euluna_gc_primes[i]; }
  }
  last = euluna_gc_primes[EULUNA_GC_PRIMES_COUNT-1];
  for (i = 0;; i++) {
    if (last * i >= size) { return last * i; }
  }
  return 0;
}

static int euluna_gc_rehash(euluna_gc_t* gc, size_t new_size) {
  size_t i;
  euluna_gc_ptr_t *old_items = gc->items;
  size_t old_size = gc->nslots;

  gc->nslots = new_size;
  gc->items = calloc(gc->nslots, sizeof(euluna_gc_ptr_t));

  if (gc->items == NULL) {
    gc->nslots = old_size;
    gc->items = old_items;
    return 0;
  }

  for (i = 0; i < old_size; i++) {
    if (old_items[i].hash != 0) {
      euluna_gc_add_ptr(gc,
        old_items[i].ptr,   old_items[i].size,
        old_items[i].flags, old_items[i].dtor);
    }
  }

  free(old_items);

  return 1;
}

static int euluna_gc_resize_more(euluna_gc_t *gc) {
  size_t new_size = euluna_gc_ideal_size(gc, gc->nitems);
  size_t old_size = gc->nslots;
  return (new_size > old_size) ? euluna_gc_rehash(gc, new_size) : 1;
}

static int euluna_gc_resize_less(euluna_gc_t *gc) {
  size_t new_size = euluna_gc_ideal_size(gc, gc->nitems);
  size_t old_size = gc->nslots;
  return (new_size < old_size) ? euluna_gc_rehash(gc, new_size) : 1;
}

static void euluna_gc_mark_ptr(euluna_gc_t *gc, void *ptr) {
  size_t i, j, h, k;

  if ((uintptr_t)ptr < gc->minptr
  ||  (uintptr_t)ptr > gc->maxptr) { return; }

  i = euluna_gc_hash(ptr) % gc->nslots; j = 0;

  while (1) {
    h = gc->items[i].hash;
    if (h == 0 || j > euluna_gc_probe(gc, i, h)) { return; }
    if (ptr == gc->items[i].ptr) {
      if (gc->items[i].flags & EULUNA_GC_MARK) { return; }
      gc->items[i].flags |= EULUNA_GC_MARK;
      if (gc->items[i].flags & EULUNA_GC_LEAF) { return; }
      for (k = 0; k < gc->items[i].size/sizeof(void*); k++) {
        euluna_gc_mark_ptr(gc, ((void**)gc->items[i].ptr)[k]);
      }
      return;
    }
    i = (i+1) % gc->nslots; j++;
  }

}

static void euluna_gc_mark_stack(euluna_gc_t *gc) {
  void *stk, *bot, *top, *p;
  bot = gc->bottom; top = &stk;

  if (bot == top) { return; }

  if (bot < top) {
    for (p = top; p >= bot; p = ((char*)p) - sizeof(void*)) {
      euluna_gc_mark_ptr(gc, *((void**)p));
    }
  }

  if (bot > top) {
    for (p = top; p <= bot; p = ((char*)p) + sizeof(void*)) {
      euluna_gc_mark_ptr(gc, *((void**)p));
    }
  }

}

static void euluna_gc_mark(euluna_gc_t *gc) {
  size_t i, k;
  jmp_buf env;
  void (*volatile mark_stack)(euluna_gc_t*) = euluna_gc_mark_stack;

  if (gc->nitems == 0) { return; }

  for (i = 0; i < gc->nslots; i++) {
    if (gc->items[i].hash ==        0) { continue; }
    if (gc->items[i].flags & EULUNA_GC_MARK) { continue; }
    if (gc->items[i].flags & EULUNA_GC_ROOT) {
      gc->items[i].flags |= EULUNA_GC_MARK;
      if (gc->items[i].flags & EULUNA_GC_LEAF) { continue; }
      for (k = 0; k < gc->items[i].size/sizeof(void*); k++) {
        euluna_gc_mark_ptr(gc, ((void**)gc->items[i].ptr)[k]);
      }
      continue;
    }
  }

  memset(&env, 0, sizeof(jmp_buf));
  setjmp(env);
  mark_stack(gc);

}

void euluna_gc_sweep(euluna_gc_t *gc) {
  size_t i, j, k, nj, nh;

  if (gc->nitems == 0) { return; }

  gc->nfrees = 0;
  for (i = 0; i < gc->nslots; i++) {
    if (gc->items[i].hash ==        0) { continue; }
    if (gc->items[i].flags & EULUNA_GC_MARK) { continue; }
    if (gc->items[i].flags & EULUNA_GC_ROOT) { continue; }
    gc->nfrees++;
  }

  gc->frees = realloc(gc->frees, sizeof(euluna_gc_ptr_t) * gc->nfrees);
  if (gc->frees == NULL) { return; }

  i = 0; k = 0;
  while (i < gc->nslots) {
    if (gc->items[i].hash ==        0) { i++; continue; }
    if (gc->items[i].flags & EULUNA_GC_MARK) { i++; continue; }
    if (gc->items[i].flags & EULUNA_GC_ROOT) { i++; continue; }

    gc->frees[k] = gc->items[i]; k++;
    memset(&gc->items[i], 0, sizeof(euluna_gc_ptr_t));

    j = i;
    while (1) {
      nj = (j+1) % gc->nslots;
      nh = gc->items[nj].hash;
      if (nh != 0 && euluna_gc_probe(gc, nj, nh) > 0) {
        memcpy(&gc->items[ j], &gc->items[nj], sizeof(euluna_gc_ptr_t));
        memset(&gc->items[nj],              0, sizeof(euluna_gc_ptr_t));
        j = nj;
      } else {
        break;
      }
    }
    gc->nitems--;
  }

  for (i = 0; i < gc->nslots; i++) {
    if (gc->items[i].hash == 0) { continue; }
    if (gc->items[i].flags & EULUNA_GC_MARK) {
      gc->items[i].flags &= ~EULUNA_GC_MARK;
    }
  }

  euluna_gc_resize_less(gc);

  gc->mitems = gc->nitems + (size_t)(gc->nitems * gc->sweepfactor) + 1;

  for (i = 0; i < gc->nfrees; i++) {
    if (gc->frees[i].ptr) {
      if (gc->frees[i].dtor) { gc->frees[i].dtor(gc->frees[i].ptr); }
      free(gc->frees[i].ptr);
    }
  }

  free(gc->frees);
  gc->frees = NULL;
  gc->nfrees = 0;

}

void euluna_gc_start(euluna_gc_t *gc, void *stk) {
  gc->bottom = stk;
  gc->paused = 0;
  gc->nitems = 0;
  gc->nslots = 0;
  gc->mitems = 0;
  gc->nfrees = 0;
  gc->maxptr = 0;
  gc->items = NULL;
  gc->frees = NULL;
  gc->minptr = UINTPTR_MAX;
  gc->loadfactor = 0.9;
  gc->sweepfactor = 0.5;
}

void euluna_gc_stop(euluna_gc_t *gc) {
  euluna_gc_sweep(gc);
  free(gc->items);
  free(gc->frees);
}

void euluna_gc_pause(euluna_gc_t *gc) {
  gc->paused = 1;
}

void euluna_gc_resume(euluna_gc_t *gc) {
  gc->paused = 0;
}

void euluna_gc_run(euluna_gc_t *gc) {
  euluna_gc_mark(gc);
  euluna_gc_sweep(gc);
}

static void *euluna_gc_add(
  euluna_gc_t *gc, void *ptr, size_t size,
  int flags, void(*dtor)(void*)) {

  gc->nitems++;
  gc->maxptr = ((uintptr_t)ptr) + size > gc->maxptr ?
    ((uintptr_t)ptr) + size : gc->maxptr;
  gc->minptr = ((uintptr_t)ptr)        < gc->minptr ?
    ((uintptr_t)ptr)        : gc->minptr;

  if (euluna_gc_resize_more(gc)) {
    euluna_gc_add_ptr(gc, ptr, size, flags, dtor);
    if (!gc->paused && gc->nitems > gc->mitems) {
      euluna_gc_run(gc);
    }
    return ptr;
  } else {
    gc->nitems--;
    free(ptr);
    return NULL;
  }
}

static void euluna_gc_rem(euluna_gc_t *gc, void *ptr) {
  euluna_gc_rem_ptr(gc, ptr);
  euluna_gc_resize_less(gc);
  gc->mitems = gc->nitems + gc->nitems / 2 + 1;
}

void *euluna_gc_alloc(euluna_gc_t *gc, size_t size) {
  return euluna_gc_alloc_opt(gc, size, 0, NULL);
}

void *euluna_gc_calloc(euluna_gc_t *gc, size_t num, size_t size) {
  return euluna_gc_calloc_opt(gc, num, size, 0, NULL);
}

void *euluna_gc_realloc(euluna_gc_t *gc, void *ptr, size_t size) {
  euluna_gc_ptr_t *p;
  void *qtr = realloc(ptr, size);

  if (qtr == NULL) {
    euluna_gc_rem(gc, ptr);
    return qtr;
  }

  if (ptr == NULL) {
    euluna_gc_add(gc, qtr, size, 0, NULL);
    return qtr;
  }

  p  = euluna_gc_get_ptr(gc, ptr);

  if (p && qtr == ptr) {
    p->size = size;
    return qtr;
  }

  if (p && qtr != ptr) {
    int flags = p->flags;
    void(*dtor)(void*) = p->dtor;
    euluna_gc_rem(gc, ptr);
    euluna_gc_add(gc, qtr, size, flags, dtor);
    return qtr;
  }

  return NULL;
}

void euluna_gc_free(euluna_gc_t *gc, void *ptr) {
  euluna_gc_ptr_t *p  = euluna_gc_get_ptr(gc, ptr);
  if (p) {
    if (p->dtor) {
      p->dtor(ptr);
    }
    free(ptr);
    euluna_gc_rem(gc, ptr);
  }
}

void *euluna_gc_alloc_opt(euluna_gc_t *gc, size_t size, int flags, void(*dtor)(void*)) {
  void *ptr = malloc(size);
  if (ptr != NULL) {
    ptr = euluna_gc_add(gc, ptr, size, flags, dtor);
  }
  return ptr;
}

void *euluna_gc_calloc_opt(
  euluna_gc_t *gc, size_t num, size_t size,
  int flags, void(*dtor)(void*)) {
  void *ptr = calloc(num, size);
  if (ptr != NULL) {
    ptr = euluna_gc_add(gc, ptr, num * size, flags, dtor);
  }
  return ptr;
}

void euluna_gc_set_dtor(euluna_gc_t *gc, void *ptr, void(*dtor)(void*)) {
  euluna_gc_ptr_t *p  = euluna_gc_get_ptr(gc, ptr);
  if (p) { p->dtor = dtor; }
}

void euluna_gc_set_flags(euluna_gc_t *gc, void *ptr, int flags) {
  euluna_gc_ptr_t *p  = euluna_gc_get_ptr(gc, ptr);
  if (p) { p->flags = flags; }
}

int euluna_gc_get_flags(euluna_gc_t *gc, void *ptr) {
  euluna_gc_ptr_t *p  = euluna_gc_get_ptr(gc, ptr);
  if (p) { return p->flags; }
  return 0;
}

void(*euluna_gc_get_dtor(euluna_gc_t *gc, void *ptr))(void*) {
  euluna_gc_ptr_t *p  = euluna_gc_get_ptr(gc, ptr);
  if (p) { return p->dtor; }
  return NULL;
}

size_t euluna_gc_get_size(euluna_gc_t *gc, void *ptr) {
  euluna_gc_ptr_t *p  = euluna_gc_get_ptr(gc, ptr);
  if (p) { return p->size; }
  return 0;
}
