/obj/machinery/atmospherics/components/binary/turbine
	name = "mechanical gas turbine"
	desc = "Extracts energy from pressurized gas flow, providing rotary energy to mechanical components."
	icon = 'nsv13/icons/obj/machinery/mechanical.dmi'
	icon_state = "turbine_idle"
	var/datum/component/mechanical_interface/MI
	var/shaft_dirs // bitfield of which directions we can attach to a shaftbox.

	// --- physx vars ----
	var/blade_radius = 0.5 // blade and duct radius
	var/valve = 0 // 0 to 1. Governs how much gas can flow through, with lower being less
	var/power = 0			// How much power we're extracting in watts

/obj/machinery/atmospherics/components/binary/turbine/Initialize(mapload)
	..()
	return INITIALIZE_HINT_LATELOAD

/obj/machinery/atmospherics/components/binary/turbine/LateInitialize()
	..()
	MI = AddComponent(/datum/component/mechanical_interface, 10, 15000, /obj/structure/mechanical/gear/shaftbox)
	MI.scan_adjacent(shaft_dirs, shaft_dirs)
	MI.sync()

/obj/machinery/atmospherics/components/binary/turbine/SetInitDirections()
	..()
	if(dir & (NORTH | SOUTH))
		shaft_dirs = EAST | WEST
	else
		shaft_dirs = NORTH | SOUTH

/obj/machinery/atmospherics/components/binary/turbine/process_atmos(delta_time)
	..()
	var/datum/gas_mixture/input = airs[1]
	var/datum/gas_mixture/output = airs[2]
	// Unfortunately auxmos does not currently have any DM-facing functions to get mass so we have to work backwards to find it.
	// Q=mcΔT, we can ignore delta temp and find mass with m=Q/c
	var/in_mass = input.thermal_energy() / input.heat_capacity()
	var/in_density = in_mass / input.return_volume()
	var/delta_p = max(input.return_pressure() - output.return_pressure(), 0)
	// Velocity of flow = sqrt((2 x ΔP) / Density). Rearranged Bernoulli equation
	var/flow_velocity = sqrt((2 * delta_p) / in_density) * delta_time
	// cross sectional area * flow velocity * gas density
	var/volumetric_flow_rate = (blade_radius * blade_radius * PI) * flow_velocity
	// mass flow rate * 0.5
	power = volumetric_flow_rate * in_density * 0.5
	input.transfer_ratio_to(output, volumetric_flow_rate / input.return_volume())

