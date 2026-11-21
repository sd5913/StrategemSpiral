class_name DamageEffect
extends Effect

var amount: int = 0

func execute(targets: Array[Node]) -> void:
	for target in targets:
		if not target:
			continue
		if target is Enemy or target is Player:
			var dealt_amount: int = amount
			if target is Enemy:
				var players := target.get_tree().get_nodes_in_group("player")
				if not players.is_empty():
					var player := players[0] as Player
					if player and is_instance_valid(player):
						dealt_amount *= player.stats.damage_multiplier
			target.take_damage(dealt_amount)
			SfxPlayer.play(sound)
