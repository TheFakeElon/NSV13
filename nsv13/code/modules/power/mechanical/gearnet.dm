/datum/gearnet
	var/id // Unique ID
	var/static/num = 0 // amount of gearnets that have been created
	var/list/gears = list()

/datum/gearnet/New()
	num++
	id = num
	SSmechanics.gearnets += src

/datum/gearnet/Destroy()
	for(var/obj/structure/mechanical/gear/G in gears)
		G.gearnet = null
	gears = null
	SSmechanics.gearnets.Remove(src)
	return ..()

/datum/gearnet/proc/add_gear(obj/structure/mechanical/gear/G, index)
	if(G.gearnet)
		if(G.gearnet == src)
			return
		else
			G.gearnet.remove_gear(G)
	G.gearnet = src
	if(index)
		gears[index] = G
	else
		gears.Add(G)

/datum/gearnet/proc/remove_gear(obj/structure/mechanical/gear/G)
	gears.Remove(G)
	G.gearnet = null
	if(!gears.len)
		qdel(src)

// Mostly modified gearnet code
//remove the old gearnet and replace it with a new one throughout the network.
/proc/propagate_gear_network(obj/O, datum/gearnet/GN)
	var/list/worklist = list(O) //start propagating from the passed object
	var/index = 1
	var/obj/P = null

	while(index <= worklist.len) //until we've exhausted all gear objects
		P = worklist[index] //get the next gear object found

		if(istype(P, /obj/structure/mechanical/gear))
			var/obj/structure/mechanical/gear/M = P
			if(M.gearnet != GN) //add it to the gearnet, if it isn't already there
				GN.add_gear(M, index)
			worklist |= M.get_connections() //get adjacents gear objects, with or without a gearnet

		index++
/*
		else if(M.anchored)
			found_machines |= P

		else
			continue



	//now that the gearnet is set, connect found machines to it
	for(var/obj/structure/mechanical/M as() in found_machines)
		if(!M.locate_components()) //couldn't find a node on its turf...
			M.gearnet = null //... so disconnect if already on a gearnet

*/


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
