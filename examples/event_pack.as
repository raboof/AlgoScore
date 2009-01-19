o5 = score.new_obj_by_name("timegrid");
o5.set_prop("beats per minute", 120);
o5.set_prop("timegrid in score", 0);
o5.set_prop("height", 20);
o5.set_prop("length", 6.03253);
o5.set_prop("caption_enable", 1);
o5.set_prop("delay_update", 0);
o5.set_prop("timegrid pattern", 4);
o5.set_prop("start", 11.1506);
o5.set_prop("rate (s)", 0.5);
o5.set_prop("timegrid direction", 0);
o5.set_prop("ypos", 15);
o5.set_prop("divisor", 4);
o5.query_inlets();
o4 = score.new_obj_by_name("comment");
o4.set_prop("marker in score", 0);
o4.set_prop("caption_enable", 1);
o4.set_prop("delay_update", 0);
o4.set_prop("text", 'A funcbus is used to pack an event from multiple incoming sources,
triggered by the "event" inlet.
One of the sources is another event packer that merges a
timegrid and an envelope to create events.');
o4.set_prop("start", 0);
o4.set_prop("marker direction", 0);
o4.set_prop("ypos", -30);
o4.set_prop("font_size", 10);
o2 = score.new_obj_by_name("linseg");
o2.set_prop("aux_inputs", [  ]);
o2.set_prop("proportional", 1);
o2.set_prop("transfer func", 'math.sin(x*3.1415/2)');
o2.set_prop("filled", 0);
o2.set_prop("height", 50);
o2.set_prop("length", 18.1789);
o2.set_prop("base line", 0);
o2.set_prop("caption_enable", 1);
o2.set_prop("min value", 0);
o2.set_prop("delay_update", 0);
o2.set_prop("linewidth", 1);
o2.set_prop("labels", 1);
o2.set_prop("invert plot", 0);
o2.set_prop("start", 0);
o2.set_prop("ypos", 135);
o2.set_prop("max value", 1);
o2.set_prop("shape data", [ 0, 2, 1, 2, 0 ]);
o1 = score.new_obj_by_name("jitter");
o1.set_prop("end value", 0);
o1.set_prop("aux_inputs", [  ]);
o1.set_prop("transfer func", '');
o1.set_prop("filled", 0);
o1.set_prop("height", 50);
o1.set_prop("out.interpolate", 1);
o1.set_prop("length", 9.7245);
o1.set_prop("base line", 0);
o1.set_prop("caption_enable", 1);
o1.set_prop("max duration", 1);
o1.set_prop("min value", 0);
o1.set_prop("delay_update", 0);
o1.set_prop("linewidth", 1);
o1.set_prop("time_randomizer", 'math.rand()*(max-min)+min');
o1.set_prop("labels", 0);
o1.set_prop("invert plot", 0);
o1.set_prop("start", 0);
o1.set_prop("seed", 1.22652e+09);
o1.set_prop("max value", 1);
o1.set_prop("value_randomizer", 'math.rand()*(max-min)+min');
o1.set_prop("ypos", 225);
o1.set_prop("start value", 0);
o1.set_prop("min duration", 0.1);
o1.query_inlets();
o3 = score.new_obj_by_name("linseg");
o3.set_prop("aux_inputs", [  ]);
o3.set_prop("proportional", 1);
o3.set_prop("transfer func", '');
o3.set_prop("filled", 0);
o3.set_prop("height", 50);
o3.set_prop("length", 6);
o3.set_prop("base line", 0);
o3.set_prop("caption_enable", 1);
o3.set_prop("min value", 0);
o3.set_prop("delay_update", 0);
o3.set_prop("linewidth", 1);
o3.set_prop("labels", 1);
o3.set_prop("invert plot", 0);
o3.set_prop("start", 11.1506);
o3.set_prop("ypos", -60);
o3.set_prop("max value", 1);
o3.set_prop("shape data", [ 0, 1, 1, 1, 0 ]);
o6 = score.new_obj_by_name("funcbus");
o6.set_prop("alt_score_text", '');
o6.set_prop("length", 5.95878);
o6.set_prop("outlets", [ 'out' ]);
o6.set_prop("caption_enable", 1);
o6.set_prop("font_size", 10);
o6.set_prop("delay_update", 0);
o6.set_prop("text", 'in.A(t)');
o6.set_prop("start", 11.1506);
o6.set_prop("ypos", 255);
o6.set_prop("aux_inputs", [ 'A', 'B', 'C' ]);
o6.query_inlets();
c = o6.connect(o3,"out","A",3.724492014118077);
c.set_prop("transfer func", '');
c.set_prop("hide_inlet", 0);
c = o6.connect(o5,"out","event",1.972874482725912);
c.set_prop("transfer func", '');
c.set_prop("hide_inlet", 0);
o0 = score.new_obj_by_name("linseg");
o0.set_prop("aux_inputs", [  ]);
o0.set_prop("proportional", 1);
o0.set_prop("transfer func", '');
o0.set_prop("filled", 0);
o0.set_prop("height", 50);
o0.set_prop("length", 18.1789);
o0.set_prop("base line", 0);
o0.set_prop("caption_enable", 1);
o0.set_prop("min value", 0);
o0.set_prop("delay_update", 0);
o0.set_prop("linewidth", 1);
o0.set_prop("labels", 1);
o0.set_prop("invert plot", 0);
o0.set_prop("start", 0);
o0.set_prop("ypos", 60);
o0.set_prop("max value", 1);
o0.set_prop("shape data", [ 1, 1, 0 ]);
o7 = score.new_obj_by_name("funcbus");
o7.set_prop("alt_score_text", '');
o7.set_prop("length", 18.2982);
o7.set_prop("outlets", [ 'out' ]);
o7.set_prop("caption_enable", 1);
o7.set_prop("font_size", 10);
o7.set_prop("delay_update", 0);
o7.set_prop("text", '[ev,in.A(t),in.B(t)]');
o7.set_prop("start", 0);
o7.set_prop("ypos", 300);
o7.set_prop("aux_inputs", [ 'A', 'B', 'C' ]);
o7.query_inlets();
c = o7.connect(o2,"out","A",10.34045725646124);
c.set_prop("transfer func", '');
c.set_prop("hide_inlet", 0);
c = o7.connect(o0,"out","B",10.91533836978131);
c.set_prop("transfer func", '');
c.set_prop("hide_inlet", 0);
c = o7.connect(o1,"out","event",6.262425447316105);
c.set_prop("transfer func", '');
c.set_prop("hide_inlet", 0);
c = o7.connect(o6,"out","event",14.41045228628231);
c.set_prop("transfer func", '');
c.set_prop("hide_inlet", 0);
o8 = score.new_obj_by_name("evgraph");
o8.set_prop("height", 100);
o8.set_prop("length", 18.2982);
o8.set_prop("caption_enable", 1);
o8.set_prop("y2_parm", nil);
o8.set_prop("delay_update", 0);
o8.set_prop("size_parm", 1);
o8.set_prop("start", 0);
o8.set_prop("ypos", 360);
o8.set_prop("grid", 12);
o8.set_prop("dur_parm", 2);
o8.set_prop("black_parm", nil);
o8.set_prop("size_scale", 10);
o8.set_prop("y_parm", 0);
o8.query_inlets();
c = o8.connect(o7,"out","events",9.145283499005965);
c.set_prop("transfer func", '');
c.set_prop("hide_inlet", 0);
o0.add_link(o7,0);
o3.add_link(o5,0);
o1.add_link(o7,0);
o2.add_link(o7,0);
o6.add_link(o5,0);
score.marks = [ { type : 'end', time : 18.5487 } ];
score.metadata = { composer : '', subtitle : '', title : '' };
