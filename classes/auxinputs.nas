# Copyright 2008, Jonatan Liljedahl
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

var AuxInputs = {source_name:"AuxInputs"};
AuxInputs.init = func(o) {
    o.aux_getters = {};
    o.aux_inputs = [];
    o.add_obj_prop("aux_inputs",nil,func o.update_aux_inputs());
#    o.update_aux_inputs();
}
AuxInputs.update_aux_inputs = func {
    foreach(var in;keys(me.inlets)) {
        var inlet = me.inlets[in];
        if(contains(inlet,"is_aux"))
            inlet.is_aux=0;
    }
        
    foreach(var in;me.aux_inputs) {
        if(!contains(me.inlets,in))
            me.new_inlet(in);
        me.inlets[in].is_aux=1;
    }
    foreach(var in;keys(me.inlets)) {
        if(me.inlets[in]["is_aux"]==0)
            me.del_inlet(in);
    }
}
AuxInputs.update_aux_getters = func {
    foreach(var in;me.aux_inputs)
        me.aux_getters[in]=me.inlets[in].val_finder(0);
}

EXPORT=["AuxInputs"];
