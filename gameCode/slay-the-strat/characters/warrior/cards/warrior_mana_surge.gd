extends Card

func apply_effects(targets: Array[Node]) -> void:
	for target in targets:
		var player := target as Player
		if player:
			Events.player_hand_drawn.connect(_grant_mana_overflow.bind(player.stats), CONNECT_ONE_SHOT)

func _grant_mana_overflow(stats: CharacterStats) -> void:
	stats.mana += 2
