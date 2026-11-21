extends Card

func apply_effects(targets: Array[Node]) -> void:
	if targets.is_empty():
		return
	var player := targets[0] as Player
	if not player:
		return
	Events.ultimate_card_qte_started.emit(
		["up","down","down","up","down"] as Array[String],
		_apply_success.bind(player),
		_apply_failure.bind(player)
	)

func _apply_success(player: Player) -> void:
	player.stats.health *= 2
	player.stats.blood_ritual_loss_per_turn = 2
	var pulse_tween := player.create_tween().set_loops()
	pulse_tween.tween_property(player.sprite_2d, "modulate", Color(1.0, 0.25, 0.25), 0.2)
	pulse_tween.tween_property(player.sprite_2d, "modulate", Color.WHITE, 0.2)
	Events.battle_over_screen_requested.connect(
		_stop_pulse.bind(pulse_tween, player.sprite_2d),
		CONNECT_ONE_SHOT
	)

func _stop_pulse(_text: String, _type: BattleOverPanel.Type, pulse_tween: Tween, sprite: Sprite2D) -> void:
	if is_instance_valid(pulse_tween) and pulse_tween.is_running():
		pulse_tween.kill()
	if is_instance_valid(sprite):
		sprite.modulate = Color.WHITE

func _apply_failure(player: Player) -> void:
	var remaining := ceili(float(player.stats.health) / 2.0)
	var damage := player.stats.health - remaining
	player.stats.block = 0
	player.take_damage(damage)
