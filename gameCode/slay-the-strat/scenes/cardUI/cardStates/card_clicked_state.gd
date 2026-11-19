extends CardStates


func enter() -> void:
	card_ui.original_index = card_ui.get_index()
	
func on_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		transition_requested.emit(self, CardStates.State.DRAGGING)
		card_ui.card_state_machine.on_input(event)
	elif event.is_action_released("left_mouse") or event.is_action_pressed("right_mouse"):
		transition_requested.emit(self, CardStates.State.BASE)
