/obj/machinery/computer/flymotor
	name = "flywheel motor control console"
	desc = "A simple console used to control flywheel motors"
	icon_state = "oldcomp"
	icon_screen = "turbinecomp"
	icon_keyboard = null
	var/list/motors = list()
	var/automode = TRUE
	var/autoset = 0
	var/obj/effect/flywheel/flywheel
	var/M_ID = "lazy1"

/obj/machinery/computer/flymotor/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(ui)
		return
	ui = new(user, src, "MotorControl")
	ui.open()

/obj/machinery/computer/flymotor/ui_act(action, params)
	if(..())
		return
	var/selected = params["target"]
	switch(action)
		if("input")
			if(automode)
				return
			var/obj/structure/mechanical/powered/motor/vroom = motors[target]
			if(!vroom)
				return
			var/input = clamp(text2num(params["desired_man"]), 0, vroom.capacity)
			vroom.current_amt = input
		if("toggle_auto")
			automode = !automode
		if("input_auto")
			var/input = max(text2num(params["desired_auto"]), 0)
			autoset = input

/obj/machinery/computer/flymotor/ui_data(mob/user)
	var/list/data = list()
	data["motors"] = list()
	data["rpm"] = 0
	data["max_rpm"] = 0
	data["auto"] = automode
	data["auto_amt"] = autoset
	if(flywheel)
		data["motors"] = motors
		data["rpm"] = flywheel.rpm
		data["max_rpm"] = flywheel.bearing.max_rpm
	return data

// for handling auto
/obj/machinery/computer/flymotor/process()
	if(!automode || (stat & BROKEN) || !length(motors) || !flywheel)
		return
	for(var/obj/structure/mechanical/powered/motor/MO in motors)
		if(MO.is_satisfied())
			return
		MO.current_amt = clamp(auto_remaining(), 0, MO.capacity)

/// Gets the energy difference between the current level and the target level
/obj/machinery/computer/flymotor/proc/auto_remaining()
	return autoset - flywheel.get_energy() / GLOB.CELLRATE

// ------ Generator ------

/obj/machinery/computer/flymotor/generator
	name = "flywheel output control console"
	desc = "A simple console use to control flywheel electric generators"
	icon_screen = "recharge_comp"

/obj/machinery/computer/flymotor/generator/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(ui)
		return
	ui = new(user, src, "GeneratorControl")
	ui.open()

/obj/machinery/computer/flymotor/auto_remaining()
	return flywheel.get_energy() / GLOB.CELLRATE - autoset
