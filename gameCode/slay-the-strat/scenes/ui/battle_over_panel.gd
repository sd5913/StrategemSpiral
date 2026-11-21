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
	label.text = text
	label.remove_theme_color_override("font_color")
	if type == Type.OBLITERATED:
		label.add_theme_color_override("font_color", Color(1.0, 0.48, 0.3))
	continue_button.visible = true
	restart_button.visible = true
	show()
	get_tree().paused = true
