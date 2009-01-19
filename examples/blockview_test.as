o0 = score.new_obj_by_name("datagen");
o0.set_prop("alt_score_text", '');
o0.set_prop("length", 5);
o0.set_prop("outlets", [ 'out' ]);
o0.set_prop("caption_enable", 1);
o0.set_prop("font_size", 10);
o0.set_prop("delay_update", 0);
o0.set_prop("text", 'out.data=[
  [0,"A"],
  [1,"B"],
  [4,"C"],
  [4.5,"D"],
];');
o0.set_prop("start", 0.2);
o0.set_prop("ypos", 105);
o0.set_prop("out.interpolate", 0);
o0.set_prop("aux_inputs", [ 'A', 'B', 'C' ]);
o0.query_inlets();
o1 = score.new_obj_by_name("block_view");
o1.set_prop("height", 30);
o1.set_prop("length", 6.03588);
o1.set_prop("caption_enable", 1);
o1.set_prop("delay_update", 0);
o1.set_prop("start", 0.0768352);
o1.set_prop("block_text", 'sprintf("%g:%s",ev[0],ev[1])');
o1.set_prop("ypos", 330);
o1.set_prop("font_size", 8);
o1.query_inlets();
c = o1.connect(o0,"out","events",2.445324155069582);
c.set_prop("transfer func", '');
c.set_prop("hide_inlet", 0);
score.marks = [ { type : 'end', time : 6.44135 } ];
score.metadata = { composer : '', subtitle : '', title : '' };
