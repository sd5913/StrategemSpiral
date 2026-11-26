extends EnemyAction

@export var damage := 4


func perform_action() -> void:
	if not enemy or not target:
		return

	var tween := create_tween().set_trans(Tween.TRANS_QUINT)
	var start := enemy.global_position
	var end := target.global_position + Vector2.RIGHT * 32
	var damage_effect := DamageEffect.new()
	var target_array: Array[Node] = [target]
	damage_effect.amount = damage
	damage_effect.sound = sound

	tween.tween_property(enemy, "global_position", end, 0.4)
	tween.tween_callback(_deal_hit.bind(damage_effect, target_array))
	tween.tween_interval(0.25)
	tween.tween_callback(_deal_hit.bind(damage_effect, target_array))
	tween.tween_interval(0.25)
	tween.tween_property(enemy, "global_position", start, 0.4)

	tween.finished.connect(
		func():
			Events.enemy_action_completed.emit(enemy)
	)


func _deal_hit(damage_effect: DamageEffect, targets: Array[Node]) -> void:
	damage_effect.execute(targets)
	enemy.stats.heal(int(damage_effect.amount * 0.5))
