#define SHAFT_ROTATE_CLOCKWISE 1
#define SHAFT_ROTATE_NONE 0
#define SHAFT_ROTATE_ANTICLOCKWISE -1

// Shaftbox components

/obj/structure/mechanical/gear/shaftbox
	name = "shaft gearbox"
	desc = "A gear box that acts as a bridge between a transmission shaft and a gear network"
	icon_state = "shaftbox"
	var/datum/shaft/shaft
	var/obj/structure/mechanical/gear/shaftbox_adapter/adapter
	var/bidirectional = FALSE // set to true if the shaft can pass through both sides of the shaft box

/obj/structure/mechanical/gear/shaftbox/LateInitialize()
	adapter = new(loc)
	adapter.layer = layer - 0.01
	radius = adapter.radius // 1:1
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
		shaft = new(src)
		shaft.update(FALSE)
	else if(shaft.master == src)
		shaft.update()
	connected += shaft.shaftboxes - src

/obj/structure/mechanical/gear/shaftbox/Destroy()
	if(!QDELETED(adapter))
		qdel(adapter)
	adapter = null
	if(shaft)
		shaft.shaftboxes -= src
		shaft = null
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
	if(SSmechanics.initialized && !shaft)
		find_shaftbox()

/obj/structure/shaftpiece/proc/find_shaftbox()
	var/valid_con_dirs
	if(dir & (NORTH | SOUTH))
		valid_con_dirs = NORTH | SOUTH
	else
		valid_con_dirs = EAST | WEST

	var/turf/NT = get_turf(src)
	for(var/direction in GLOB.cardinals)
		if(!(direction & valid_con_dirs))
			continue
		NT = get_step(src, direction)
		for(var/obj/structure/mechanical/gear/shaftbox/SB in NT)
			if(SB.shaft && (dir & SB.shaft.axis.valid))
				SB.shaft.update(TRUE)
				return
		for(var/obj/structure/shaftpiece/SP in NT)
			if(SP.shaft && (dir & SP.shaft.axis.valid))
				SP.shaft.update(TRUE)
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

			for(var/obj/structure/shaftpiece/SP in NT)
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
	for(var/obj/structure/shaftpiece/SP as() in shaft_pieces)
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
			var/iconstate_index = clamp(round(0.5 * sqrt(abs(master.rpm))), 1, 8)
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
		for(var/obj/structure/shaftpiece/SP as() in shaft_pieces)
			SP.icon_state = nicon
			SP.dir = new_shaft_dir
		last_rotate_dir = rotate_dir
		last_assigned_icon = nicon
	// if the rotation direction hasn't changed, we'll just check to see if we need to change the icon state
	else if(nicon != last_assigned_icon)
		for(var/obj/structure/shaftpiece/SP as() in shaft_pieces)
			SP.icon_state = nicon
		last_assigned_icon = nicon

/datum/shaft/proc/find_master()
	if(!length(shaftboxes))
		QDEL_IN(src, 0)
		return FALSE
	master = shaftboxes[1]
	axis.align(master)
	return TRUE

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
