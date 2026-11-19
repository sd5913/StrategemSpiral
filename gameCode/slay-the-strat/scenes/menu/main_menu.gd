extends Control

const BATTLE := preload("res://scenes/battle/battle.tscn")

@onready var play_button: Button = %PlayButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	play_button.pressed.connect(_start_battle)
	quit_button.pressed.connect(get_tree().quit)
	play_button.grab_focus.call_deferred()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().quit()


func _start_battle() -> void:
	get_tree().change_scene_to_packed(BATTLE)
