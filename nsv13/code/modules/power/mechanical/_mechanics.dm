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
