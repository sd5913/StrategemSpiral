extends Card

func apply_effects(targets: Array[Node]) -> void:
	if targets.is_empty():
		return
	var player := targets[0] as Player
	if not player:
		return
	Events.ultimate_card_qte_started.emit(
		["down","up","left","down","up","right","down","up"] as Array[String],
		_apply_success.bind(player),
		_apply_failure.bind(player)
	)

func _apply_success(player: Player) -> void:
	SfxPlayer.play_while_paused(sound)
	Events.battle_over_resolution_started.emit()
	player.stats.block = 0
	player.stats.take_damage(30)
	var enemies := player.get_tree().get_nodes_in_group("enemies")
	var defeated_enemies: Array[Enemy] = []
	var enemies_alive := false
	for enemy_node in enemies:
		var enemy := enemy_node as Enemy
		if enemy:
			enemy.stats.block = 0
			enemy.stats.take_damage(30)
			if enemy.stats.health > 0:
				enemies_alive = true
			else:
				defeated_enemies.append(enemy)

	var whiteout: CanvasLayer = await _play_nuclear_cutscene(player)
	var player_defeated := player.stats.health <= 0
	for enemy in defeated_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	if not player_defeated and enemies_alive:
		await _fade_whiteout(whiteout, player)
	Events.battle_over_resolution_finished.emit()

func _apply_failure(player: Player) -> void:
	player.stats.block = 0
	if player.stats.health > 0:
		player.take_damage(player.stats.health)

func _play_nuclear_cutscene(player: Player) -> CanvasLayer:
	var arena := player.get_parent() as Node2D
	var arena_origin := arena.position
	var flash := ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1.0, 1.0, 1.0, 0.0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.add_child(flash)
	arena.add_child(layer)

	var whiteout_tween := player.create_tween()
	whiteout_tween.tween_property(flash, "color:a", 0.12, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	whiteout_tween.tween_property(flash, "color:a", 1.0, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	whiteout_tween.tween_interval(0.4)

	var quake_tween := player.create_tween()
	var shake_steps := 36
	for step in range(shake_steps):
		var intensity := float(step + 1) / float(shake_steps)
		var strength := lerpf(0.2, 2.5, intensity * intensity)
		var offset := Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		quake_tween.tween_property(arena, "position", arena_origin + offset, 3.4 / float(shake_steps))
	quake_tween.tween_property(arena, "position", arena_origin, 0.15)

	await whiteout_tween.finished
	arena.position = arena_origin
	return layer

func _fade_whiteout(layer: CanvasLayer, player: Player) -> void:
	var flash := layer.get_child(0) as ColorRect
	var fade_tween := player.create_tween()
	fade_tween.tween_property(flash, "color:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await fade_tween.finished
	layer.queue_free()
