<CsoundSynthesizer>
<CsOptions>
-+rtaudio=jack -odac:system:playback_ -B2048
</CsOptions>
<CsInstruments>

sr = 44100
kr = 4410
nchnls = 2

0dbfs = 1

gihandle OSCinit 7770
gkpw init 0.5

instr 1
  kf init 0
  kdur init 0
next1:
  kk OSClisten gihandle, "/note", "ff", kdur, kf
  if (kk == 0) goto ex
  event "i", 10, 0, kdur, kf
  kgoto next1
ex:
  kk OSClisten gihandle, "/pw", "f", gkpw
endin

instr 10
  kpw lineto gkpw, 0.01
;  kpw line 0.99, p3, 0.5
  a1 vco2 0.3, p4, 4, kpw
  a1 linen a1, 0, p3, p3
  outs a1*0.5, a1*0.5
endin

</CsInstruments>

<CsScore>
i 1 0 10000

</CsScore>
</CsoundSynthesizer>
