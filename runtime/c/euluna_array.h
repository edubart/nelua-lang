typedef struct {
  {%=subctype%} data[{%=length%}];
} {% if type.aligned then %} __attribute__((aligned({%=type.aligned%}))){% end %} {%=tyname%};
