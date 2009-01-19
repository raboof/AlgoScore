import("csound");
import("math");

duration = 20;
cs = csound.create();
csound.compile(cs, ["-+rtaudio=alsa","-o","dac:plughw:0","test.orc"]);
# csound.compile(cs, ["-o","foo.wav","test.orc"]);

# generate events
for(var i = 0; i < 2000; i += 1) {
    start = math.trirand() * (duration-1);
    dur = math.linrand();
    amp = math.rand() * 0.5;
    if(math.rand() > 0.8) {
        ins = 3;
        frq = math.rand2(-1,1);
    } else {
        ins = 1;
        frq = math.rand2(40, 2000 * (1-dur));
    }
    csound.score_event(cs, `i`, [ins, start, dur*0.5, frq, amp]);
}

# run csound for the duration, glissing slowly upwards
x = 0;
while(csound.perform_ksmps(cs) == 0
      and csound.get_score_time(cs) < duration) {

    csound.kchannel_write(cs, "tone_pitch", x);
    x += 0.00002;
};

csound.reset(cs);
