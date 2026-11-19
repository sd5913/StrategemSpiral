extends EnemyAction

var tint_tween: Tween

func perform_action() -> void:
	if not enemy:
		return

	if tint_tween and tint_tween.is_running():
		tint_tween.kill()

	enemy.is_protecting_allies = true
	enemy.sprite_2d.modulate = Color.WHITE
	tint_tween = enemy.create_tween().set_loops()
	tint_tween.tween_property(enemy.sprite_2d, "modulate", Color(1.0, 0.25, 0.25), 0.2)
	tint_tween.tween_property(enemy.sprite_2d, "modulate", Color.WHITE, 0.2)
	Events.player_turn_ended.connect(_on_player_turn_ended.bind(enemy), CONNECT_ONE_SHOT)
	SfxPlayer.play(sound)

	get_tree().create_timer(0.6, false).timeout.connect(
		func():
			Events.enemy_action_completed.emit(enemy)
	)

func _on_player_turn_ended(protected_enemy: Enemy) -> void:
	if not is_instance_valid(protected_enemy):
		return

	if tint_tween and tint_tween.is_running():
		tint_tween.kill()
	tint_tween = null
	protected_enemy.is_protecting_allies = false
	protected_enemy.sprite_2d.modulate = Color.WHITE
