{% if next(fields) then %}
typedef struct {%=tyname%} {
{% for i,field in ipairs(fields) do %}
  {%=field.ctype%} {%=field.name%};
{% end %}
} {% if type.aligned then %} __attribute__((aligned({%=type.aligned%}))){% end %} {%=tyname%};
{% else %}
typedef struct {%=tyname%} {%=tyname%};
{% end %}
