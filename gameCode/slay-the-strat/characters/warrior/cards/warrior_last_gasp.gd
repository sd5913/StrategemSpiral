extends Card

func apply_effects(targets: Array[Node]) -> void:
	if targets.is_empty():
		return
	var player := targets[0] as Player
	if not player:
		return
	Events.ultimate_card_qte_started.emit(
		["right","down","right","down","right","down"] as Array[String],
		_apply_success.bind(player),
		_apply_failure.bind(player)
	)

func _apply_success(player: Player) -> void:
	play_card_sound()
	var damage := maxi(player.stats.health - 5, 0)
	player.stats.block = 0
	if damage > 0:
		player.take_damage(damage)
	else:
		player.stats.health = 5
		player.take_damage(0)
	player.stats.damage_multiplier = 3
	player.start_shiver()

func _apply_failure(player: Player) -> void:
	var damage := maxi(player.stats.health - 5, 0)
	player.stats.block = 0
	if damage > 0:
		player.take_damage(damage)
	else:
		player.stats.health = 5
		player.take_damage(0)
