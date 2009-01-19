# Copyright 2007, 2008, Jonatan Liljedahl
#
# This file is part of AlgoScore.
#
# AlgoScore is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# AlgoScore is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with AlgoScore.  If not, see <http://www.gnu.org/licenses/>.

import("algoscore");
import("cairo");

# gör en SVG-image object..

Brace = {name:"brace",parents:[algoscore.ASObject]};
Brace.init = func(o) {
    algoscore.ASObject.init(o);
    o.parents=[Brace];
    o.length=0;
    o.fontsize=100;
    o.fontface="Serif";
    o.char="{";
    var f = func o.remake_surface();
    o.add_obj_prop("fontsize",nil,f);
    o.add_obj_prop("fontface",nil,f,1);
    o.add_obj_prop("char",nil,f,1);
}
Brace.update_geometry = func(cr) {
    cairo.select_font_face(cr,me.fontface);
    cairo.set_font_size(cr,me.fontsize);
    var x = cairo.text_extents(cr,me.char);
    var fx = cairo.font_extents(cr);
    me.width=x.x_advance;
    me.height=fx.height;
    me.descent=fx.descent;
    
}
Brace.draw = func(cr,ofs,width,last) {
    cairo.select_font_face(cr,me.fontface);
    cairo.set_font_size(cr,me.fontsize);
    cairo.move_to(cr,0,me.height-me.descent);
    cairo.show_text(cr,me.char);
}

HLine = {name:"horz_line",parents:[algoscore.ASObject]};
HLine.init = func(o) {
    algoscore.ASObject.init(o);
    o.parents=[HLine];
    o.sticky=1;
    o.start=0;
    o.fixed_start=1;
    o.length=0;
    o.height=6;
    o.linewidth=2;
    o.add_obj_prop("caption");
    o.add_obj_prop("linewidth");
}
HLine.draw = func(cr,ofs,width,last) {
    cairo.move_to(cr,ofs,me.height/2);
    cairo.rel_line_to(cr,width,0);
    cairo.set_line_width(cr,me.linewidth);
    cairo.stroke(cr);
}
HLine.update_geometry = func(cr,canvas_w) {
    me.width = canvas_w;
}

EXPORT=["Brace","HLine"];
