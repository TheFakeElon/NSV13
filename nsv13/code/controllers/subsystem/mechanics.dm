// Similar to SSmachinery powernet but exclusively handles gear networks.
// This avoids loading any expensive bloat on the main machinery subsystem.
SUBSYSTEM_DEF(mechanics)
	name = "Mechanics"
	init_order = INIT_ORDER_MECHANICS
	flags = SS_KEEP_TIMING
	wait = 2 SECONDS
	var/list/updatequeue = list()
	var/list/currentrun = list()
	var/list/gearnets = list()

/datum/controller/subsystem/mechanics/Initialize(start_timeofday)
	Initialize_gearnets()
	fire()
	return ..()

/datum/controller/subsystem/mechanics/proc/Initialize_gearnets()
	QDEL_LIST(gearnets)
	gearnets.len = 0
	for(var/obj/structure/mechanical/gear/M in GLOB.gears)
		if(!M.gearnet) // If it's been hit by a propagation it'll have a gearnet
			var/datum/gearnet/newGN = new()
			newGN.propagate_network(M, TRUE)

/datum/controller/subsystem/mechanics/stat_entry()
	return ..("CR:[length(currentrun)]|GN:[length(gearnets)]")

/datum/controller/subsystem/mechanics/fire(resumed = 0)
	if(!resumed)
		currentrun = updatequeue.Copy()

	while(length(currentrun))
		var/obj/structure/mechanical/gear/GR = currentrun[length(currentrun)]
		currentrun.len--
		if(QDELETED(GR))
			continue
		GR.gearnet?.update_network(GR)
		CHECK_TICK


// Add a gear (and it's respective gearnet) to the update queue
/datum/controller/subsystem/mechanics/proc/queue_update(obj/structure/mechanical/gear/GR)
	updatequeue -= GR // if we're already in the queue, move our position. We don't want duplicates
	updatequeue += GR

// Update gearnet immediately
/datum/controller/subsystem/mechanics/proc/update(obj/structure/mechanical/gear/GR)
	updatequeue -= GR
	GR.gearnet?.update_network(GR)

// Finds/creates/rebuilds gearnet for a gear. Should only be called after connections have been calculated.
/datum/controller/subsystem/mechanics/proc/get_gearnet(obj/structure/mechanical/gear/GR)
	var/datum/gearnet/newGN
	if(!length(GR.connected))
		newGN = new()
		newGN.add_gear(GR)
		return
	var/list/found_gearnets = list()
	for(var/obj/structure/mechanical/gear/CG as() in GR.connected)
		if(CG.gearnet)
			found_gearnets |= CG.gearnet
	// if we found no gearnets in our connections, build one ourselves
	if(!length(found_gearnets))
		newGN = new()
		newGN.propagate_network(GR, FALSE)
		return
	// if we only found one gearnet, join it
	if(length(found_gearnets) == 1)
		newGN = found_gearnets[1]
		newGN.add_gear(src)
	else // if we found multiple, we gotta do some reconstruction and join two together
		newGN = join_gearnets(found_gearnets)
		newGN.add_gear(GR)


// Combines 2 or more gearnets into one, returns the new gearnet
/datum/controller/subsystem/mechanics/proc/join_gearnets(list/gearnets_to_join)
	var/datum/gearnet/largest_GN
	var/top_gear_amt = 0
	for(var/datum/gearnet/GN as() in gearnets_to_join)
		var/glen = length(GN.gears)
		if(glen > top_gear_amt)
			top_gear_amt = glen
			largest_GN = GN

	var/list/smaller = gearnets_to_join.Copy() - largest_GN
	for(var/datum/gearnet/GN as() in smaller)
		for(var/obj/structure/mechanical/gear/gear in GN.gears)
			gear.gearnet = largest_GN
			gear.gearnet_ver = largest_GN.version
			largest_GN += gear
		GN.gears = null
		qdel(GN)
	return largest_GN




/datum/controller/subsystem/mechanics/Recover()
	if(istype(SSmechanics.gearnets))
		gearnets = SSmechanics.gearnets
