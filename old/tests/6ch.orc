sr = 44100
kr = 441
nchnls = 6

0dbfs = 1

gisine ftgen 0, 0, 4096, 10, 1, 0.5, 0.2

instr 1

;    kgliss linseg 1, p3*0.5, p6, p3*0.5, 1
    a1 oscil 0.3, p4, gisine
;    kamp linseg 0, p3*0.2, 1, p3*0.8, 0
;    kamp line 1, p3, 0
;    kamp expon 1, p3, 0.00001
    kamp transeg 1, p3, -2, 0

    ktrig metro 50
    if ktrig == 1 then
        outvalue "tag", p1    
        outvalue "amp", kamp
    endif

    outch p5, a1*kamp

    ;outs a1, a1

endin
