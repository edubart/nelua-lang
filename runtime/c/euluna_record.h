typedef struct {
{% for i,field in ipairs(fields) do %}
  {%=field.ctype%} {%=field.name%};
{% end %}
} {%=tyname%};

