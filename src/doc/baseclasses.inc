
== Score class ==[Score]
The current score object is available as ``score`` in the console or
``me.score`` in classes.
=== Score.objects{} ===
A table of all objects in the score, indexed by numerical ID.
=== Score.new_obj_by_name(class_name) ===
Create object from class ``class_name``.
=== Score.time2x(t) ===
Convert time in seconds to pixel position according to current zoom.
=== Score.x2time(x) ===
Convert pixel position to time in seconds according to current zoom.
=== Score.update_all(all=0, list=nil, force=0) ===
Update all objects.
| ``all`` | - all objects if 1, otherwise only pending updates.
| ``list`` | - list of objects if not nil, otherwise all objects.
| ``force`` | - also objects with ``delay_update`` set.
=== Score.get_object_tree(list=nil) ===
Get a list of all objects (or the ones in ``list``)
sorted according to their dependencies.
=== Score.dump_objects() ===
Generate a textual string that will create the current
score with all objects if compiled and run as nasal code.
=== Score.save_to_file(filename) ===
Save the current score to file.
=== Score.load_from_file(filename) ===
Load a score from file.
=== Score.multi_copy(id, n, dt=nil, ghost=0) ===
Make multiple copies of an object.
| ``id`` | - the object ID.
| ``n`` | - numer of copies.
| ``dt`` | - amount of time each copy should be offset, defaults to objects length.
| ``ghost`` | - if 1, create ghost copies instead of real copies.
=== Score.align_ghosts() ===
Vertically align all ghost copies with their parents.
=== Score.match_prop(prop, val) ===
Return a list of IDs of all objects where property ``prop`` matches ``val``.
=== Score.many_set_prop(ids, prop, val) ===
Set property on multiple objects at once.
| ``ids`` | - a list of object IDs.
| ``prop`` | - the name of the property.
| ``val`` | - the value.
== ASObject class ==[ASObject]
This is the baseclass for all AlgoScore objects.
=== ASObject.children{} ===
A table of objects that depends on this object. Used for
dependency resolution when sorting the object tree.
=== ASObject.clean_globals(namespace=nil) ===
Remove this object from the list of global suppliers.
Additionally, if ``namespace`` is non-nil, add
``G_set(sym,val)`` and ``G_get(sym)`` to the namespace.
=== ASObject.set_global(sym, val) ===
Set global variable ``sym`` to ``val`` and register
this object as the supplier for that variable.
=== ASObject.get_global(sym) ===
Get global variable ``sym`` and add this object
as a children to the supplier of that variable.
=== ASObject.remake_surface() ===
Recreate the current graphics cache for this object.
=== ASObject.get_label() ===
Return a label for this object, in the format classname[ID].
Can be overridden by subclasses if wanted.
=== ASObject.dump() ===
Return a textual string that will create this object and all
its properties if compiled and executed as nasal code.
=== ASObject.duplicate(ghost=0) ===
Create a copy of this object with all its properties.
If ``ghost`` is non-zero, create a ghost copy.
=== ASObject.edit_event(ev) ===
Override this to handle key and mouse events in //edit mode//.
``ev`` is a standard GTK event.
=== ASObject.edit_start() ===
Called when the user requests //edit mode// on this object.
Return 1 to stay in edit mode (events will be sent to me.edit_event())
or 0 to exit edit mode.
=== ASObject.edit_end() ===
Called when the user exits //edit mode// on this object.
=== ASObject.add_obj_prop(name, sym=nil, cb=nil, no_eval=0) ===
Add an object property.
| ``name`` | - the name of the property as shown in the GUI.
| ``sym`` | - the symbol of the property as stored in the object. Defaults to ``name``.
| ``cb`` | - the callback to be called when this property changed.
| ``no_eval`` | - if 0, evaluate the property as nasal code, else treat it as a string.
=== ASObject.del_obj_prop(name) ===
Delete an object property.
=== ASObject.set_prop(name, val) ===
Set an object property.
=== ASObject.get_prop(name) ===
Get an object property.
=== ASObject.new_inlet(name) ===
Create new inlet.
=== ASObject.del_inlet(name) ===
Disconnect and remove inlet.
=== ASObject.delete_all_inlets() ===
Delete all inlets.
=== ASObject.disconnect_all() ===
Disconnect all inlets.
=== ASObject.new_outlet(name, res=0, ipol=0) ===
Add a new outlet.
| ``name`` | - the name of the outlet.
| ``res`` | - sample resolution in seconds or 0 for event data.
| ``ipol`` | - 1 to interpolate between events or samples.
=== ASObject.cleanup() ===
Override this to define a handler for cleaning up
when this object is destroyed.
=== ASObject.destroy(all=0) ===
Destroy this object and call all cleanup handlers in the
class parents. If ``all`` is zero, unregister it from the
score and remove all connections, etc...
=== ASObject.get_parents() ===
Return a table of all objects connected to this object.
=== ASObject.has_parents() ===
Return 1 if any objects are connected to this object.
=== ASObject.has_parents_in(list) ===
Return 1 if any objects in ``list`` are connected to this object.
=== ASObject.xy_inside(x,y) ===
Return true if x,y is inside the active "click region" of object.
Can be overridden by subclasses.
=== ASObject.connect(src, outlet, inlet, pos=nil) ===
Connect ``outlet`` of object ``src`` to ``inlet`` on this object.
If ``pos`` is given, set connections graphical position.
Returns the created [Connection #Connection] object or nil if failed.
=== ASObject.connect_done(src, outlet, inlet) ===
Override this to be called when connection is done.
=== ASObject.disconnect(src, inlet, do_update=1) ===
Disconnect object ``src``from ``inlet`` on this object.
If ``do_update`` is zero, don't update this object.
=== ASObject.query_inlets() ===
Override this to be called before user gets the list of available
inlets.
=== ASObject.add_link(src, t) ===
Add link from object ``src`` to this object,
at position ``t`` in seconds.
=== ASObject.is_linked(src) ===
Return 1 if this object is linked with ``src``.
=== ASObject.remove_link(src) ===
Remove any link between this object and ``src``.
=== ASObject.remove_all_links() ===
Remove all links between this object and any other object.
=== ASObject.get_alignments() ===
Return a list of alignment points (in seconds)
of this object. Defaults to a sorted ``me.alignments``
with 0 and ``me.length`` added.
=== ASObject.get_object_tree() ===
Returns the topological sort of the dependency tree with this
object as the root object.
=== ASObject.update_now() ===
Force update of this object now.
=== ASObject.generate() ===
The subclass-provided function that generates the data for this object,
called when this object is updated.
Should return 0 if finished, or 1 if not. Most classes should return 0,
returning 1 is for the case of output busses at the end of the connection
graph, which might render in a background thread. They should then set
obj.pending_update to 0 when the thread finishes.
=== ASObject.cancel_generate() ===
Output busses that render in background threads can define this to
be called when the user asks to cancel the processing.
=== ASObject.update(children_only=0) ===
Update object.
Call this whenever the object and all its children should generate
it's data. For example after user-editing some property or data of the object.

``children_only``:
| 0 | - for this obj and it's children,
| 1 | - for children only,
| -1 | - for this obj only, but set pending update for children.
=== ASObject.update_if_connected() ===
Update this object if it is connected to any other object.
=== ASObject.redraw() ===
Sets ``redraw`` flag to indicate that this object needs redrawing.
Call this whenever the object should redraw.
The flag is checked by Score.redraw() 
=== ASObject.move_resize_done(moved, resized) ===
Called after object has been moved (start or ypos changed)
and/or resized (length changed). Could be overridden by subclass.
=== ASObject.draw(cr, ofs, width, last) ===
The subclass-provided function that draws the object.
| ``cr`` | - cairo context to draw on.
| ``ofs`` | - offset into the total object width that this sub-surface starts on. That is, the x pixel that 0 corresponds to. Zero when drawing on the first sub-surface.
| ``width`` | - width of the sub-surface, clipped to the total object width in the last sub-surface, where ``last`` is 1 instead of 0.
=== ASObject.update_geometry(cr, canvas_width) ===
The subclass-provided function that updates obj.width.
Default is based exactly on obj.length.
=== ASObject.interpolate(outlet, a, b, x) ===
Function to interpolate between a and b, where x is between 0.0 and 1.0
can be overridden by subclass.
=== ASObject.default_get_value(outlet, t) ===
Get value at time ``t`` on ``outlet``, reading ``outlet.data``
as samples if ``outlet.resolution`` is non-zero or events if zero,
interpolating with ``me.interpolate()`` if ``outlet.interpolate`` is non-zero.
=== ASObject.get_value(outlet, t) ===
Get value at time ``t`` on ``outlet``.
Can be overridden by subclass, default calls ``me.default_get_value()``.
Note that this might be called from an output bus background thread, and
must be thread safe.
=== ASObject.default_get_event(outlet, index) ===
Get event number ``index`` on ``outlet``,
in the format ``[t, value]``.
Can be overriden by subclass.
=== ASObject.get_event(outlet, i) ===
Get event at index ``i`` on ``outlet``.
Can be overridden by subclass, default calls ``me.default_get_event()``.
Note that this might be called from an output bus background thread, and
must be thread safe.
=== ASObject.get_datasize(outlet) ===
Get number of elements in ``outlet.data``, either number of
events or number of samples.
Can be overriden by subclass.
== Inlet class ==[Inlet]
An Inlet object is a named input slot of an object, and holds any number
of [connection #Connection] objects.
=== Inlet.add_con_prop(name, sym=nil, init=nil, cb=nil, no_eval=1) ===
Add a property for connections to this inlet.
Arguments is similar to [ASObject #ASObject].add_obj_prop().
``init`` is a table of symbols and their initialization values.
=== Inlet.get_connections() ===
Returns a list of all Connection objects for this inlet.
Also sets ``inlet.datasize`` as the sum of each connections datasize,
and ``connection.datasize`` which is retreived through ``source_obj.get_datasize(outlet).``
=== Inlet.con_finder() ===
Returns a cached connection-finder, which is a function //f(t)// that returns the relevant
connection at time ``t``. As long as ``t`` is not less than it was the last time, the
search will start at the last found connection.
Returns nil if inlet is not connected.
=== Inlet.val_finder(default=nil) ===
Returns a cached value-finder, which is a function //f(t)// that returns
the value at time ``t`` from the connection at time ``t``, or the value of ``default``
if inlet is not connected.
=== Inlet.val_finder_num(default=nil) ===
Returns a cached value-finder, which is a function //f(t)// that returns
the value at time ``t`` from the connection at time ``t``, or the value of ``default``
if inlet is not connected or the value is not a number.
== Connection class ==[Connection]
A Connection object holds a connection from a source object and outlet.
It will also hold properties specific for this connection.
=== Connection.set_prop(sym, val) ===
Set property.
=== Connection.get_prop(sym) ===
Get property.
=== Connection.get_resolution() ===
Returns the value of ``outlet.resolution`` for this connections
source object and outlet.
=== Connection.get_interpolate() ===
Returns the value of ``outlet.interpolate`` for this connections
source object and outlet.
=== Connection.get_value(t) ===
Get the value of this connections source object and outlet at time ``t``.
=== Connection.get_event(i) ===
Get the event of this connections source object and outlet at index ``i``.
