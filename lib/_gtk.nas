init();

var box_pack_start = func(w,c,e=1,f=1,p=0) {
        emit(w,"add",c);
        child_set(w,c,"expand",e,"fill",f,"padding",p,"pack-type","start");
};
var box_pack_end = func(w,c,e=1,f=1,p=0) {
        emit(w,"add",c);
        child_set(w,c,"expand",e,"fill",f,"padding",p,"pack-type","end");
};
