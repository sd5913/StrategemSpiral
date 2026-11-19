extends EnemyAction

@export var damage := 14

func perform_action() -> void:
	if not enemy or not target:
		return
		
	var tween := create_tween().set_trans(Tween.TRANS_QUINT)
	var end := target.global_position + Vector2.RIGHT * 32
	var damage_effect := DamageEffect.new()
	var target_array: Array[Node] = [target]
	damage_effect.amount = damage
	damage_effect.sound = sound
	
	tween.tween_property(enemy,"global_position", end, 0.4)
	tween.tween_callback(damage_effect.execute.bind(target_array))
	tween.tween_callback(func():
		enemy.take_damage(damage)
		Events.enemy_action_completed.emit(enemy)
	)
