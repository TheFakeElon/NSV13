/obj/machinery/atmospherics/components/binary/turbine
	name = "mechanical gas turbine"
	desc = "Extracts energy from pressurized gas flow, providing rotary energy to mechanical components."
	icon = 'nsv13/icons/obj/machinery/mechanical.dmi'
	icon_state "turbine_idle"
	var/obj/structure/mechanical/gear/shaftbox/shaftbox
	var/valve = 0 // 0 to 1. Governs how much gas can flow through, with lower being less

/obj/machinery/atmospherics/components/binary/turbine/Initialize(mapload)
	return INITIALIZE_HINT_LATELOAD
