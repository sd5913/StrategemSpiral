extends Node2D

const ARC_POINTS := 10

@onready var area_2d: Area2D = $Area2D
@onready var card_arc: Line2D = $CanvasLayer/cardArc

var current_card: CardUI
var targeting := false
var overlapping_targets: Array[Area2D] = []

func _ready() -> void:
	Events.card_aim_started.connect(_on_card_aim_started)
	Events.card_aim_ended.connect(_on_card_aim_ended)
	
func _process(_delta: float) -> void:
	if not targeting:
		return
	
	area_2d.position = get_local_mouse_position()
	card_arc.points = get_points()
	_refresh_selected_target()
	
func get_points() -> Array:
	var points := []
	var start := current_card.global_position
	start.x += (current_card.size.x /2)
	var target := get_local_mouse_position()
	var distance := (target - start)
	
	for i in range(ARC_POINTS):
		var t := (1.0 / ARC_POINTS) * i
		var x := start.x + (distance.x / ARC_POINTS) * i
		var y := start.y + ease_out_cubic(t) * distance.y
		points.append(Vector2(x, y))
		
	points.append(target)
	return points
	
func ease_out_cubic(number: float) -> float:
	return 1.0 - pow(1.0 - number, 3.0)
	
func _on_card_aim_started(card: CardUI) -> void:
	if not card.card.is_single_targeted():
		return
	
	targeting = true
	overlapping_targets.clear()
	_clear_target_indicators()
	area_2d.monitoring = true
	area_2d.monitorable = true
	current_card = card
	
func _on_card_aim_ended(card: CardUI) -> void:
	targeting = false
	card_arc.clear_points()
	overlapping_targets.clear()
	_clear_target_indicators()
	area_2d.position = Vector2.ZERO
	area_2d.monitoring = false
	area_2d.monitorable = false
	current_card = null

func _on_area_2d_area_entered(area: Area2D) -> void:
	if not current_card or not targeting:
		return
	
	if area.is_in_group("enemies") and not overlapping_targets.has(area):
		overlapping_targets.append(area)
		_refresh_selected_target()

func _on_area_2d_area_exited(area: Area2D) -> void:
	if not current_card or not targeting:
		return
	
	overlapping_targets.erase(area)
	_refresh_selected_target()

func _refresh_selected_target() -> void:
	if not current_card or not targeting:
		return

	var mouse_position := area_2d.global_position
	var selected_target: Area2D
	var nearest_distance := INF
	for candidate in overlapping_targets:
		if not is_instance_valid(candidate) or not candidate.is_in_group("enemies"):
			continue
		var distance := mouse_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			selected_target = candidate

	current_card.targets.clear()
	if selected_target:
		current_card.targets.append(selected_target)
	_set_target_indicators(selected_target)

func _set_target_indicators(selected_target: Area2D) -> void:
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		if enemy:
			enemy.set_target_indicator_active(enemy == selected_target)

func _clear_target_indicators() -> void:
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		if enemy:
			enemy.set_target_indicator_active(false)
