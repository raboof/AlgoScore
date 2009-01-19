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

import("outbus");
import("sndfile");
import("playbus");
import("unix");
import("thread");
import("interval");
import("utils");

var SigBus = {name:"signal_bus",parents:[outbus.OutBus]};
SigBus.description =
"<b>Send raw float values through a JACK signal port.</b>\n\n"
"The <tt>sr_div</tt> property sets the control rate as a division of the sample rate,"
" as queried from the JACK server.";
SigBus.init = func(o) {
    outbus.OutBus.init(o);
    o.parents = [SigBus];
    o.port_id = "signal"~o.id;
    o.bus = playbus.create_bus();
    o.sr_div = 100;
    o.add_obj_prop("sr_div",nil,func { playbus.set_sr_div(o.bus,o.sr_div); o.update()});
    playbus.set_sr_div(o.bus,o.sr_div);
    o.outfile = get_tmp_dir()~"/as"~unix.getpid()~"_signal"~o.id~".raw";
    o.add_obj_prop("port_id",nil,func o.update_ports());
#    o.channels = 1;
#    o.add_obj_prop("channels",nil,func o.update_ports());
    
    o.new_inlet("in");

    o.thread_working = 0;
    o.thread_cancel = 0;
    o.thread_progress = 0;
    o.thread_lock = thread.newlock();
    o.thread_sem = thread.newsem();

    o.thread_mon_id = interval.add_proc(func o.thread_monitor());

    o.update_ports();
    o.register_bus();
}
SigBus.update_ports = func {
    me.caption = me.port_id;
    playbus.setup_ports(me.bus, me.port_id, 1, 0);
}
SigBus.cleanup = func {
    unix.unlink(me.outfile);
    interval.remove_proc(me.thread_mon_id);
}
SigBus.reconnect = func {
    playbus.remove_bus(me.bus);
    me.bus = playbus.create_bus();
    me.update_ports();
    me.update();
}
SigBus.thread_monitor = func {
    thread.lock(me.thread_lock);
    
    if(me.thread_working!=0) {
        me.update_progress = me.thread_progress;
        if(me.thread_working==2) {
            print(me.get_label(),": update thread done\n");
            me.thread_working=0;
            me.pending_update = me.thread_cancel;
        }
        me.score.queue_draw();
    }

    thread.unlock(me.thread_lock);
    return 1;
}
SigBus.cancel_generate = func {
    thread.lock(me.thread_lock);
    if(me.thread_working==1) {
        me.thread_cancel=1;
        thread.unlock(me.thread_lock);
#        print_stderr("cancel waiting on semdown\n");
        thread.semdown(me.thread_sem);
#        print_stderr("cancel did semdown\n");
        return 1;
    }
    thread.unlock(me.thread_lock);
    return 0;
}
SigBus.generate = func {
#print_stderr("generate\n");
#    if(me.cancel_generate())
#        print(me.get_label(),": restarting thread\n");

    thread.lock(me.thread_lock);
    me.getter = me.inlets.in.val_finder(0);
    me.krate = playbus.get_sr()/me.sr_div;
    me.fp = sndfile.open(me.outfile, sndfile.WRITE, sndfile.RAWFLOAT, 1, me.krate);
    playbus.set_file(me.bus,[me.outfile,1]);

#    thread.lock(me.thread_lock);
    me.thread_progress = 0;
    me.thread_working = 1;
    me.thread_cancel = 0;
    thread.unlock(me.thread_lock);

#print_stderr("starting thread...\n");
#    thread.newthread(func me.update_thread());

    thread.newthread(func {
        var err=[];
        call(me.update_thread,[],me,nil,err);
        if(size(err)) {
            printerr(utils.stacktrace(err));
            thread.semup(me.thread_sem);
        }
    });

    return 1;
}

SigBus.update_thread = func {
#print_stderr("update_thread\n");
    var dt = 1/me.krate;
    var t = 0;
    var length = me.score.endmark.time;
    var buf = setsize([],64);
    var do_semup = 0;
    while(t<length) {
#        print_stderr("thread locking (in loop)\n");
        thread.lock(me.thread_lock);
        me.thread_progress = t;
        if(me.thread_cancel) {
            do_semup = 1;
#            print_stderr("thread unlocking (at cancel)\n");
            thread.unlock(me.thread_lock);
            break;
        }
#        print_stderr("thread unlocking (in loop)\n");
        thread.unlock(me.thread_lock);
#        print_stderr("getting values\n");
        for(i=0;i<64 and t<length;i+=1) {
            buf[i] = me.getter(t);
            t += dt;
        }
#        print_stderr("writing to sndfile...\n");
        sndfile.write(me.fp, buf);
#        print_stderr("done writing.\n");
    }
    sndfile.close(me.fp);

#    print_stderr("thread locking (after loop)\n");
    thread.lock(me.thread_lock);
    me.thread_working = 2; #done
#    print_stderr("thread unlocking (after loop)\n");
    thread.unlock(me.thread_lock);
    if(do_semup) {
#        print_stderr("thread doing semup\n");
        thread.semup(me.thread_sem);
    }

    return 0;
}

EXPORT=["SigBus"];
