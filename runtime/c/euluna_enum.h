typedef {%=subctype%} {%=tyname%};
enum {
{% for i,field in ipairs(fields) do %}
  {%=field.codename%} = {%=field.value%},
{% end %}
};
