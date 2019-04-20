int main(int argc, char **argv) {
  EULUNA_UNUSED(argv);
{% if context.has_gc then %}
  euluna_gc_start(&euluna_gc, &argc);
	int (*volatile inner_main)(void) = euluna_main;
  int result = inner_main();
  euluna_gc_stop(&euluna_gc);
  return result;
{% else %}
  EULUNA_UNUSED(argc);
  return euluna_main();
{% end %}
}
