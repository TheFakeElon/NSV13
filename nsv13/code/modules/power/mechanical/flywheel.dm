// Only works accurately for disk flywheels of uniform thickness.
#define INERTIAL_CONSTANT 0.5

// Should be set to the largest
#define MAX_FLYWHEEL_RADIUS 1.5

/obj/structure/mechanical/flywheel
	name = "flywheel"
	desc = "An extremely durable, dense disk capable of storing large amounts of kinetic energy"
	icon_state = "flywheel"
	appearance_flags = KEEP_TOGETHER
	pixel_x = -16
	pixel_y = -16
	radius = 1
	// bearing should always be on the same tile as the flywheel
	var/obj/structure/mechanical/bearing/bearing
	var/mass = 100 // mass in kilograms.
	var/angular_mass = 0

	var/loose = FALSE

	var/list/shitlist = list() // Mobs who aren't going to live much longer
	var/mob/shitlist_target

/obj/structure/mechanical/flywheel/Initialize()
	. = ..()
	angular_mass = get_inertia()
	bearing = locate() in loc
	if(bearing)
		footloose(FALSE)

/obj/structure/mechanical/flywheel/proc/get_inertia() // Maths
	return INERTIAL_CONSTANT * mass * (radius * radius)

// returns the total energy stored in the flywheel(s) in joules
/obj/structure/mechanical/flywheel/proc/get_energy()
	return 0.5 * angular_mass * (RPM_TO_RADS(rpm) ** 2)

/obj/structure/mechanical/flywheel/proc/add_energy(joules, safe = FALSE)
	var/rpm_increase = RADS_TO_RPM(sqrt(joules / (angular_mass / 2)))
	rpm += rpm_increase
	if(bearing)
		bearing.rpm = rpm
	return rpm_increase

/obj/structure/mechanical/flywheel/proc/footloose(prewobble = TRUE)
	set waitfor = FALSE
	if(rpm < 30)
		no_more_footloose()
		return
	loose = TRUE
	if(prewobble)
		for(var/i in 1 to rand(3, 5))
			sleep(rand(7, 17))
			playsound(src, 'sound/effects/clang.ogg', 70 + 10 * i, TRUE)
	if(bearing)
		bearing.flywheel = null
		bearing = null
	Move(get_step_rand(src))
	START_PROCESSING(SSobj, src)

/obj/structure/mechanical/flywheel/proc/no_more_footloose()
	visible_message("<span class='danger'>\The [src] tips over!</span>")
	loose = FALSE
	qdel(src)

/obj/structure/mechanical/flywheel/proc/suck_energy(joules)
	var/sucked = min(RADS_TO_RPM(sqrt(joules / (angular_mass / 2))), rpm)
	rpm -= sucked
	return sucked

/obj/structure/mechanical/flywheel/process()
	if(!loose)
		return PROCESS_KILL
	if(rpm < 30)
		no_more_footloose()
	if(length(shitlist))
		if(!shitlist_target)
			var/closest = 130
			for(var/mob/living/M in shitlist)
				if(!M.stat || M.InCritical())
					shitlist -= M
					continue
				if(M.z != z)
					continue
				var/dist = get_dist(src, M)
				if(dist < closest)
					closest = dist
					shitlist_target = M
		else if(!shitlist_target.stat || shitlist_target.z != z)
			shitlist_target = null
		else if(get_dist(src, shitlist_target) >= radius * 2)
			step_towards(src, shitlist_target)
			return
	if(prob(30))
		Move(get_step_rand(src))
	else
		suck_energy(1)

/obj/structure/mechanical/flywheel/Destroy()
	bearing = null
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/structure/mechanical/flywheel/Bump(atom/movable/AM)
	contact(AM)
	return ..()

/obj/structure/mechanical/flywheel/Bumped(atom/movable/AM)
	..()
	contact(AM)

/obj/structure/mechanical/flywheel/proc/contact(atom/movable/AM)
	var/bonk = round(log(rpm) * 10, 1)
	playsound(src, 'sound/effects/clang.ogg', min(bonk, 110), FALSE)
	if(bonk > 25 && iswallturf(AM))
		var/turf/closed/wall/T = AM
		T.devastate_wall()
		suck_energy(7000)
		return
	if(isliving(AM))
		var/mob/living/L = AM
		L.adjustBruteLoss(bonk)
		suck_energy(5000)
	else if(AM.anchored && isobj(AM))
		var/obj/O = AM
		O.take_damage(bonk * 2)
		suck_energy(1000)
		return

	AM?.throw_at(get_edge_target_turf(src, get_dir(src, AM), bonk, bonk / 10))
	suck_energy(1000)

/obj/structure/mechanical/flywheel/small
	name = "small flywheel"
	desc = "An extremely durable and dense disk capable of storing large amounts of kinetic energy. This one is a bit smaller than most."
	icon_state = "flywheel_small"
	pixel_x = 0
	pixel_y = 0
	radius = 0.5
	mass = 50

/obj/structure/mechanical/flywheel/large
	name = "large flywheel"
	desc = "An extremely durable and dense disk capable of storing large amounts of kinetic energy. This one is a bit bulkier than most."
	icon_state = "flywheel_large"
	pixel_x = -32
	pixel_y = -32
	radius = 1.5
	mass = 175

// -------------- BEARINGS -------------------

/obj/structure/mechanical/bearing
	name = "passive magnetic bearing"
	desc = "A sturdy magnetic bearing capable of supporting the mechanical stresses induced by high speed flywheels."
	radius = 0 // Flywheel is placed ontop of this
	max_rpm = 5000
	var/instability = 0
	var/instability_threshold = 5
	var/datum/looping_sound/flywheel/soundloop

	var/obj/structure/mechanical/flywheel/flywheel // connected flywheel, if any

/obj/structure/mechanical/bearing/Initialize()
	. = ..()
	soundloop = new(list(src))

/obj/structure/mechanical/bearing/Destroy()
	if(flywheel)
		if(!flywheel.loose)
			flywheel.footloose()
		flywheel.bearing = null
	STOP_PROCESSING(SSmachines, src)
	QDEL_NULL(soundloop)
	return ..()

/obj/structure/mechanical/bearing/locate_components()
	flywheel = locate() in loc
	return flywheel

/obj/structure/mechanical/bearing/proc/start()
	if(!flywheel && !locate_components())
		return FALSE
	START_PROCESSING(SSmachines, src)
	soundloop.start()
	return TRUE

/obj/structure/mechanical/bearing/process(delta_time)
	if(!flywheel || flywheel.rpm < max_rpm)
		instability = 0
		return PROCESS_KILL

	instability += rand(0.2, 2.5)
	if(instability > instability_threshold)
		var/diff = max(flywheel.rpm - max_rpm, 0)
		if(DT_PROB(1 + instability + log(diff) * 2, delta_time))
			flywheel.footloose()
			overstress()

/obj/structure/mechanical/bearing/overstress()
	qdel(src)
	return TRUE


// -------------- FLYWHEEL MOTORS -------------------
//      (Not to be confused with gear motors)


/obj/structure/mechanical/flywheel_motor
	name = "electric flywheel motor"
	desc = "A high-power motor designed to input kinetic energy into a flywheel"
	icon_state = "fmotor"
	radius = 0.5 // radius of the rotor
	var/max_power = 50000 // max input/output in joules
	var/current_power = 0 // current amount of input
	var/obj/structure/mechanical/flywheel/flywheel // connected flywheel, if any
	var/obj/structure/cable/cable

/obj/structure/mechanical/flywheel_motor/locate_components()
	for(var/obj/structure/mechanical/flywheel/W in oview(MAX_FLYWHEEL_RADIUS * 2, src))
		if(is_connected_euclidian(src, W)) //TODO: get_con_dist for flywheels
			flywheel = W
			return TRUE
	return FALSE

/obj/structure/mechanical/flywheel_motor/process()
	var/turf/T = get_turf(src)
	cable = T.get_cable_node()
	if(!current_power || !flywheel)
		return
	var/drained = min(current_power, cable.surplus(), max_power)
	if(drained)
		cable.add_load(drained)
		flywheel.add_energy(drained * GLOB.CELLRATE) // convert watts to joules

/obj/structure/mechanical/flywheel_motor/examine()
	. = ..()
	if(!cable)
		. += "<span class='notice'>It's not currently connected to a grid.</span>"

/obj/structure/mechanical/flywheel_motor/generator
	name = "electric generator"
	desc = "Converts mechanical energy into electricty"
	icon_state = "fgenerator"
	max_power = 100000

/obj/structure/mechanical/flywheel_motor/generator/process()
	if(!current_power || !cable || !flywheel)
		return
	var/added = min(current_power, flywheel.get_energy(), max_power)
	if(added > 0)
		cable.add_avail(added / GLOB.CELLRATE) // convert joules to watts
		flywheel.suck_energy(added)

#undef INERTIAL_CONSTANT
#undef MAX_FLYWHEEL_RADIUS
