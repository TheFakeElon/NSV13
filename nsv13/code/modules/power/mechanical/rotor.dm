// -------------- MECHANICAL MOTORS -------------------
//   --------- (Gear powering motors) --------------

/obj/structure/mechanical/gear/powered
	name = null
	var/current_power = 0
	var/max_power = 50000
	var/efficiency = 0.95
	var/obj/structure/cable/cable

	var/last_power = 0
	var/last_rpm = 0

/obj/structure/mechanical/gear/powered/Initialize()
	. = ..()
	START_PROCESSING(SSobj, src)

/obj/structure/mechanical/gear/powered/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/structure/mechanical/gear/powered/process()
	if(!current_power)
		return
	var/turf/T = loc
	cable = T.get_cable_node()
	if(!cable)
		current_power = 0
		return
	while(current_power > cable.delayed_surplus())
		current_power -= clamp(round(current_power * 0.25), 5000, current_power)
	cable.add_delayedload(current_power)

/obj/structure/mechanical/gear/powered/motor
	name = "electric motor"
	desc = "An industrial grade electric motor. Converts electrical energy into torque."
	icon_state = "motor"
	radius = 0.5

/obj/structure/mechanical/gear/powered/motor/process()
	if(last_power == current_power && last_rpm == rpm)
		return
	torque = CALC_TORQUE(current_power * efficiency, rpm)
	for(var/obj/structure/mechanical/gear/G in connected)
		G.transmission_act(src, list(src))

	last_power = current_power
	last_rpm = rpm

// unsynchronized motors will break
/obj/structure/mechanical/gear/powered/motor/transmission_act(obj/structure/mechanical/gear/caller, list/called)
	if(torque * rpm != caller.torque * caller.rpm)
		overstress(caller)
	else
		..()
