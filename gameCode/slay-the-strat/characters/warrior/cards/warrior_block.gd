extends Card

func apply_effects(targets: Array[Node], effect_multiplier: int) -> void:
	var block_effect := BlockEffect.new()
	block_effect.amount = 5 * effect_multiplier
	block_effect.sound = sound
	block_effect.execute(targets)
