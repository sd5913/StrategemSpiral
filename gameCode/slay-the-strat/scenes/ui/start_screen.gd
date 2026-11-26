extends Node2D

const BATTLE_SCENE_PATH := "res://scenes/battle/battle.tscn"
const TITLE_BASE_Y := 18.0
const TITLE_FLOAT_AMPLITUDE := 1.5
const TITLE_FLOAT_SPEED := 2.0

@onready var title_label: Label = $Title
var float_time := 0.0


func _process(delta: float) -> void:
	float_time += delta
	title_label.position.y = TITLE_BASE_Y + roundf(
		sin(float_time * TITLE_FLOAT_SPEED) * TITLE_FLOAT_AMPLITUDE
	)


func _unhandled_input(event: InputEvent) -> void:
	var should_start := false

	if event is InputEventKey:
		should_start = event.pressed and not event.echo
	elif event is InputEventMouseButton:
		should_start = event.pressed
	elif event is InputEventJoypadButton:
		should_start = event.pressed

	if should_start:
		var error := get_tree().change_scene_to_file(BATTLE_SCENE_PATH)
		if error != OK:
			push_error("Failed to load battle scene: %s" % error)
