extends Card

func apply_effects(targets: Array[Node]) -> void:
	if targets.is_empty():
		return
	var player := targets[0] as Player
	if not player:
		return
	Events.ultimate_card_qte_started.emit(
		["left", "right", "right", "left"] as Array[String],
		_apply_success.bind(player),
		_apply_failure.bind(player)
	)

func _apply_success(player: Player) -> void:
	play_card_sound()
	var enemies: Array[Enemy] = []
	var enemy_health_sum := 0
	for enemy_node in player.get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		if enemy and enemy.stats.health > 0:
			enemies.append(enemy)
			enemy_health_sum += enemy.stats.health
	if enemies.is_empty():
		return
	var divided_health := ceili(float(player.stats.health) / float(enemies.size()))
	player.stats.health = enemy_health_sum
	for enemy in enemies:
		enemy.stats.health = divided_health
	for character_node in player.get_tree().get_nodes_in_group("player") + enemies:
		if character_node is Node2D:
			Shaker.shake(character_node as Node2D, 16.0, 2.0)

func _apply_failure(player: Player) -> void:
	var enemies: Array[Enemy] = []
	for enemy_node in player.get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		if enemy and enemy.stats.health > 0:
			enemies.append(enemy)
	if enemies.is_empty():
		return
	var divided_health := ceili(float(player.stats.health) / float(enemies.size()))
	for enemy in enemies:
		enemy.stats.heal(divided_health)
		var tween := enemy.create_tween()
		tween.tween_property(enemy.sprite_2d, "modulate", Color.GREEN, 0.08)
		tween.tween_property(enemy.sprite_2d, "modulate", Color.WHITE, 0.25)
