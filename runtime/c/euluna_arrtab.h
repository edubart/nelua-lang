/* {% if context.has_arrtab then %} */
#ifndef EULUNA_ARRTAB_H
#define EULUNA_ARRTAB_H

#ifndef EULUNA_COMPILER
#include "euluna_core.h"
#endif

/* {%
local iters = require 'euluna.utils.iterators'
for tyname,ctype in iters.opairs(context.arraytypes) do
%} */

typedef struct euluna_arrtab_{%=tyname%}_t {
  {%=ctype%}* data;
  size_t len, cap;
} euluna_arrtab_{%=tyname%}_t;

void euluna_arrtab_{%=tyname%}_reserve(euluna_arrtab_{%=tyname%}_t* t, size_t cap);
void euluna_arrtab_{%=tyname%}_resize_zero(euluna_arrtab_{%=tyname%}_t* t, size_t n);
void euluna_arrtab_{%=tyname%}_resize(euluna_arrtab_{%=tyname%}_t* t, size_t n, {%=ctype%} v);
void euluna_arrtab_{%=tyname%}_push(euluna_arrtab_{%=tyname%}_t* t, {%=ctype%} v);

static inline {%=ctype%} euluna_arrtab_{%=tyname%}_pop(euluna_arrtab_{%=tyname%}_t* t);
static inline {%=ctype%}* euluna_arrtab_{%=tyname%}_get(euluna_arrtab_{%=tyname%}_t* t, size_t i);
static inline {%=ctype%}* euluna_arrtab_{%=tyname%}_at(euluna_arrtab_{%=tyname%}_t* t, size_t i);
static inline size_t euluna_arrtab_{%=tyname%}_length(euluna_arrtab_{%=tyname%}_t* t) { return t-> len; }

/* {% end %} */

#endif
/* {% end %} */
