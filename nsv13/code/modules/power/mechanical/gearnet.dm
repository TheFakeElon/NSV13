/datum/gearnet
	var/id // Unique ID
	var/static/num = 0 // amount of gearnets that have been created since initialization.
	var/list/gears = list() // all gears in this gearnet
	var/version = 0 // Increments by 1 every time the gear network is updated

/datum/gearnet/New()
	num++
	id = num
	SSmechanics.gearnets += src

/datum/gearnet/Destroy()
	for(var/obj/structure/mechanical/gear/G as() in gears)
		G.gearnet = null
	SSmechanics.gearnets -= src
	return ..()

/datum/gearnet/proc/add_gear(obj/structure/mechanical/gear/G)
	if(G.gearnet)
		if(G.gearnet == src)
			return
		else
			// remove gear from other gearnet
			G.gearnet.remove_gear(G)
	G.gearnet = src
	G.gearnet_ver = version
	gears += G

/datum/gearnet/proc/remove_gear(obj/structure/mechanical/gear/G)
	gears -= G
	G.gearnet = null
	if(!length(gears))
		qdel(src)

// Recursively propeagate gear network through starting gear (IG)
/datum/gearnet/proc/propagate_network(obj/structure/mechanical/gear/IG, mapload)
	var/list/worklist = list(IG) //start propagating from the passed object
	var/wklen = length(worklist)
	var/obj/structure/mechanical/gear/gear
	while(wklen)

		gear = worklist[wklen]
		worklist.len--
		if(gear.gearnet == src)
			wklen = length(worklist)
			continue

		add_gear(gear)
		if(mapload)
			gear.update_mapload_connections()
		else
			gear.update_connections()

		for(var/obj/structure/mechanical/gear/CG as() in gear.connected)
			if(CG.gearnet != src)
				worklist += CG
		wklen = length(worklist)
		CHECK_TICK

/datum/gearnet/proc/update_network(obj/structure/mechanical/gear/source)
	version++
	var/list/worklist = list()
	// iterating because we only want the keys from the 2D list
	for(var/obj/structure/mechanical/gear/SG as() in source.connected)
		worklist += SG

	var/wklen = length(worklist)
	var/obj/structure/mechanical/gear/gear
	while(wklen)
		gear = worklist[wklen]
		worklist.len--
		if(gear.gearnet_ver == version)
			wklen = length(worklist)
			continue
		for(var/obj/structure/mechanical/gear/CG as() in gear.connected)
			if(CG.gearnet_ver != version)
				worklist += CG
				CG.transmission_act(gear)
		wklen = length(worklist)
		CHECK_TICK

/*
//Merge two gearnets, the bigger (in gear length term) absorbing the other
/proc/merge_gearnets(datum/gearnet/net1, datum/gearnet/net2)
	if(!net1 || !net2) //if one of the gearnet doesn't exist, return
		return

	if(net1 == net2) //don't merge same gearnets
		return

	//We assume net1 is larger. If net2 is in fact larger we are just going to make them switch places to reduce on code.
	if(length(net1.gears) < length(net2.gears))	//net2 is larger than net1. Let's switch them around
		var/temp = net1
		net1 = net2
		net2 = temp
	//merge net2 into net1
	for(var/obj/structure/mechanical/M as() in net2.gears) //merge cables
		net1.add_gear(M)
/*
	for(var/obj/structure/mechanical/M as() in net2.machines) //merge power machines
		if(!M.locate_components())
			M.gearnet = null //if somehow we can't connect the machine to the new gearnet, disconnect it from the old nonetheless
*/

	return net1
*/
