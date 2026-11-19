class_name CardStates
extends Node

enum State{BASE, CLICKED, DRAGGING, AIMING, RELEASED}

signal transition_requested(from: CardStates, to: State)

@export var state: State

var card_ui: CardUI

func enter() -> void:
	pass

func exit() -> void:
	pass

func on_input(_event: InputEvent) -> void:
	pass

func on_gui_input(_event: InputEvent) -> void:
	pass

func on_mouse_entered() -> void:
	pass

func on_mouse_exited() -> void:
	pass

func release_at(viewport_position: Vector2) -> void:
	get_viewport().set_input_as_handled()
	card_ui.resolve_drop_at(viewport_position)
	var next_state := State.BASE if card_ui.targets.is_empty() else State.RELEASED
	transition_requested.emit(self, next_state)
