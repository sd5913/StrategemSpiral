extends Node

func _exit_tree() -> void:
	var had_streams := false
	AudioServer.lock()
	for player: AudioStreamPlayer in get_children():
		if player.stream != null:
			had_streams = true
			player.stream = null
	var stopped_at := Time.get_ticks_usec()
	AudioServer.unlock()
	if not had_streams:
		return

	# Godot queues stopped streams for deletion on the mixer thread.
	# Wait for a post-stop mix before the engine shuts the driver down.
	while Time.get_ticks_usec() - stopped_at < 100_000:
		var elapsed := (Time.get_ticks_usec() - stopped_at) / 1_000_000.0
		if AudioServer.get_time_since_last_mix() < elapsed:
			break
		OS.delay_msec(1)

func play(audio: AudioStream, single=false) -> void:	
	if not audio:
		return
	if single:
		stop()
		
	for player in get_children():
		player = player as AudioStreamPlayer
		
		if not player.playing:
			player.stream = audio
			player.play()
			break
			
func stop() -> void:
	for player in get_children():
		player = player as AudioStreamPlayer
		player.stop()
	
