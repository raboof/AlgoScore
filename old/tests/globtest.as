o0 = score.new_obj_by_name("code");
o0.set_prop("start", 0.4265873015873018);
o0.set_prop("ypos", 90);
o0.set_prop("eval_once", 1);
o0.set_prop("text", 'me.set_global("foo", 123);
');
o0.set_prop("font_size", 10);
o0.query_inlets();
o1 = score.new_obj_by_name("code");
o1.set_prop("start", 3.849206349206349);
o1.set_prop("ypos", 285);
o1.set_prop("eval_once", 1);
o1.set_prop("text", 'print(me.get_label(),": ",me.get_global("foo"),"\n");');
o1.set_prop("font_size", 10);
o1.query_inlets();
