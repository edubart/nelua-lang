#ifndef EULUNA_COMPILER
#include "euluna_arrtab.h"
#include "euluna_gc.h"
#endif

void _{%=tyname%}_reserve({%=tyname%}* t, size_t cap) {
  {%=ctype%}* data = ({%=ctype%}*)euluna_gc_realloc(&euluna_gc, t->data, (cap+1) * sizeof({%=ctype%}));
  if(EULUNA_UNLIKELY(data == NULL))
    euluna_panic("_{%=tyname%}_reserve: not enough memory");
  if(EULUNA_UNLIKELY(t->cap == 0))
    data[0] = ({%=ctype%}){0};
  t->data = data;
  t->cap = cap;
}

void _{%=tyname%}_grow({%=tyname%}* t) {
  size_t cap = (t->cap == 0) ? 1 : t->cap << 1;
  _{%=tyname%}_reserve(t, cap);
}

void {%=tyname%}_reserve({%=tyname%}* t, size_t cap) {
  if(EULUNA_UNLIKELY(t->cap >= cap))
    return;
  _{%=tyname%}_reserve(t, cap);
}

void {%=tyname%}_resize_zero({%=tyname%}* t, size_t n) {
  size_t addn = n - t->len;
  if(addn > 0) {
    _{%=tyname%}_reserve(t, n);
    memset(&t->data[t->len+1], 0, addn);
    t->len = n;
  }
}

void {%=tyname%}_resize({%=tyname%}* t, size_t n, {%=ctype%} v) {
  size_t addn = n - t->len;
  if(addn > 0) {
    _{%=tyname%}_reserve(t, n);
    for(size_t i = t->len+1; i < n; ++i) {
      t->data[i] = v;
    }
    t->len = n;
  }
}

void {%=tyname%}_push({%=tyname%}* t, {%=ctype%} v) {
  ++t->len;
  if(EULUNA_UNLIKELY(t->len > t->cap))
    _{%=tyname%}_grow(t);
  t->data[t->len] = v;
}

{%=ctype%} {%=tyname%}_pop({%=tyname%}* t) {
  if(EULUNA_UNLIKELY(t->len == 0))
    euluna_panic("{%=tyname%}_pop: length is 0");
  return t->data[t->len--];
}

{%=ctype%}* {%=tyname%}_at({%=tyname%}* t, size_t i) {
  if(EULUNA_UNLIKELY(i > t->len)) {
    if(EULUNA_UNLIKELY(i != t->len + 1))
      euluna_panic("{%=tyname%}_set: index out of range");
    t->len++;
    if(EULUNA_UNLIKELY(t->len > t->cap))
      _{%=tyname%}_grow(t);
  } else if(EULUNA_UNLIKELY(i == 0 && t->cap == 0)) {
    _{%=tyname%}_grow(t);
  }
  return &t->data[i];
}

{%=ctype%}* {%=tyname%}_get({%=tyname%}* t, size_t i) {
  if(EULUNA_UNLIKELY(i > t->len)) {
    euluna_panic("{%=tyname%}_get: index out of range");
  }
  else if(EULUNA_UNLIKELY(i == 0 && t->cap == 0)) {
    _{%=tyname%}_grow(t);
  }
  return &t->data[i];
}

// TODO: insert and remove
