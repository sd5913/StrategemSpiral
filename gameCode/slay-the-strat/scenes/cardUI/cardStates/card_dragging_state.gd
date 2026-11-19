extends CardStates

func enter() -> void:
	var ui_layer := get_tree().get_first_node_in_group("ui_layer")
	if ui_layer:
		card_ui.reparent(ui_layer)
		
	card_ui.panel.set("theme_override_styles/panel", card_ui.DRAGGING_STYLEBOX)
	card_ui.drop_point_detector.monitoring = true
	Events.card_drag_started.emit(card_ui)
	
func exit() -> void:
	Events.card_drag_ended.emit(card_ui)
	
func on_input(event: InputEvent) -> void:
	var single_targeted := card_ui.card.is_single_targeted()
	var mouse_motion := event is InputEventMouseMotion
	var cancel = event.is_action_pressed("right_mouse")
	
	if single_targeted and mouse_motion and card_ui.targets.size() > 0:
		transition_requested.emit(self, CardStates.State.AIMING)
		return
	
	if mouse_motion:
		card_ui.global_position = card_ui.get_global_mouse_position() - card_ui.pivot_offset
		
	if cancel:
		transition_requested.emit(self, CardStates.State.BASE)
	elif event is InputEventMouseButton and event.is_action_released("left_mouse"):
		release_at(event.position)
