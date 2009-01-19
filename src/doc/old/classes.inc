=== linseg

something like csound linseg

=== cs_instr_graph

Single CSound instrument event.

p2 (time) and p3 (duration) is taken from the position and length of the object.

'instr' property sets the instrument number.

'parms' property is a list of instrument parameters, starting with p4.
If 'in(X)' is used instead of a numeric parameter in this list,
an inlet named X will be created and used to initialize that parameter.
Example: `[100, in(0), 1]` will set p4 to 100, p5 to the current value
at the inlet '0' and p6 to 1.

The 'graphs' property is a hash like this:
`$${ amp:{fill:1,lw:1,max:1}, foo:{fill:0,lw:2,max:100} }$$`
The keys specifies what outvalue-channels to plot,
'fill' tells if the graph should be filled or not, 'lw' is linewidth
and 'max' the maximum value.

The values should be sent from the orchestra with code like this:
---------
ktrig metro 50
if ktrig == 1 then
  outvalue "tag", p1 ; needed to identify the event
  outvalue "amp", k1
  outvalue "foo", k2
endif
-----------

=== cs_ftab

Single event CSound function table generator/visualizer.

To be used with the csound objects 'ftable' input.

The start time of this object is ignored.

'parms' is a vector of f-statement parameters, like `[1,0,1024,10,1]` for a single
sinewave cycle in ftab 1.

If set to a single element vector, it does not send any event but only visualizes the
specified function table.

=== funcbus

Process inputs through nasal code.

The code runs with the following variables available:

* 'in' - a table of input values, named after the inputs, which are dynamically created when
connected. example: `return x * in.A;`
* 't' - the time of the value asked for by the receieving object.
* 'x' - a ramp from 0.0 to 1.0 along the length of the object.
* 'length' - the length of the object.
* 'math' - the math library (sin, pow, mod, etc...)
* 'G_set(sym,val)' - set global variable.
* 'G_get(sym)' - get global variable.

=== send

Send data to all Recv objects that are listening on the same symbol.

=== masklinseg

(no description)

=== maskshape

(no description)

=== audiobus

output audio to JACK or soundfile.

'port_id' property sets the prefix of the JACK ports.

'channels' property sets number of ports.

=== cs_instr

Single CSound instrument event.

p2 (time) and p3 (duration) is taken from the position and length of the object.

'instr' property sets the instrument number.

'parms' property is a list of instrument parameters, starting with p4.
If `in(X)` is used instead of a numeric parameter in this list, an inlet named X
will be created and used to initialize that parameter.
Example: `[100, in(0), 1]` will set p4 to 100, p5 to the current value at the inlet '0'
and p6 to 1.

=== jitter

like csound jitter opcode.

=== comparator

Compare two numerical inputs.

'min' and 'max' properties sets the output value for when the 'in' input is below or above the
'tresh' input.

'resolution' property sets sample interval in seconds.

=== comment

Place a text comment in the score.

If 'marker in score' property is set, a vertical gridline is drawn at the left edge of the
object.

=== shape

Simple ramps between values.

'shape data' property sets the sequence of values, which are evenly spaced along the length of
the object.

=== sine

Sinewave LFO

.Inputs:
* 'freq' sets frequency.
* 'freq_mul' scales the frequency.
* 'amp' scales the amplitude.

.Properties:
* 'out.freq' is default frequency when 'freq' input is not connected.
* 'out.amp' is the initial amplitude.
* 'out.resolution' sets the sample interval in seconds.

=== multisine

(no description)

=== graph

Plot incomming numerical data.

=== midibus

Output MIDI to JACK or midifile.

.Properties:
* 'port_id' is the name of the JACK midiport.
* 'channel' is the MIDI channel.
* 'controllers' is a table of CC names and their number, like `$${mod:1,vol:7}$$`.
Add 1000 to the number to make it send 14 bit controllers instead of 7 bit.

.Inputs:
* 'note' takes note events in the format [pitch,velocity] or [pitch, velocity, duration].
* 'pitch' takes numerical input in the range -1.0 to +1.0 for pitchwheel events.
* 'raw' takes events of raw midi bytes, like [0x90, 60, 100].

All CC's defined in 'controllers' shows up as inputs, and takes numerical data in the range 0.0
to 1.0.


=== datagen

Generate data or events with nasal code.

The code runs with the following variables available:

* 'length' - the length of the object.
* 'input' - a table of functions f(t) to get value from input at time t, named after the inputs, which are dynamically created when connected. example: 'x = input.A(t);'

* 'out.resolution' (writable) - the sample interval, or 0 for event-data.
* 'out.interpolate' (writable) - 1 to interpolate between values.
* 'out.data' (writable) - the output data.
* 'math' - the math library (sin, pow, mod, etc...)
* 'G_set(sym,val)' - set global variable.
* 'G_get(sym)' - get global variable.

=== sum

sum numerical inputs

=== slider

A simple graphical slider.

=== noise

Random LFO.

.Inputs:
* 'max' sets the upper value limit.
* 'min' sets the lower value limit.

.Properties:
* 'seed' sets the initial random seed.
* 'out.resolution' sets the rate.
* 'out.interpolate' is 0 for stepped values and 1 for interpolated lines between values

=== recv

Receive data from the Send object that are sending on the same symbol.

=== sndfile

read soundfile

=== timegrid

Timegrid with alignmentpoints and controllable tempo.

=== code

Compile and evaluate nasal code.

* 'value' outputs the returned value from the code.
* If 'eval_once' is 0, the code will be evaluated each time a receieving object asks for a value.
* 'func' outputs the compiled function.

The code runs with the following variables available:

* 'math' - the math library (sin, pow, mod, etc...)
* 'G_set(sym,val)' - set global variable.
* 'G_get(sym)' - get global variable.

=== evgraph

Plot discrete events.

'events' input takes events in the format `[val1,...]`

.Properties:
* 'y_parm' chooses what element of the event should describe the vertical position of the event.
* 'dur_parm' chooses what element should describe the length of the event.
* 'black_parm' chooses what element should describe the opacity of the event.

=== csound_bus

CSound output bus.

'orc_file' property sets the orchestra file to use.

'events' input takes instrument events as `[p1,p3,...]` and gives them to csound with p2 set to
the time of the incomming event.

'ftable' input takes single events with GEN parameters as `[ftab_num, time, size, gen_num,
gen_args...]`

Any software channels defined in the orchestra will show up in the connection list.
