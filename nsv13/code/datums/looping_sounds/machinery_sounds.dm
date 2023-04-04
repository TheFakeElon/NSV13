/datum/looping_sound/advanced/ftl_drive
	start_sound = 'nsv13/sound/machines/FTL/main_drive_spoolup.ogg'
	start_length = 24 SECONDS
	mid_sounds = 'nsv13/sound/machines/FTL/main_drive_loop.ogg'
	mid_length = 10.9 SECONDS
	end_sound = 'nsv13/sound/machines/FTL/main_drive_spooldown.ogg'
	volume = 100
	can_process = TRUE

// We use pretty long sounds here so we'll update the volume for listeners on process
/datum/looping_sound/advanced/ftl_drive/process()
	recalculate_volume(1)

#define BASE_FREQ 0.4

/datum/looping_sound/flywheel
	start_sound = 'nsv13/sound/effects/flywheel/startup.ogg'
	mid_sounds = list('nsv13/sound/effects/flywheel/powered_air.ogg' = 1)
	volume = 50
	end_sound = 'nsv13/sound/effects/flywheel/shutdown.ogg'
	extra_range = 6
	var/wrr = 1 // pitch

/datum/looping_sound/flywheel/play(soundfile)
	var/sound/S = sound(soundfile)
	if(direct)
		S.channel = SSsounds.random_available_channel()
		S.volume = volume
		SEND_SOUND(parent, S)
	else
		playsound(parent, S, volume, wrr, extra_range, frequnecy=wrr)

/datum/looping_sound/flywheel/proc/update_wrr(rpm, max_rpm)
	wrr = BASE_FREQ + rpm / max_rpm

#undef BASE_FREQ
