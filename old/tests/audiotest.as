o1 = score.new_obj_by_name("datagen");
o1.set_prop("start", 0.6845238095238075);
o1.set_prop("ypos", 345);
o1.set_prop("length", 5);
o1.set_prop("alt_score_text", '');
o1.set_prop("text", 'out.audiobuf="/Users/lijon/Kymatica/Audio/2007-10/lofi-bowls.wav"');
o1.set_prop("font_size", 10);
o1.query_inlets();
o2 = score.new_obj_by_name("audiobus");
o2.set_prop("amp", 1);
o2.set_prop("port_id", 'audio_2');
o2.set_prop("channels", 2);
o2.set_prop("ypos", 435);
o2.set_prop("export_enable", 1);
o2.set_prop("export_file", '');
o2.query_inlets();
c = o2.connect(o1,"out","in",3.204365079365079);
c.set_prop("transfer func", '');
o0 = score.new_obj_by_name("comment");
o0.set_prop("marker in score", 1);
o0.set_prop("start", 2.37103174603175);
o0.set_prop("ypos", 150);
o0.set_prop("text", 'this starts here (too soon!)');
o0.set_prop("font_size", 10);
o0.query_inlets();
o3 = score.new_obj_by_name("datagen");
o3.set_prop("start", 4.027777777777777);
o3.set_prop("ypos", 180);
o3.set_prop("length", 5);
o3.set_prop("alt_score_text", '');
o3.set_prop("text", 'out.audiobuf="/Users/lijon/Kymatica/Audio/2007-11/buchla_springverb_fix.wav"');
o3.set_prop("font_size", 10);
o3.query_inlets();
o4 = score.new_obj_by_name("audiobus");
o4.set_prop("amp", 1);
o4.set_prop("port_id", 'audio_0');
o4.set_prop("channels", 2);
o4.set_prop("ypos", 225);
o4.set_prop("export_enable", 1);
o4.set_prop("export_file", '');
o4.query_inlets();
c = o4.connect(o3,"out","in",6.200396825396825);
c.set_prop("transfer func", '');