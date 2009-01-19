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

instr 1
  kf init 0
  ka init 0
  kpw init 0.01

  kk OSClisten gihandle, "/freq", "f", kf
  kk OSClisten gihandle, "/amp", "f", ka
  kk OSClisten gihandle, "/pw", "f", kpw
  
  kf2 lineto kf, 0.01
  kamp lineto ka, 0.01
  aamp interp kamp

  a1 vco2 1, 50+kf2*300, 4, kpw
  a1 = a1 * aamp
  al, ar pan2 a1, kamp
  outs al*0.5, ar*0.5
endin

</CsInstruments>

<CsScore>
i 1 0 1000

</CsScore>
</CsoundSynthesizer>
