#define SHAFT_ROTATE_CLOCKWISE 1
#define SHAFT_ROTATE_NONE 0
#define SHAFT_ROTATE_ANTICLOCKWISE -1
// Max iconstate number in the shaftpiece dmi
#define SHAFTPIECE_ICONSTATE_MAX 8

// Locates any valid shafts we can connect to, returns shaft datum if found.
// Takes a bitfield of valid connection directions.
/obj/structure/mechanical/proc/find_shaft(dirs)
	var/turf/NT = get_turf(src)
	for(var/direction in GLOB.cardinals)
		if(!(direction & dirs))
			continue
		NT = get_step(src, direction)
		for(var/obj/structure/mechanical/gear/shaftbox/SB in NT)
			if(SB.shaft && (dir & SB.shaft.axis.valid))
				return SB.shaft
		for(var/obj/structure/mechanical/shaftpiece/SP in NT)
			if(SP.shaft && (dir & SP.shaft.axis.valid))
				return SP.shaft
	return null


// ------------ Shaft box ------------


/obj/structure/mechanical/gear/shaftbox
	name = "shaft gearbox"
	desc = "A gear box that acts as a bridge between a transmission shaft and a gear network"
	icon_state = "shaftbox"
	var/datum/shaft/shaft
	var/obj/structure/mechanical/gear/shaftbox_adapter/adapter
	var/bidirectional = FALSE // set to true if the shaft can pass through both sides of the shaft box

/obj/structure/mechanical/gear/shaftbox/LateInitialize()
	adapter = locate() in loc
	if(!adapter)
		adapter = new(loc)
	adapter.layer = layer - 0.01
	//radius = adapter.radius // 1:1
	RegisterSignal(adapter, COMSIG_ATOM_DIR_CHANGE, .proc/dir_change)
	RegisterSignal(src, COMSIG_ATOM_DIR_CHANGE, .proc/dir_change)
	..()

// we don't connect to normal gears, only our adapter and other shaft boxes
/obj/structure/mechanical/gear/shaftbox/can_connect(obj/structure/mechanical/gear/OG)
	return OG.loc == loc || istype(OG, /obj/structure/mechanical/gear/shaftbox)

/obj/structure/mechanical/gear/shaftbox/update_connections()
	connected = list(adapter)
	locate_components()

/obj/structure/mechanical/gear/shaftbox/update_animation()
	if(!shaft)
		return
	if(shaft.master == src)
		shaft.update_animation()

/obj/structure/mechanical/gear/shaftbox/locate_components()
	if(!shaft)
		// if we're bidirectional, scan behind us too
		var/datum/shaft/oshaft = find_shaft(bidirectional ? (dir | turn(dir, 180)) : dir)
		oshaft?.update()
		if(!shaft)
			shaft = new(src)
			shaft.update(FALSE)
	else if(shaft.master == src) // we wouldn't be master if we located an existing shaft, and we would have already updated if we just made one.
		shaft.update()
	for(var/obj/structure/mechanical/gear/shaftbox/SB as() in shaft.shaftboxes)
		if(SB != src)
			connect(SB)

/obj/structure/mechanical/gear/shaftbox/Moved(atom/OldLoc, Dir)
	. = ..()
	if(adapter?.loc != loc)
		adapter.forceMove(loc)
	update_connections()

/obj/structure/mechanical/gear/shaftbox/proc/dir_change()
	SIGNAL_HANDLER
	if(!adapter)
		return
	adapter.dir = turn(dir, 180)
	if(shaft?.master == src)
		shaft.axis.align(src)
	update_connections()

/obj/structure/mechanical/gear/shaftbox/Destroy()
	if(!QDELETED(adapter))
		qdel(adapter)
	adapter = null
	shaft?.remove_shaftbox(src)
	shaft = null
	return ..()


// ------------ Shaft box adapters ------------

// The bevel adapter between normal gears and the shaft gear box. Created by the shaft gearbox on spawn.
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
	setDir(turn(shaftbox.dir, 180))
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


// ------------ Shaft pieces ------------


/obj/structure/mechanical/shaftpiece
	name = "transmission shaft"
	desc = "Moves kinetic energy along a linear axis."
	icon = 'nsv13/icons/obj/machinery/shaft.dmi'
	icon_state = "shaft_idle"
	layer = ABOVE_OBJ_LAYER
	var/datum/shaft/shaft

/obj/structure/mechanical/shaftpiece/Initialize()
	..()
	return INITIALIZE_HINT_LATELOAD

/obj/structure/mechanical/shaftpiece/LateInitialize()
	if(SSmechanics.initialized && !shaft)
		var/datum/shaft/oshaft = find_shaft(dir | turn(dir, 180))
		oshaft?.update()

/obj/structure/mechanical/shaftpiece/Destroy()
	shaft?.remove_shaftpiece(src)
	shaft = null
	return ..()

// ------------ Shaft datum ------------


/datum/shaft
	var/obj/structure/mechanical/gear/shaftbox/master
	var/datum/axis/axis // bitfield of the two dirs that make up the axis. i.e NORTH | SOUTH or EAST | WEST
	var/list/shaftboxes = list()
	var/list/shaft_pieces = list()

	var/last_rotate_dir = SHAFT_ROTATE_NONE // last rotation direction (relative to NORTH). Either clockwise, none or anticlockwise
	var/last_assigned_icon = "shaft_idle"

/datum/shaft/New(obj/structure/mechanical/gear/shaftbox/SB)
	master = SB
	shaftboxes += SB
	axis = new()
	axis.align(master)

/datum/shaft/proc/update(reset = TRUE)
	if(!master && !find_master())
		return
	if(reset)
		reset()
	var/turf/NT = master.loc
	if(!istype(NT))
		return
	var/list/shaft_dirs = list(axis.forward)
	if(master.bidirectional)
		shaft_dirs += axis.back
	var/found = TRUE // have we found a shaft piece/box?
	for(var/direction in shaft_dirs)
		NT = master.loc
		// will keep stepping until we reach the end of the shaft
		while(found)
			found = FALSE
			NT = get_step(NT, direction) // take the next step across this axis
			for(var/obj/structure/mechanical/gear/shaftbox/SB in NT)
				if(SB.dir & axis.valid)
					if(SB.shaft != src)
						shaftboxes += SB
						SB.shaft = src
					found = TRUE

			for(var/obj/structure/mechanical/shaftpiece/SP in NT)
				if(SP.dir & axis.valid)
					if(SP.shaft != src)
						shaft_pieces += SP
						SP.shaft = src
					found = TRUE

/datum/shaft/proc/reset()
	for(var/obj/structure/mechanical/gear/shaftbox/SB as() in shaftboxes)
		SB.shaft = null
	shaftboxes.len = 0
	if(master)
		shaftboxes = list(master)
		master.shaft = src
	for(var/obj/structure/mechanical/shaftpiece/SP as() in shaft_pieces)
		SP.icon_state = "shaft_idle"
		SP.shaft = null
	shaft_pieces.len = 0

/datum/shaft/proc/update_animation()
	if(!length(shaft_pieces))
		return
	var/nicon
	var/rotate_dir
	if(master.rpm)
		rotate_dir = SIGN(master.rpm)
		if(master.rpm > master.max_rpm * 0.75)
			nicon = "shaft_wobble"
		else
			// Which icon state number to use. Changes are more noticable at low speeds so I've made the relationship non-linear
			// Unfortunately we're stuck with this until the day BYOND lets us change icon animation speed at runtime
			var/iconstate_index = clamp(round(0.5 * sqrt(abs(master.rpm))), 1, SHAFTPIECE_ICONSTATE_MAX)
			nicon = "shaft_[iconstate_index]"
	else
		nicon = "shaft_idle"
		rotate_dir = SHAFT_ROTATE_NONE
	// if we've inverted our rotation direction, we need to flip all of the shaft icons.
	// we'll update the icon state while we're at it
	if(rotate_dir != last_rotate_dir && rotate_dir != SHAFT_ROTATE_NONE)
		var/new_shaft_dir
		if(rotate_dir == SHAFT_ROTATE_ANTICLOCKWISE)
			new_shaft_dir = axis.back
		else
			new_shaft_dir = axis.forward
		for(var/obj/structure/mechanical/shaftpiece/SP as() in shaft_pieces)
			SP.icon_state = nicon
			SP.dir = new_shaft_dir
		last_rotate_dir = rotate_dir
		last_assigned_icon = nicon
	// if the rotation direction hasn't changed, we'll just check to see if we need to change the icon state
	else if(nicon != last_assigned_icon)
		for(var/obj/structure/mechanical/shaftpiece/SP as() in shaft_pieces)
			SP.icon_state = nicon
		last_assigned_icon = nicon

/datum/shaft/proc/find_master()
	if(!length(shaftboxes))
		reset()
		QDEL_IN(src, 0)
		return FALSE
	master = shaftboxes[1]
	axis.align(master)
	return TRUE

/datum/shaft/proc/remove_shaftbox(obj/structure/mechanical/gear/shaftbox/SB)
	shaftboxes -= SB
	SB.shaft = null // we should be nulling on SB's side too, just in case something weird happens.
	if(master == SB && find_master())
		update()

/datum/shaft/proc/remove_shaftpiece(obj/structure/mechanical/shaftpiece/SP)
	shaft_pieces -= SP
	SP.shaft = null
	update()

/datum/shaft/Destroy()
	reset()
	shaftboxes.len = 0 // because master is re-added in reset()
	master = null
	QDEL_NULL(axis)
	return ..()

/datum/axis
	var/forward // facing away from the source
	var/back // facing towards the source
	var/valid // bitfield of valid dirs across axis. i.e for an axis facing north, the valid dirs would be NORTH | SOUTH

/datum/axis/proc/align(atom/A)
	forward = A.dir
	back = turn(A.dir, 180)
	valid = forward | back

#undef SHAFT_ROTATE_CLOCKWISE
#undef SHAFT_ROTATE_NONE
#undef SHAFT_ROTATE_ANTICLOCKWISE

#undef SHAFTPIECE_ICONSTATE_MAX
