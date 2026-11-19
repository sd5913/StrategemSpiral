extends Card

func apply_effects(targets: Array[Node], effect_bonus: int) -> void:
	var damage_effect := DamageEffect.new()
	damage_effect.amount = 3 + effect_bonus
	damage_effect.sound = sound
	damage_effect.execute(targets)
