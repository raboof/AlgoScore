
== code ==[code_class]

**Compile and evaluate nasal code.**@@
@@
**Properties:**@@
| ``eval_once`` | - if 0, the code will be evaluated each time a receieving object asks for a value.@@
**Outlets:**@@
| ``value`` | - outputs the returned value from the code.@@
| ``func`` | - outputs the compiled function.@@
@@
The code runs with the following variables available:@@
| ``math`` | - the math library (sin, pow, mod, etc...)@@
| ``G_set(sym,val)`` | - set global variable.@@
| ``G_get(sym)`` | - get global variable.

== comment ==[comment_class]

**Place a text comment in the score.**@@
@@
If ``marker in score`` property is set, a vertical gridline is drawn at the left edge of the object.

== comparator ==[comparator_class]

**Compare two numerical inputs.**@@
@@
``min`` and ``max`` properties sets the output value for when the ``in`` input is below or above the ``tresh`` input.@@
@@
``resolution`` property sets sample interval in seconds.

== cs_ftab ==[cs_ftab_class]

**Single event CSound function table generator/visualizer.**@@
@@
To be used with the csound objects ``ftable`` input.@@
The start time of this object is ignored.@@
``parms`` is a vector of f-statement parameters, like ``[1,0,1024,10,1]`` for a single sinewave cycle in ftab #1.@@
@@
If set to a single element vector, it does not send any event but only visualizes the specified function table.

== cs_instr ==[cs_instr_class]

**Single CSound instrument event.**@@
@@
p2 (time) and p3 (duration) is taken from the position and length of the object.@@
@@
``instr`` property sets the instrument number.@@
@@
``parms`` property is a list of instrument parameters, starting with p4.@@
If ``in(X)`` is used instead of a numeric parameter in this list, an inlet named X will be created and used to initialize that parameter.@@
@@
Example: ``[100, in('A'), 1]`` will set p4 to 100, p5 to the current value at the inlet A and p6 to 1.

== cs_instr_graph ==[cs_instr_graph_class]

**Single CSound instrument event.**@@
@@
p2 (time) and p3 (duration) is taken from the position and length of the object.@@
@@
``instr`` property sets the instrument number.@@
@@
``parms`` property is a list of instrument parameters, starting with p4.@@
If ``in(X)`` is used instead of a numeric parameter in this list, an inlet named X will be created and used to initialize that parameter.@@
@@
Example: ``[100, in('A'), 1]`` will set p4 to 100, p5 to the current value at the inlet A and p6 to 1.@@
@@
The ``graphs`` property is a hash like this: ``{amp:{fill:1, lw:1, max:1}, foo:{fill:0, lw:2, max:100}}``@@
The keys specifies what outvalue-channels to plot, ``fill`` tells if the graph should be filled or not, ``lw`` is linewidth and ``max`` the maximum value.@@
@@
The values should be sent from the orchestra with code like this:@@
@@
  ``ktrig metro 50``@@
  ``if ktrig == 1 then``@@
    ``outvalue "tag", p1 ; needed to identify the event``@@
    ``outvalue "amp", k1``@@
    ``outvalue "foo", k2``@@
  ``endif``@@


== csound_bus ==[csound_bus_class]

**CSound output bus.**@@
@@
``orc_file`` property sets the orchestra file to use.@@
@@
``events`` input takes instrument events as ``[p1,p3,...]`` and gives them to csound with p2 set to the time of the incomming event.@@
@@
``ftable`` input takes single events with GEN parameters as ``[ftab_num, time, size, gen_num, gen_args...]``@@
@@
Any software channels defined in the orchestra will show up in the connection list.

== datagen ==[datagen_class]

**Generate data or events with nasal code.**@@
@@
The code runs with the following variables available:@@
| ``length`` | - the length of the object. (read-only)@@
| ``in`` | - a table of functions f(t) to get value from input at time t, named after the inputs specified in the ``aux_inputs`` property. example: ``x = in.A(t);``@@
| ``out.resolution`` | - sample interval, or 0 for event-data.@@
| ``out.interpolate`` | - 1 to interpolate between values.@@
| ``out.data`` | - the output data, initialized to []@@
| ``math`` | - the math library (sin, pow, mod, etc...)@@
| ``inlets`` | - direct access to inlets, for use of Inlet.get_connections() and such.@@
| ``G_set(sym,val)`` | - set global variable.@@
| ``G_get(sym)`` | - get global variable.@@
@@
Multiple outlets may be specified in the ``outlets`` property. They will be available just like 'out' above but named accordingly.

== evgraph ==[evgraph_class]

**Plot discrete events.**@@
@@
``events`` input takes events in the format ``[val1, ...]``@@
@@
**Properties:**@@
| ``y_parm`` | - what element of the event should describe the vertical position of the event.@@
| ``y2_parm`` | - what element of the event should describe the vertical end-position of the event.@@
| ``dur_parm`` | - what element should describe the length of the event.@@
| ``black_parm`` | - what element should describe the opacity of the event.@@
| ``size_parm`` | - what element should describe the size of the onset marker. Use ``size_scale`` to scale it.@@
| ``grid`` | - y-space division.

== funcbus ==[funcbus_class]

**Process inputs through nasal code.**@@
@@
The code runs with the following variables available:@@
| ``in`` | - a table of functions f(t) to get value from input at time t, named after the inputs specified in the ``aux_inputs`` property. example: ``return x * in.A(t);``@@
| ``t`` | - time of the value asked for by the receieving object.@@
| ``ev`` | - the value of the 'event' inlet at time t.@@
| ``x`` | - ramp from 0.0 to 1.0 along the length of the object.@@
| ``outlet`` | - the name of the outlet asked for by the receieving object. The available outlets are specified in the ``outlets`` property.@@
| ``length`` | - the length of the object.@@
| ``math`` | - the math library (sin, pow, mod, etc...)@@
| ``init`` | - 1 at first eval after update.@@
| ``G_set(sym,val)`` | - set global variable.@@
| ``G_get(sym)`` | - get global variable.@@
@@
If a destination object asks for an event by index, t will be set to the corresponding event of the 'event' inlet, both in the ``t`` variable and in the returned event. The 'ev' variable will then hold the actual value of the event. This can be used to synthesize events by combining multiple sources or expressions.

== graph ==[graph_class]

Plot incomming numerical data.

== jitter ==[jitter_class]

**Random line-curve.**@@
@@
``min duration`` and ``max duration`` sets default min and max duration in seconds. Can also be controlled with ``mindur`` and ``maxdur`` inlets.@@
``time_randomizer`` and ``value_randomizer`` sets the code used to get random numbers. aux inputs are available as ``in``, current time as ``t`` and last value as ``last``.

== linseg ==[linseg_class]

**User defined break-point curve.**@@
@@
``shape data`` property is in the format ``[val1, time1, val2, time2, val3, ...]``@@
if ``proportional`` is zero, times are in seconds, otherwise relative each other and fitted into the object length.

== masklinseg ==[masklinseg_class]

Like ``linseg`` but with min/max curves.

== maskshape ==[maskshape_class]

Like ``shape`` but with min/max curves.

== midi_bus ==[midi_bus_class]

**Output MIDI to JACK or midifile.**@@
@@
**Properties:**@@
| ``port_id`` | - name of the JACK midiport.@@
| ``channel`` | - MIDI channel.@@
| ``controllers`` | - table of CC names and their number, like ``{mod:1,vol:7}``. Add 1000 to the number to make it send 14 bit controllers instead of 7 bit.@@
| ``resolution`` | - resolution of interpolated inputs.@@
@@
**Inputs:**@@
| ``note`` | - note events in the format ``[pitch, velocity]`` or ``[pitch, velocity, duration]``.@@
| ``pitch`` | - numerical input in the range -1.0 to +1.0 for pitchwheel events.@@
| ``raw`` | - events of raw midi bytes, like ``[0x90, 60, 100]``.@@
All CC's defined in ``controllers`` shows up as inputs, and takes numerical data in the range 0.0 to 1.0.@@


== morph ==[morph_class]

**Morph between two inputs**@@
@@
Vectors and hashes are handled recursively.@@
Vectors must have the same structure.@@
Any keys in one hash that are missing in the other are copied.@@
If the type of A is not the same as B, the value of A will be returned.@@
The ``interpolator`` property defines the function used for interpolating between numeric values.@@
The code runs with the following variables set:@@
| ``a`` | - The value of input A.@@
| ``b`` | - The value of input B.@@
| ``x`` | - The value of input x if connected, else a ramp between 0.0 and 1.0 along the length of the object.@@


== noise ==[noise_class]

**Random LFO.**@@
@@
**Inputs:**@@
| ``max`` | - upper value limit.@@
| ``min`` | - lower value limit.@@
@@
**Properties:**@@
| ``seed`` | - initial random seed.@@
| ``randomizer`` | - the code used to get random number. aux inputs are available as ``in``, current time as ``t`` and last value as ``last``.@@
| ``out.resolution`` | - rate in seconds.@@
| ``out.interpolate`` | - 0 for stepped values and 1 for interpolated lines between values

== osc_bus ==[osc_bus_class]

**Output OSC (OpenSoundControl) messages.**@@
@@
**Properties:**@@
| ``osc_address`` | - destination URL, like 'osc.udp://localhost:7770'@@
| ``resolution`` | - resolution of interpolated inputs.@@
| ``controllers`` | - table of inlet names and their path and typetag string, like ``{freq:['/something/freq','f']}``@@
@@
When the typetag string is a single letter, the inlet expects a single value, otherwise it expects a vector with corresponding types.@@
@@
**Type tags:**@@
| f | - float@@
| i | - 32 bit integer@@
| d | - double@@
| c | - 8 bit integer@@
| s | - string@@
| S | - symbol@@
| m | - string of 4 midi bytes@@


== recv ==[recv_class]

Receive data from the Send object that are sending on the same symbol.

== send ==[send_class]

Send data to all Recv objects that are listening on the same symbol.

== shape ==[shape_class]

**Simple ramps between values.**@@
@@
``shape data`` property sets the sequence of values, which are evenly spaced along the length of the object.

== signal_bus ==[signal_bus_class]

**Send raw float values through a JACK signal port.**@@
@@
The ``sr_div`` property sets the control rate as a division of the sample rate, as queried from the JACK server.

== sine ==[sine_class]

**Sinewave LFO.**@@
@@
**Inputs:**@@
| ``freq`` | - set frequency.@@
| ``freq_mul`` | - scale the frequency.@@
| ``amp`` | - scale the amplitude.@@
@@
**Properties:**@@
| ``out.freq`` | - default frequency when ``freq`` input is not connected.@@
| ``out.amp`` | - the initial amplitude.@@
| ``out.resolution`` | - the sample interval in seconds.

== slider ==[slider_class]

A simple graphical slider.

== timegrid ==[timegrid_class]

**Timegrid with alignmentpoints and controllable tempo.**

