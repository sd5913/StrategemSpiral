extends EnemyAction

@export var damage := 4
@export var block_amount := 2

func perform_action() -> void:
	if not enemy or not target:
		return

	Events.enemy_turn_ended.connect(_grant_team_block.bind(enemy), CONNECT_ONE_SHOT)

	var tween := create_tween().set_trans(Tween.TRANS_QUINT)
	var start := enemy.global_position
	var end := target.global_position + Vector2.RIGHT * 32
	var damage_effect := DamageEffect.new()
	var target_array: Array[Node] = [target]
	damage_effect.amount = damage
	damage_effect.sound = sound

	tween.tween_property(enemy, "global_position", end, 0.4)
	tween.tween_callback(damage_effect.execute.bind(target_array))
	tween.tween_interval(0.25)
	tween.tween_property(enemy, "global_position", start, 0.4)
	tween.finished.connect(
		func():
			Events.enemy_action_completed.emit(enemy)
	)

func _grant_team_block(attacking_enemy: Enemy) -> void:
	if not is_instance_valid(attacking_enemy) or not attacking_enemy.get_parent():
		return

	for child in attacking_enemy.get_parent().get_children():
		var ally := child as Enemy
		if ally and ally.stats.health > 0:
			ally.stats.block += block_amount
