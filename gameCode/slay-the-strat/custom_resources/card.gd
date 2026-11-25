class_name Card
extends Resource

enum Type {ATTACK, SKILL, POWER}
enum Target{SELF, SINGLE_ENEMY, ALL_ENEMIES, EVERYONE}

@export_group("Card Attributes")
@export var id: String
@export var type: Type
@export var target: Target
@export var cost: int
@export var is_ultimate := false

@export_group("Card Visuals")
@export var icon: Texture
@export_multiline var tooltip_text: String
@export var sound: AudioStream

func is_single_targeted() -> bool:
	return target == Target.SINGLE_ENEMY

func play_card_sound() -> void:
	SfxPlayer.play(sound)

func _get_targets(targets: Array[Node]) -> Array[Node]:
	if not targets:
		return[]
	var tree := targets[0].get_tree()
	match target:
		Target.SELF:
			return tree.get_nodes_in_group("player")
		Target.ALL_ENEMIES:
			return tree.get_nodes_in_group("enemies")
		Target.EVERYONE:
			return tree.get_nodes_in_group("player") + tree.get_nodes_in_group("enemies")
		_:
			return []
		
func play(targets: Array[Node], char_stats: CharacterStats) -> void:
	Events.card_played.emit(self)
	char_stats.mana -= cost
	var resolved_targets: Array[Node] = []
	if is_single_targeted():
		if not targets.is_empty():
			resolved_targets.append(targets[0])
	else:
		resolved_targets = _get_targets(targets)

	if type == Type.ATTACK and not is_ultimate and not resolved_targets.is_empty():
		var player := resolved_targets[0].get_tree().get_first_node_in_group("player")
		if player and player.has_method("play_attack"):
			var on_hit := func() -> void:
				apply_effects(resolved_targets)
			await player.call("play_attack", resolved_targets, on_hit)
			return

	apply_effects(resolved_targets)

func apply_effects(_targets: Array[Node]) -> void:
	pass
