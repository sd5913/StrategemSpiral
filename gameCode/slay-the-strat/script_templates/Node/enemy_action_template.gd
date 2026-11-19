# meta-name: EnemyAction
# meta-description: An action that can be performed by an enemy during its own turn.

extends EnemyAction

func perform_action() -> void:
	if not enemy or not target:
		return
		
	var tween := create_tween().set_trans(Tween.TRANS_QUINT)
	var start := enemy.global_position
	var end := enemy.global_position + Vector2.RIGHT * 32
	
	SfxPlayer.play(sound)
	
	Events.enemy_action_completed.emit(enemy)
