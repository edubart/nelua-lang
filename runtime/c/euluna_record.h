{% if next(fields) then %}
typedef struct {%=tyname%} {
{% for i,field in ipairs(fields) do %}
  {%=field.ctype%} {%=field.name%};
{% end %}
} {%=tyname%};
{% else %}
typedef struct {%=tyname%} {%=tyname%};
{% end %}
