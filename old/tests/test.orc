sr = 44100
kr = 4410
nchnls = 2

0dbfs = 1

gka chnexport "noise_amp", 1
gkb chnexport "tone_amp", 1
gkc chnexport "tone_pitch", 1

gadistl init 0
gadistr init 0

gisine ftgen 0, 0, 2048, 10, 5
;gisine ftgen 0, 0, 2048, 16, 1, 2048, 0, -1
;gisine ftgen 0, 0, 1024, 7, 0, 450, 1, 124, -1, 450, 0

instr 1
a1 oscil 0.1+50/p4, p4, p6
;a1 oscil p5*gkb, p4+gkc*500, gisine
;a1 linen a1, 0, p3, p3
;a1 linen a1, p3, p3, 0.01
a1 linen a1, p3*0.3, p3, p3*0.3
;am expseg 0.001, p3*0.3, 0.8, p3*0.4, 1, p3*0.3, 0.001
;a1 = a1 * am

;ipan random -1, 1
ipan unirand 2
ipan = ipan - 1

k1 linseg ipan, p3, (1-ipan)
al = a1*k1
ar = a1*(1-k1)
;al linen a1, p3, p3, 0
;ar linen a1, 0, p3, p3

outs al*0.15, ar*0.15
gadistl = gadistl + al
gadistr = gadistr + ar

;al clip al, 1, 0.5
;ar clip ar, 1, 0.5
;outs al, ar
endin

instr 2
a1 pinkish gka
outs a1, a1
endin

instr 3
a1 oscil p5, p4, gisine
a1 linen a1, 0, p3, p3
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
a1 randi 1, p4
outs a1,a1
endin

instr 10
a2 clip gadistl, 0, p4
a1 clip gadistr, 0, p4
gadistl = 0
gadistr = 0

a11 streson a1*0.4, 110, 0.98
a22 streson a2*0.4, 111, 0.98
a33 streson a1*0.4, 220*1.5, 0.98
a44 streson a2*0.4, 221.1*1.5, 0.98
outs p5*(a11+a33), p5*(a22+a44)

;outs a1*p5, a2*p5

endin
