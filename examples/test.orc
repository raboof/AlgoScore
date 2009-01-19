sr = 44100
kr = 4410
nchnls = 2

0dbfs = 1

gkb chnexport "tone_amp", 1
gkc chnexport "tone_pitch", 1

gisine ftgen 0, 0, 2048, 10, 5, 1

instr 1
    a1 oscil p5*gkb, p4+gkc*100, gisine
    a1 linen a1, p3*0.3, p3, p3*0.3

    outs a1*0.2, a1*0.2
endin

instr 3
    a1 oscil p5, p4, gisine
    a1 linen a1, 0, p3, p3
    a1 mirror a1, -0.3, 0.3
    outs a1, a1
endin

instr 4
    k1 linen 1, p3*0.9, p3, 0
    a1 pinkish k1*0.2

    ktrig metro 50
    if ktrig == 1 then
      outvalue "tag", p1
      outvalue "amp", k1
    endif

    outs a1, a1
endin

instr 5
    a1 oscil p5, p4, p6
    a1 linen a1, p3*0.5, p3, p3*0.5
    al linen a1, p3, p3, 0
    ar linen a1, 0, p3, p3
    outs al*0.5, ar*0.5
endin
