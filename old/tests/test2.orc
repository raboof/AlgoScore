sr = 44100
kr = 441
nchnls = 2

0dbfs = 1

gkb chnexport "tone_amp", 1
gkc chnexport "tone_pitch", 1

gisine ftgen 0, 0, 2048, 10, 4, 2, 3, 1

instr 1
;a1 oscil (p5>0?p5:gkb), p4+gkc*500, p6
a1 oscil gkb, p4+gkc*500, gisine
outs a1*0.5, a1*0.5
endin
