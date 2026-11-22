class_name BattleOverPanel
extends Panel

enum Type {WIN, LOSE, OBLITERATED}

@onready var label: Label = %Label
@onready var continue_button = %ContinueButton
@onready var restart_button = %RestartButton

func _ready() -> void:
	continue_button.pressed.connect(get_tree().quit)
	restart_button.pressed.connect(get_tree().reload_current_scene)
	Events.battle_over_screen_requested.connect(show_screen)
	
func show_screen(text: String, type: Type) -> void:
	if _is_obliteration():
		text = "OBLITERATED"
		type = Type.OBLITERATED
	label.text = text
	label.remove_theme_color_override("font_color")
	if type == Type.OBLITERATED:
		label.add_theme_color_override("font_color", Color(1.0, 0.48, 0.3))
	continue_button.visible = true
	restart_button.visible = true
	show()
	get_tree().paused = true

func _is_obliteration() -> bool:
	var player_alive := false
	for player_node in get_tree().get_nodes_in_group("player"):
		var player := player_node as Player
		if player and player.stats.health > 0:
			player_alive = true
			break

	var enemies_alive := false
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		if enemy and enemy.stats.health > 0:
			enemies_alive = true
			break

	return not player_alive and not enemies_alive
