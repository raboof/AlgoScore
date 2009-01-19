o3 = score.new_obj_by_name("comment");
o3.set_prop("marker in score", 0);
o3.set_prop("caption_enable", 1);
o3.set_prop("delay_update", 0);
o3.set_prop("text", 'Using connection transfunc to extract single values from event vector.');
o3.set_prop("start", 1.47055);
o3.set_prop("marker direction", 0);
o3.set_prop("ypos", 135);
o3.set_prop("font_size", 12);
o0 = score.new_obj_by_name("datagen");
o0.set_prop("alt_score_text", '');
o0.set_prop("length", 5.04666);
o0.set_prop("caption_enable", 1);
o0.set_prop("font_size", 10);
o0.set_prop("delay_update", 0);
o0.set_prop("text", 'out.data = [
  [0,[1,0.7,1]],
  [2,[3,0.2,1]],
  [4,[2,1,1]],
];');
o0.set_prop("start", 0.151776);
o0.set_prop("ypos", 210);
o0.set_prop("aux_inputs", [ 'A', 'B', 'C' ]);
o0.query_inlets();
o2 = score.new_obj_by_name("evgraph");
o2.set_prop("height", 100);
o2.set_prop("length", 6.02064);
o2.set_prop("caption_enable", 1);
o2.set_prop("delay_update", 0);
o2.set_prop("size_parm", 1);
o2.set_prop("start", 0.151776);
o2.set_prop("ypos", 315);
o2.set_prop("grid", 12);
o2.set_prop("dur_parm", 2);
o2.set_prop("black_parm", nil);
o2.set_prop("size_scale", 10);
o2.set_prop("y_parm", 0);
o2.query_inlets();
c = o2.connect(o0,"out","events",0.9140017436926851);
c.set_prop("transfer func", '');
c.set_prop("hide_inlet", 0);
o1 = score.new_obj_by_name("sine");
o1.set_prop("aux_inputs", [  ]);
o1.set_prop("out.amp", 1);
o1.set_prop("transfer func", '');
o1.set_prop("filled", 0);
o1.set_prop("height", 50);
o1.set_prop("length", 6.02064);
o1.set_prop("base line", 0);
o1.set_prop("caption_enable", 1);
o1.set_prop("out.freq", 2);
o1.set_prop("min value", -1);
o1.set_prop("delay_update", 0);
o1.set_prop("linewidth", 1);
o1.set_prop("labels", 1);
o1.set_prop("invert plot", 0);
o1.set_prop("start", 0.151776);
o1.set_prop("ypos", 450);
o1.set_prop("max value", 1);
o1.set_prop("out.resolution", 0.02);
o1.query_inlets();
c = o1.connect(o0,"out","amp",1.521160044859969);
c.set_prop("transfer func", 'x[1]');
c.set_prop("hide_inlet", 0);
c = o1.connect(o0,"out","freq",1.258976953389009);
c.set_prop("transfer func", 'x[0]');
c.set_prop("hide_inlet", 0);
score.marks = [ { type : 'end', time : 6.56776 } ];
score.metadata = { composer : '', subtitle : '', title : '' };
