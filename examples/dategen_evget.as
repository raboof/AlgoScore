o1 = score.new_obj_by_name("datagen");
o1.set_prop("alt_score_text", 'Some events');
o1.set_prop("length", 15.825);
o1.set_prop("caption_enable", 1);
o1.set_prop("font_size", 10);
o1.set_prop("delay_update", 0);
o1.set_prop("text", 'out.data = [
  [0,[0,5]],
  [5,[1,5]],
  [10,[2,5]],
];');
o1.set_prop("start", 0);
o1.set_prop("ypos", 75);
o1.set_prop("aux_inputs", [ 'A', 'B', 'C' ]);
o1.query_inlets();
o4 = score.new_obj_by_name("evgraph");
o4.set_prop("height", 50);
o4.set_prop("length", 15.825);
o4.set_prop("caption_enable", 1);
o4.set_prop("y2_parm", nil);
o4.set_prop("delay_update", 0);
o4.set_prop("size_parm", nil);
o4.set_prop("start", 0);
o4.set_prop("ypos", 135);
o4.set_prop("grid", 12);
o4.set_prop("dur_parm", 1);
o4.set_prop("black_parm", nil);
o4.set_prop("size_scale", 10);
o4.set_prop("y_parm", 0);
o4.query_inlets();
c = o4.connect(o1,"out","events",0.805168986083499);
c.set_prop("transfer func", '');
c.set_prop("hide_inlet", 0);
o2 = score.new_obj_by_name("datagen");
o2.set_prop("alt_score_text", '');
o2.set_prop("length", 15.825);
o2.set_prop("caption_enable", 1);
o2.set_prop("font_size", 10);
o2.set_prop("delay_update", 0);
o2.set_prop("text", 'cons = inlets.A.get_connections();
foreach(c;cons) {
  for(i=0;i<c.datasize;i+=1) {
    ev = c.get_event(i);
    append(out.data,[ev[0]*0.3,ev[1]]);
  }
}');
o2.set_prop("start", 0);
o2.set_prop("ypos", 210);
o2.set_prop("aux_inputs", [ 'A', 'B', 'C' ]);
o2.query_inlets();
c = o2.connect(o1,"out","A",4.502982107355865);
c.set_prop("transfer func", '');
c.set_prop("hide_inlet", 0);
o3 = score.new_obj_by_name("evgraph");
o3.set_prop("height", 50);
o3.set_prop("length", 15.825);
o3.set_prop("caption_enable", 1);
o3.set_prop("y2_parm", nil);
o3.set_prop("delay_update", 0);
o3.set_prop("size_parm", nil);
o3.set_prop("start", 0);
o3.set_prop("ypos", 345);
o3.set_prop("grid", 12);
o3.set_prop("dur_parm", 1);
o3.set_prop("black_parm", nil);
o3.set_prop("size_scale", 10);
o3.set_prop("y_parm", 0);
o3.query_inlets();
c = o3.connect(o2,"out","events",9.840954274353876);
c.set_prop("transfer func", '');
c.set_prop("hide_inlet", 0);
o0 = score.new_obj_by_name("comment");
o0.set_prop("marker in score", 0);
o0.set_prop("caption_enable", 1);
o0.set_prop("delay_update", 0);
o0.set_prop("text", 'A datagen object is used to copy a set of events, compressing
their onset time.');
o0.set_prop("start", 0);
o0.set_prop("marker direction", 0);
o0.set_prop("ypos", 30);
o0.set_prop("font_size", 10);
score.marks = [ { type : 'end', time : 16.163 } ];
score.metadata = { composer : '', subtitle : '', title : '' };
