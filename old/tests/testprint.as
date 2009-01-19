o1 = score.new_obj_by_name("timegrid");
o1.set_prop("timegrid direction", 0);
o1.set_prop("beats per minute", 120);
o1.set_prop("timegrid in score", 1);
o1.set_prop("height", 20);
o1.set_prop("rate (s)", 0.5);
o1.set_prop("start", 20.47619047619047);
o1.set_prop("ypos", 495);
o1.set_prop("timegrid pattern", 4);
o1.set_prop("length", 5);
o1.set_prop("divisor", 4);
o1.query_inlets();
o2 = score.new_obj_by_name("sine");
o2.set_prop("out.resolution", 0.02);
o2.set_prop("out.amp", 1);
o2.set_prop("filled", 1);
o2.set_prop("height", 200);
o2.set_prop("max value", 1);
o2.set_prop("start", 0.7738095238095265);
o2.set_prop("ypos", 765);
o2.set_prop("linewidth", 1);
o2.set_prop("length", 12.46428571428572);
o2.set_prop("base line", 0);
o2.set_prop("out.freq", 0.5);
o2.set_prop("min value", -1);
o2.query_inlets();
o0 = score.new_obj_by_name("sine");
o0.set_prop("out.resolution", 0.02);
o0.set_prop("out.amp", 1);
o0.set_prop("filled", 0);
o0.set_prop("height", 50);
o0.set_prop("max value", 1);
o0.set_prop("start", 5.476190476190479);
o0.set_prop("ypos", 675);
o0.set_prop("linewidth", 2);
o0.set_prop("length", 6.363095238095235);
o0.set_prop("base line", 0);
o0.set_prop("out.freq", 2);
o0.set_prop("min value", -1);
o0.query_inlets();
c = o0.connect(o2,"out","amp",1.488095238095239);
c.set_prop("transfer func", '');
score.marks = [ { type : 'end', time : 30 } ];
score.metadata = { title : 'TestPrint', composer : 'kymatica', subtitle : '' };
