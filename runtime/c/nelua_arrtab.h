typedef struct {%=tyname%} {
  {%=ctype%}* data;
  size_t len, cap;
} {%=tyname%};
void {%=tyname%}_reserve({%=tyname%}* t, size_t cap);
void {%=tyname%}_resize_zero({%=tyname%}* t, size_t n);
void {%=tyname%}_resize({%=tyname%}* t, size_t n, {%=ctype%} v);
void {%=tyname%}_init({%=tyname%}* t, {%=ctype%}* a, size_t n);
void {%=tyname%}_push({%=tyname%}* t, {%=ctype%} v);
static inline {%=tyname%} {%=tyname%}_create({%=ctype%}* a, size_t n) {
  {%=tyname%} r = {0};
  {%=tyname%}_init(&r, a, n);
  return r;
}
static inline {%=ctype%} {%=tyname%}_pop({%=tyname%}* t);
static inline {%=ctype%}* {%=tyname%}_get({%=tyname%}* t, size_t i);
static inline {%=ctype%}* {%=tyname%}_at({%=tyname%}* t, size_t i);
static inline size_t {%=tyname%}_length({%=tyname%}* t) { return t-> len; }
