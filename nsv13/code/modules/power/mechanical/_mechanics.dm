/// Checks if the selected mechanical part is touching us, only works for connections along the same axis. Do not use after mapload
#define is_connected_cardinal(M) (loc == M.loc || ((x == M.x || y == M.y) && get_dist(src, M) == radius + M.radius))
/*
 * Uses a broader equivalency because irrational figures + floating point numbers is not fun.
 * Ideally we'd use truncation instead but we don't have that yet because byond.
 * This technically means that *massive* gears may fail to connect but that shouldn't matter outside of extreme adminbus
 * This gets called a lot in loops so it's a define to reduce overhead
*/
/// Checks if the selected mechanical part is touching us, accounts for diagonal connections. All post-mapload connection checks should use this. Expensive.
#define is_connected_euclidian(M) (loc == M.loc || ISEQUIVALENT(sqrt((x - M.x)*(x - M.x) + (y - M.y)*(y - M.y)), (radius + M.radius), 0.01))


/obj/structure/mechanical
	name = null
	icon = 'nsv13/icons/obj/machinery/mechanical.dmi'
	anchored = TRUE
	density = TRUE
	obj_flags = CAN_BE_HIT | ON_BLUEPRINTS
	var/damaged = FALSE
	var/rpm = 0
	var/torque = 0
	var/max_rpm = 1000 // max rotations per minute before we start taking damage

	// part radius in meters (tiles).
	// 0.5 should be used for one tile objects
	var/radius = 0.5

/obj/structure/mechanical/Initialize()
	. = ..()
	// could possibly break something in the future idk lol
	// radius * 64 == radius * 2 * 32
	bound_width = round(radius * 64, 32)
	bound_height = round(radius * 64, 32)

/obj/structure/mechanical/proc/locate_flywheel()
	for(var/obj/structure/flywheel/W in GLOB.mechanical)
		if(get_dist(src, W) == W.radius * 2)
			return W
	return FALSE

/obj/structure/mechanical/proc/locate_components()
	return TRUE

/obj/structure/mechanical/proc/check_stress()
	if(rpm > max_rpm)
		overstress()

/// This should always destroy or disable the device when called.
/obj/structure/mechanical/proc/overstress()
	visible_message("<span class='alert'>\The [src] breaks under the stress!</span>")
	qdel(src)


// Basic gear
/obj/structure/mechanical/gear
	name = "plasteel gear"
	desc = "A basic gear used to transfer rotary motion between objects."
	icon_state = "cog1"
	radius = 0.5
	var/datum/gearnet/gearnet
	var/gearnet_ver = 0
	// A 2D list of every gear connected to us and our relative gear ratio
	// Should only be added to via connect()
	var/list/connected = list()

/obj/structure/mechanical/gear/Initialize()
	..()
	GLOB.gears += src
	return INITIALIZE_HINT_LATELOAD

/obj/structure/mechanical/gear/LateInitialize()
	// we handle initial mapload connections in SSMechanics
	if(SSmechanics.initialized)
		update_connections()
		SSmechanics.get_gearnet(src)

/obj/structure/mechanical/gear/Destroy()
	GLOB.gears -= src
	for(var/obj/structure/mechanical/gear/G in connected)
		G.connected -= src
	connected = null
	gearnet?.remove_gear(src)
	return ..()

/obj/structure/mechanical/gear/Moved(atom/OldLoc, Dir)
	. = ..()
	if(OldLoc == loc) // I don't *think* this can happen but just in case
		return
	for(var/obj/structure/mechanical/gear/G as() in connected)
		G.connected -= src
	update_connections()
	SSmechanics.get_gearnet(src)

// setup connection with another gear
/obj/structure/mechanical/gear/proc/connect(obj/structure/mechanical/gear/OG)
	connected[OG] = OG.radius / radius

// Get connected gears, should only be used during mapload, explanation can be found below.
/obj/structure/mechanical/gear/proc/update_mapload_connections()
	for(var/obj/structure/mechanical/gear/G in GLOB.gears)
		if(G == src)
			continue
		if(is_connected_cardinal(G))
			connect(G)

/*
*	Unlike update_mapload_connections, update_connections has to be a catch all as any gear needs to capable of finding it's connected gears on it's own.
*	For example, we only need to use euclidian distance for large gears on mapload because they can modfy the smaller gear's connected list to include themselves (large gear) for them (small gear)
*	However; after mapload, a newly placed small gear wouldn't be able to determine it's connected to a large gear without using euclidian distance
*	So we use seperate the procs, get_connnections() for non-dependent checks post mapload and update_mapload_connections() for more performant checks when large/euclidian checking
*	gears will help
*/
/obj/structure/mechanical/gear/proc/update_connections()
	connected.len = 0
	for(var/obj/structure/mechanical/gear/G in GLOB.gears)
		if(G == src)
			continue
		if(is_connected_euclidian(G)) // the only difference between mapload
			connect(G)

/*
 * Called by gearnets, handles change in the network.
*/
/obj/structure/mechanical/gear/proc/transmission_act(obj/structure/mechanical/gear/caller)
	var/Gratio = caller.radius / radius
	rpm = -caller.rpm * Gratio
	torque = caller.torque / Gratio
	update_animation()

/obj/structure/mechanical/gear/proc/update_animation()
	animate(src)
	if(rpm)
		SpinAnimation(600 / abs(rpm), -1, rpm > 0, 3, FALSE)

/obj/structure/mechanical/gear/vv_edit_var(var_name, var_value)
	. = ..()
	if(. && (var_name == NAMEOF(src, rpm) || var_name == NAMEOF(src, torque))) // don't do this admins. You will probably break something
		update_animation() // I'm stll mad you did it >:(

/obj/structure/mechanical/gear/large
	name = "large plasteel gear"
	desc = "A large gear used to transfer mechanical energy between objects, designed to be conencted diagonally."
	icon_state = "cog2"
	radius = 0.914 // 1 tile diagonal distance (sqrt(2)) - gear radius (0.5) gets you 0.914 after rounding, the radius required for a diagonal connection with a small gear from 1 tile away

// only large gears handle need to get diagonal connections on mapload
/obj/structure/mechanical/gear/large/update_mapload_connections()
	for(var/obj/structure/mechanical/gear/G in GLOB.gears)
		if(G == src)
			continue
		if(is_connected_euclidian(G))
			connect(G)
			G.connect(src)

// Shaftbox



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
	update_connects()

/obj/structure/mechanical/gear/shaftbox/LateInitialize()
	..()
	adapter = new(loc)
	radius = adapter.radius // 1:1

/obj/structure/mechanical/gear/shaftbox/update_connections()
	connections = list(adapter)
	locate_components()

/obj/structure/mechanical/gear/shaftbox/locate_components()
	if(length(transmission_shafts))
		clear_shaftpieces()
	if(!(dir & connects))
		update_connects()
	var/turf/NT = get_step(OT, dir)
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
	if(rpm)
		if(rpm > max_rpm * 0.75)
			nicon = "shaft_wobble"
		else
			// Which icon state number to use. Changes are more noticable at low speeds so I've made the relationship non-linear
			// Unfortunately we're stuck with this until the day BYOND lets us change icon animation speed at runtime
			var/iconstate_index = clamp(floor(0.5 * sqrt(abs(rpm))), 1, 8)
			nicon = "shaft_[iconstate_index]"
	else
		nicon = "shaft_idle"
	var/rotate_dir = SIGN(rpm)
	if(rotate_dir != last_rotate_dir)
		for(var/obj/structure/shaftpiece/SP as() in transmission_shafts)
			SP.icon_state = nicon
			SP.dir = turn(SP.dir, 180)
	if(nicon == last_assigned_icon)
		return
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

/obj/structure/mechanical/gear/shaftbox/proc/update_connects()
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
