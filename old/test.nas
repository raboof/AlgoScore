Base = {};
Base.new = func {
    var o = {};
    me.init(o);
    return o;
}
Base.init = func(o) {
    print("base init\n");
    o.parents = [Base];
    o.foo = 42;
    o.bar = 111;
}

SubA = {parents:[Base]};
SubA.init = func(o) {
    Base.init(o);
    print("A init\n");
    o.parents = [SubA];
    o.bar = 10;
}
SubA.zoo = func {
    me.bar *= 123;
}

SubB = {parents:[Base]};
SubB.init = func(o) {
    Base.init(o);
    print("B init\n");
    o.parents = [SubB];
}
SubB.zoo = func {
    me.foo *= 1000;
}

Foo = {parents:[SubB,SubA]};
Foo.init = func(o) {
    SubA.init(o);
    SubB.init(o);
    print("Foo init\n");
    o.parents=[Foo];
}
Foo.print = func {
    print(me.foo,"\n");
    print(me.bar,"\n");
}

f = Foo.new();
f.zoo();
f.print();
