#define SHAFT_ROTATE_CLOCKWISE 1
#define SHAFT_ROTATE_NONE 0
#define SHAFT_ROTATE_ANTICLOCKWISE -1

// Shaftbox components

/obj/structure/mechanical/gear/shaftbox
	name = "shaft gearbox"
	desc = "A gear box that acts as a bridge between a transmission shaft and a gear network"
	var/obj/structure/mechanical/gear/shaftbox_adapter/adapter
	var/list/transmission_shafts = list() // list of all the transmission shaft pieces
	var/last_assigned_icon // the last icon state we assigned to our transmission shafts
	var/last_rotate_dir = 0 // last rotation direction (relative). -1 for clockwise, 0 for none, 1 for clockwise
	var/connects // bitfield of valid shaft piece directions

/obj/structure/mechanical/gear/shaftbox/Initialize()
	. = ..()
	update_connect_dir()

/obj/structure/mechanical/gear/shaftbox/LateInitialize()
	adapter = new(loc)
	radius = adapter.radius // 1:1
	..()

/obj/structure/mechanical/gear/shaftbox/update_connections()
	connected = list(adapter)
	locate_components()

/obj/structure/mechanical/gear/shaftbox/locate_components()
	if(length(transmission_shafts))
		clear_shaftpieces()
	if(!(dir & connects))
		update_connect_dir()
	var/turf/NT = get_step(src, dir)
	var/obj/structure/shaftpiece/SP = locate() in NT
	while(SP)
		if(QDELING(SP) || !(SP.dir & connects))
			SP = null
			continue
		add_shaftpiece(SP)
		NT = get_step(NT, dir)
		SP = locate() in NT
	// check for a shaftbox at the end of the transmission shaft
	var/obj/structure/mechanical/gear/shaftbox/connected_shaftbox = locate() in NT
	if(connected_shaftbox)
		connected += connected_shaftbox

/obj/structure/mechanical/gear/shaftbox/update_animation()
	if(!length(transmission_shafts))
		return
	var/nicon
	var/rotate_dir
	if(rpm)
		rotate_dir = SIGN(rpm)
		if(rpm > max_rpm * 0.75)
			nicon = "shaft_wobble"
		else
			// Which icon state number to use. Changes are more noticable at low speeds so I've made the relationship non-linear
			// Unfortunately we're stuck with this until the day BYOND lets us change icon animation speed at runtime
			var/iconstate_index = clamp(round(0.5 * sqrt(abs(rpm))), 1, 8)
			nicon = "shaft_[iconstate_index]"
	else
		nicon = "shaft_idle"
		rotate_dir = 0
	// if we've inverted our rotation direction, we need to flip all of the shaft icons.
	// we'll update the icon state while we're at it
	if(rotate_dir != last_rotate_dir && rotate_dir != 0)
		var/new_shaft_dir
		if(rotate_dir == 1)
			new_shaft_dir = dir
		else
			new_shaft_dir = turn(dir, 180)
		for(var/obj/structure/shaftpiece/SP as() in transmission_shafts)
			SP.icon_state = nicon
			SP.dir = new_shaft_dir
		last_rotate_dir = rotate_dir
		last_assigned_icon = nicon
	// if the rotation direction hasn't changed, we'll just check to see if we need to change the icon state
	else if(nicon != last_assigned_icon)
		for(var/obj/structure/shaftpiece/SP as() in transmission_shafts)
			SP.icon_state = nicon
		last_assigned_icon = nicon

/obj/structure/mechanical/gear/shaftbox/proc/add_shaftpiece(obj/effect/shaftpiece/SP)
	RegisterSignal(SP, list(COMSIG_MOVABLE_MOVED, COMSIG_PARENT_QDELETING), .proc/remove_shaftpiece)
	transmission_shafts += SP

/obj/structure/mechanical/gear/shaftbox/proc/remove_shaftpiece(obj/effect/shaftpiece/SP)
	SIGNAL_HANDLER
	UnregisterSignal(SP, list(COMSIG_MOVABLE_MOVED, COMSIG_PARENT_QDELETING))
	locate_components()

/obj/structure/mechanical/gear/shaftbox/proc/clear_shaftpieces()
	for(var/obj/structure/shaftpiece/SP as() in transmission_shafts)
		UnregisterSignal(SP, list(COMSIG_MOVABLE_MOVED, COMSIG_PARENT_QDELETING))
		SP.icon_state = "shaft_idle"
	transmission_shafts.len = 0

/obj/structure/mechanical/gear/shaftbox/proc/update_connect_dir()
	if(dir & (NORTH|SOUTH))
		connects = NORTH | SOUTH
	else
		connects = EAST | WEST


/obj/structure/shaftpiece
	name = "transmission shaft"
	desc = "Moves kinetic energy along a linear axis."
	icon = 'nsv13/icons/obj/machinery/shaft.dmi'
	icon_state = "shaft_idle"
	layer = ABOVE_OBJ_LAYER


// The bevel adapter between normal gears and the shaft gear box.
// Created by the shaft gearbox on spawn.
/obj/structure/mechanical/gear/shaftbox_adapter
	name = "gear adapter"
	desc = "An adapter that connects gearwheels to the shaft gearbox"
	var/obj/structure/mechanical/gear/shaftbox/shaftbox

/obj/structure/mechanical/gear/shaftbox/LateInitialize()
	shaftbox = locate() in loc
	if(!shaftbox)
		qdel(src)
		return
	..()

/obj/structure/mechanical/gear/shaftbox_adapter/update_connections()
	..()
	var/rel_dir
	// We can't connect to normal gears on the gearbox side
	for(var/obj/structure/mechanical/gear/G as() in connected)
		rel_dir = get_dir(src, G)
		if(rel_dir & dir)
			connected  -= G
	shaftbox = locate() in loc
	if(!shaftbox)
		qdel(src)
		return
	connect(shaftbox)

#undef SHAFT_ROTATE_CLOCKWISE
#undef SHAFT_ROTATE_NONE
#undef SHAFT_ROTATE_ANTICLOCKWISE
