{% context:ensure_runtime_builtin('nelua_panic_cstring') %}
{% context:ensure_runtime_builtin('nelua_unlikely') %}
{% context:add_include('<string.h>') %}
void _{%=tyname%}_reserve({%=tyname%}* t, size_t cap) {
  {%=ctype%}* data = ({%=ctype%}*)nelua_gc_realloc(&nelua_gc, t->data, (cap+1) * sizeof({%=ctype%}));
  if(nelua_unlikely(data == NULL))
    nelua_panic_cstring("_{%=tyname%}_reserve: not enough memory");
  if(nelua_unlikely(t->cap == 0))
    data[0] = ({%=ctype%}){0};
  t->data = data;
  t->cap = cap;
}
void _{%=tyname%}_grow({%=tyname%}* t) {
  size_t cap = (t->cap == 0) ? 1 : t->cap << 1;
  _{%=tyname%}_reserve(t, cap);
}
void {%=tyname%}_reserve({%=tyname%}* t, size_t cap) {
  if(nelua_unlikely(t->cap >= cap))
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
void {%=tyname%}_init({%=tyname%}* t, {%=ctype%}* a, size_t n) {
  _{%=tyname%}_reserve(t, n);
  for(size_t i = 0; i < n; ++i)
    t->data[i+1] = a[i];
  t->len = n;
}
void {%=tyname%}_push({%=tyname%}* t, {%=ctype%} v) {
  ++t->len;
  if(nelua_unlikely(t->len > t->cap))
    _{%=tyname%}_grow(t);
  t->data[t->len] = v;
}
{%=ctype%} {%=tyname%}_pop({%=tyname%}* t) {
  if(nelua_unlikely(t->len == 0))
    nelua_panic_cstring("{%=tyname%}_pop: length is 0");
  return t->data[t->len--];
}
{%=ctype%}* {%=tyname%}_at({%=tyname%}* t, size_t i) {
  if(nelua_unlikely(i > t->len)) {
    if(nelua_unlikely(i != t->len + 1))
      nelua_panic_cstring("{%=tyname%}_set: index out of range");
    t->len++;
    if(nelua_unlikely(t->len > t->cap))
      _{%=tyname%}_grow(t);
  } else if(nelua_unlikely(i == 0 && t->cap == 0)) {
    _{%=tyname%}_grow(t);
  }
  return &t->data[i];
}
{%=ctype%}* {%=tyname%}_get({%=tyname%}* t, size_t i) {
  if(nelua_unlikely(i > t->len)) {
    nelua_panic_cstring("{%=tyname%}_get: index out of range");
  }
  else if(nelua_unlikely(i == 0 && t->cap == 0)) {
    _{%=tyname%}_grow(t);
  }
  return &t->data[i];
}
