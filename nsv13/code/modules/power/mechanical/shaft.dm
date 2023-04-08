#define SHAFT_ROTATE_CLOCKWISE 1
#define SHAFT_ROTATE_NONE 0
#define SHAFT_ROTATE_ANTICLOCKWISE -1

// Shaftbox components

/obj/structure/mechanical/gear/shaftbox
	name = "shaft gearbox"
	desc = "A gear box that acts as a bridge between a transmission shaft and a gear network"
	icon_state = "shaftbox"
	var/master = TRUE // are we the master shaftbox? The master shaftbox is the one in charge of updating the shaft states
	var/obj/structure/mechanical/gear/shaftbox_adapter/adapter
	var/list/transmission_shafts = list() // list of all the transmission shaft pieces
	var/last_assigned_icon = "shaft_idle" // the last icon state we assigned to our transmission shafts
	var/last_rotate_dir = 0 // last rotation direction (relative). Either clockwise, none or anticlockwise
	var/connects // bitfield of valid shaft piece directions

/obj/structure/mechanical/gear/shaftbox/Initialize()
	. = ..()
	update_connect_dir()

/obj/structure/mechanical/gear/shaftbox/LateInitialize()
	adapter = new(loc)
	adapter.layer = layer - 0.01
	radius = adapter.radius // 1:1
	..()

// we don't connect to normal gears, only our adapter and other shaft boxes
/obj/structure/mechanical/gear/shaftbox/can_connect(obj/structure/mechanical/gear/OG)
	return OG == adapter || istype(OG, /obj/structure/mechanical/gear/shaftbox)

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
		if(master)
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
		rotate_dir = SHAFT_ROTATE_NONE
	// if we've inverted our rotation direction, we need to flip all of the shaft icons.
	// we'll update the icon state while we're at it
	if(rotate_dir != last_rotate_dir && rotate_dir != SHAFT_ROTATE_NONE)
		var/new_shaft_dir
		if(rotate_dir == SHAFT_ROTATE_ANTICLOCKWISE)
			new_shaft_dir = turn(dir, 180)
		else
			new_shaft_dir = dir
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

/obj/structure/mechanical/gear/shaftbox/proc/resolve_master(obj/structure/mechanical/gear/shaftbox/OSB)
	// if they aren't master, we'll be master
	if(!OSB.master)
		master = TRUE
		return
	// if we aren't master, they'll be master
	if(!master)
		OSB.master = TRUE
		return
	// if we both want to be master, we will DUEL. Whoever has the most shaftpieces wins, if it's the same, we win
	if(length(transmission_shafts) >= length(OSB.transmission_shafts))
		OSB.master = FALSE
		OSB.clear_shaftpieces()
	else
		master = FALSE
		clear_shaftpieces()


/obj/structure/mechanical/gear/shaftbox/proc/update_connect_dir()
	if(dir & (NORTH|SOUTH))
		connects = NORTH | SOUTH
	else
		connects = EAST | WEST

/obj/structure/mechanical/gear/shaftbox/Destroy()
	if(!QDELETED(adapter))
		qdel(adapter)
	adapter = null
	transmission_shafts = null
	return ..()

/obj/structure/shaftpiece
	name = "transmission shaft"
	desc = "Moves kinetic energy along a linear axis."
	icon = 'nsv13/icons/obj/machinery/shaft.dmi'
	icon_state = "shaft_idle"
	layer = ABOVE_OBJ_LAYER
	var/datum/shaft/shaft

/obj/structure/shaftpiece/Initialize()
	..()
	return INITIALIZE_HINT_LATELOAD

/obj/structure/shaftpiece/LateInitialize()
	if(SSmechanics.initialized)
		find_shaftbox()

/obj/structure/shaftpiece/proc/find_shaftbox()
	var/valid_con_dirs
	if(dir & (NORTH | SOUTH))
		valid_con_dirs = NORTH | SOUTH
	else
		valid_con_dirs = EAST | WEST

	var/obj/structure/shaftpiece/OSP
	var/obj/structure/mechanical/gear/shaftbox/SB
	var/turf/NT = get_turf(src)
	for(var/direction in GLOB.cardinals)
		if(!(direction & valid_con_dirs))
			continue
		NT = get_step(src, direction)

		SB = locate() in NT
		if(SB?.shaft)
			SB.shaft.add_shaftpiece(src)
			return
		OSP = locate() in NT
		if(OSP?.shaft)
			OSP.shaft.add_shaftpiece(src)
			return

/obj/structure/shaftpiece/proc/join_shaftbox(obj/structure/mechanical/gear/shaftbox/SB)
	if(SB.master)
		SB.locate_components()
		return
	for(var/obj/structure/mechanical/gear/shaftbox/OSB in SB.connected)
		if(OSB.master)
			OSB.locate_components()
			return

// The bevel adapter between normal gears and the shaft gear box.
// Created by the shaft gearbox on spawn.
/obj/structure/mechanical/gear/shaftbox_adapter
	name = "gear adapter"
	desc = "An adapter that connects gearwheels to the shaft gearbox"
	icon_state = "adapter"
	var/obj/structure/mechanical/gear/shaftbox/shaftbox

/obj/structure/mechanical/gear/shaftbox_adapter/LateInitialize()
	shaftbox = locate() in loc
	if(!shaftbox)
		qdel(src)
		return
	dir = turn(shaftbox.dir, 180)
	..()

/obj/structure/mechanical/gear/shaftbox_adapter/update_connections()
	..()
	var/rel_dir
	// We can only connect to gears roughly infront of us
	for(var/obj/structure/mechanical/gear/G as() in connected)
		rel_dir = get_dir(src, G)
		if(rel_dir & dir)
			continue
		connected -= G
	shaftbox = locate() in loc
	if(!shaftbox)
		QDEL_IN(src, 0) // QDEL_IN because we don't want to kill ourselves while the subsystem is enumerating over us
		return
	connect(shaftbox)

/obj/structure/mechanical/gear/shaftbox_adapter/Destroy()
	if(!QDELETED(shaftbox))
		qdel(shaftbox)
	shaftbox = null
	return ..()


/datum/shaft
	var/list/shaftboxes = list()
	var/list/shaft_pieces = list()

/datum/shaft/

/datum/shaft/proc/add_shaftpiece(obj/structure/shaftpiece/SP)
	RegisterSignal(SP, list(COMSIG_MOVABLE_MOVED, COMSIG_PARENT_QDELETING), .proc/remove_shaftpiece)
	SP.icon_state = last_assigned_icon
	if(last_rotate_dir == SHAFT_ROTATE_ANTICLOCKWISE)
		SP.dir = turn(dir, 180)
	else
		SP.dir = dir
	transmission_shafts += SP

/datum/shaft/proc/remove_shaftpiece(obj/structure/shaftpiece/SP)
	SIGNAL_HANDLER
	UnregisterSignal(SP, list(COMSIG_MOVABLE_MOVED, COMSIG_PARENT_QDELETING))
	locate_components()

/datum/shaft/proc/clear_shaftpieces(reset_istate = TRUE)
	if(reset_istate)
		for(var/obj/structure/shaftpiece/SP as() in transmission_shafts)
			UnregisterSignal(SP, list(COMSIG_MOVABLE_MOVED, COMSIG_PARENT_QDELETING))
			SP.icon_state = "shaft_idle"
	else
		for(var/obj/structure/shaftpiece/SP as() in transmission_shafts)
			UnregisterSignal(SP, list(COMSIG_MOVABLE_MOVED, COMSIG_PARENT_QDELETING))
	transmission_shafts.len = 0

#undef SHAFT_ROTATE_CLOCKWISE
#undef SHAFT_ROTATE_NONE
#undef SHAFT_ROTATE_ANTICLOCKWISE
