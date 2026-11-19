extends Card

var _pending_mana_overflow := 0
var _awaiting_hand_draw := false

func apply_effects(targets: Array[Node], effect_bonus: int) -> void:
	for target in targets:
		var player := target as Player
		if player:
			_pending_mana_overflow += 2 + effect_bonus
			if not _awaiting_hand_draw:
				_awaiting_hand_draw = true
				Events.player_hand_drawn.connect(_grant_mana_overflow.bind(player.stats), CONNECT_ONE_SHOT)

func _grant_mana_overflow(stats: CharacterStats) -> void:
	stats.mana += _pending_mana_overflow
	_pending_mana_overflow = 0
	_awaiting_hand_draw = false
