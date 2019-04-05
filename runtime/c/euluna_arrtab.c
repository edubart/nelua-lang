/* {% if context.has_arrtab then %} */
#ifndef EULUNA_COMPILER
#include "euluna_arrtab.h"
#include "euluna_gc.h"
#endif

/* {%
local iters = require 'euluna.utils.iterators'
for tyname,ctype in iters.opairs(context.arraytypes) do
%} */

void _euluna_arrtab_{%=tyname%}_reserve(euluna_arrtab_{%=tyname%}_t* t, size_t cap) {
  {%=ctype%}* data = ({%=ctype%}*)euluna_gc_realloc(&euluna_gc, t->data, (cap+1) * sizeof({%=ctype%}));
  if(EULUNA_UNLIKELY(data == NULL))
    euluna_panic("_euluna_arrtab_{%=tyname%}_reserve: not enough memory");
  if(EULUNA_UNLIKELY(t->cap == 0))
    data[0] = ({%=ctype%}){0};
  t->data = data;
  t->cap = cap;
}

void _euluna_arrtab_{%=tyname%}_grow(euluna_arrtab_{%=tyname%}_t* t) {
  size_t cap = (t->cap == 0) ? 1 : t->cap << 1;
  _euluna_arrtab_{%=tyname%}_reserve(t, cap);
}

void euluna_arrtab_{%=tyname%}_reserve(euluna_arrtab_{%=tyname%}_t* t, size_t cap) {
  if(EULUNA_UNLIKELY(t->cap >= cap))
    return;
  _euluna_arrtab_{%=tyname%}_reserve(t, cap);
}

void euluna_arrtab_{%=tyname%}_resize_zero(euluna_arrtab_{%=tyname%}_t* t, size_t n) {
  size_t addn = n - t->len;
  if(addn > 0) {
    _euluna_arrtab_{%=tyname%}_reserve(t, n);
    memset(&t->data[t->len+1], 0, addn);
    t->len = n;
  }
}

void euluna_arrtab_{%=tyname%}_resize(euluna_arrtab_{%=tyname%}_t* t, size_t n, {%=ctype%} v) {
  size_t addn = n - t->len;
  if(addn > 0) {
    _euluna_arrtab_{%=tyname%}_reserve(t, n);
    for(size_t i = t->len+1; i < n; ++i) {
      t->data[i] = v;
    }
    t->len = n;
  }
}

void euluna_arrtab_{%=tyname%}_push(euluna_arrtab_{%=tyname%}_t* t, {%=ctype%} v) {
  ++t->len;
  if(EULUNA_UNLIKELY(t->len > t->cap))
    _euluna_arrtab_{%=tyname%}_grow(t);
  t->data[t->len] = v;
}

{%=ctype%} euluna_arrtab_{%=tyname%}_pop(euluna_arrtab_{%=tyname%}_t* t) {
  if(EULUNA_UNLIKELY(t->len == 0))
    euluna_panic("euluna_arrtab_{%=tyname%}_pop: length is 0");
  return t->data[t->len--];
}

{%=ctype%}* euluna_arrtab_{%=tyname%}_at(euluna_arrtab_{%=tyname%}_t* t, size_t i) {
  if(EULUNA_UNLIKELY(i > t->len)) {
    if(EULUNA_UNLIKELY(i != t->len + 1))
      euluna_panic("euluna_arrtab_{%=tyname%}_set: index out of range");
    t->len++;
    if(EULUNA_UNLIKELY(t->len > t->cap))
      _euluna_arrtab_{%=tyname%}_grow(t);
  } else if(EULUNA_UNLIKELY(i == 0 && t->cap == 0)) {
    _euluna_arrtab_{%=tyname%}_grow(t);
  }
  return &t->data[i];
}

{%=ctype%}* euluna_arrtab_{%=tyname%}_get(euluna_arrtab_{%=tyname%}_t* t, size_t i) {
  if(EULUNA_UNLIKELY(i > t->len)) {
    printf("%lu %lu", i, t->len);
    euluna_panic("euluna_arrtab_{%=tyname%}_get: index out of range");
  }
  else if(EULUNA_UNLIKELY(i == 0 && t->cap == 0)) {
    _euluna_arrtab_{%=tyname%}_grow(t);
  }
  return &t->data[i];
}

// TODO: insert and remove

/* {% end %} */

/* {% end %} */
