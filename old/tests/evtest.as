o0=score.new_obj_by_name("datagen");
o0.properties["start"].set(0);
o0.properties["length"].set(3.969998187958176);
o0.properties["font_size"].set(10);
o0.start=0;
o0.length=3.969998187958176;
o0.ypos=117;
o0.text='out.resolution = 0;
out.interpolate = 0;
out.data = [
 [0,0],
 [1,10],
 [2,2],
 [3,1],
];';
finish(o0);
o2=score.new_obj_by_name("graph");
o2.properties["filled"].set(0);
o2.properties["max value"].set(10);
o2.properties["height"].set(100);
o2.properties["start"].set(0);
o2.properties["linewidth"].set(1);
o2.properties["base line"].set(0);
o2.properties["length"].set(5);
o2.properties["min value"].set(0);
o2.start=0;
o2.length=5;
o2.ypos=283;
finish(o2);
c = o2.connect(o0,"out","in",0.8411681465008158);
c.properties["transfer func"].set('');
o1=score.new_obj_by_name("send");
o1.properties["symbol"].set(1);
o1.properties["height"].set(10);
o1.properties["start"].set(0.4405529572940288);
o1.properties["length"].set(3.10459774187453);
o1.start=0.4405529572940288;
o1.length=3.10459774187453;
o1.ypos=472;
finish(o1);
c = o1.connect(o0,"out","in",2.146414842662181);
c.properties["transfer func"].set('');
o3=score.new_obj_by_name("recv");
o3.properties["symbol"].set(1);
o3.properties["height"].set(10);
o3.properties["start"].set(4.927809665532877);
o3.properties["length"].set(3.42220568783069);
o3.start=4.927809665532877;
o3.length=3.42220568783069;
o3.ypos=68;
finish(o3);
o4=score.new_obj_by_name("graph");
o4.properties["filled"].set(0);
o4.properties["max value"].set(10);
o4.properties["height"].set(100);
o4.properties["start"].set(4.927809665532877);
o4.properties["linewidth"].set(1);
o4.properties["base line"].set(0);
o4.properties["length"].set(5);
o4.properties["min value"].set(0);
o4.start=4.927809665532877;
o4.length=5;
o4.ypos=144;
finish(o4);
c = o4.connect(o3,"out","in",2.490079365079366);
c.properties["transfer func"].set('');
o3.add_link(o4,0);