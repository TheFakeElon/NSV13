
/// Component for interfacing between non-mechanical and mechanical objects. Should be attached to the non-mechanical object.
/datum/component/mechanical_interface
	var/atom/movable/patom 	// typecast of parent

	var/rpm
	var/torque
	// Smaller virtual radius = less output rpm, more output torque
	var/virtual_radius				// Used for determining connections in some scans and the gear ratio between us and the mechanical object.

	var/target_type 				// Typepath of valid connections
	var/obj/structure/mechanical/gear/connected

/datum/component/mechanical_interface/Initialize(virtual_radius, target_type = /obj/structure/mechanical/gear)
	patom = parent
	if(!istype(patom))
		CRASH("Invalid parent type [parent.type]. Parent must be a movable atom.")
	src.virtual_radius = virtual_radius
	src.target_type = target_type

/// Scan our tile for a connection
/datum/component/mechanical_interface/proc/scan_loc()
	for(var/obj/structure/mechanical/gear/M in patom.loc)
		if(istype(M, target_type))
			connected = M
			return TRUE
	return FALSE
/*
 * check_dirs = Bitfield of which directions to check
 * valid_target_dirs = Bitfield of valid directions for a found part to have, ignores the part otherwise.
 * All dirs are valid by default
*/
/datum/component/mechanical_interface/proc/scan_adjacent(check_dirs = ALL, valid_target_dirs = ALL)
	for(var/cdir in GLOB.cardinals)
		if(!(cdir & valid_dirs))
			continue
		for(var/obj/structure/mechanical/gear/M in get_step(patom, cdir))
			if((M.dir & valid_target_dirs) && istype(M, target_type))
				connected = M
				return TRUE
	return FALSE

// we're using the same formula as the one in _mechanics.dm
/// Scan for a mechanical part with an intersecting (but not overlapping) radius in a valid dir. Expensive
/datum/component/mechanical_interface/proc/scan_radius(check_dirs = ALL)
	var/dx
	var/dy
	for(var/obj/structure/mechanical/gear/M in oview(virtual_radius * 2, patom))
		if(!istype(M, target_type) || !(get_dir(patom, M) & check_dirs))
			continue
		dx = patom.x - M.x
		dy = patom.y - M.y
		if(ISEQUIVALENT(sqrt(dx*dx + dy*dy), (virtual_radius + M.radius), 0.01))
			connected = M
			return TRUE
	return FALSE

/// Applies our gear state to our connected gear, use this after changing rpm/torque if you want to modify the gearnet
/datum/component/mechanical_interface/proc/apply()
	if(!connected)
		return
	var/gear_ratio = virtual_radius / connected.radius
	if(patom.loc == connected.loc)
		connected.rpm = rpm
		connected.torque = torque
	else
		connected.rpm = rpm / gear_ratio
		connected.torque = torque * gear_ratio

/// Opposite of apply(), This applies the connected gear's state to us.
/datum/component/mechanical_interface/proc/sync()
	if(!connected)
		return
	var/gear_ratio connected.radius / virtual_radius
	if(patom.loc == connected.loc)
		rpm = connected.rpm
		torque = connected.torque
	else
		rpm = connected.rpm / gear_ratio
		torque = connected.torque * gear_ratio
