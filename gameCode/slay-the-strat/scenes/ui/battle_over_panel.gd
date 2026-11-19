class_name BattleOverPanel
extends Panel

enum Type {WIN, LOSE}

@onready var label: Label = %Label
@onready var continue_button = %ContinueButton
@onready var restart_button = %RestartButton

func _ready() -> void:
	continue_button.pressed.connect(get_tree().quit)
	restart_button.pressed.connect(get_tree().reload_current_scene)
	Events.battle_over_screen_requested.connect(show_screen)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed:
		return
	var key: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	match key:
		KEY_ENTER, KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			if not event.echo:
				restart_button.pressed.emit()
		KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if not event.echo:
				continue_button.pressed.emit()
	
func show_screen(text: String, _type: Type) -> void:
	label.text = text
	continue_button.visible = true
	restart_button.visible = true
	show()
	get_tree().paused = true
