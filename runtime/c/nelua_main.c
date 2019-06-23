int main(int argc, char **argv) {
  Nelua_UNUSED(argv);
{% if context.has_gc then %}
  nelua_gc_start(&nelua_gc, &argc);
	int (*volatile inner_main)(void) = nelua_main;
  int result = inner_main();
  nelua_gc_stop(&nelua_gc);
  return result;
{% else %}
  Nelua_UNUSED(argc);
  return nelua_main();
{% end %}
}
