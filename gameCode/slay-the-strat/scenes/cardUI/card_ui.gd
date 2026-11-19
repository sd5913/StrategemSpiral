class_name CardUI
extends Control

signal reparent_requested(which_card_ui: CardUI)

const BASE_STYLEBOX := preload("res://scenes/cardUI/card_face_stylebox.tres")
const HOVER_STYLEBOX := preload("res://scenes/cardUI/card_face_hover_stylebox.tres")
const DRAGGING_STYLEBOX := preload("uid://ca54yd7w2gcv0")
const ENEMY_COLLISION_MASK := 1 << 2

@export var card: Card : set = _set_card
@export var char_stats: CharacterStats : set = _set_char_stats

@onready var panel: Panel = $Panel
@onready var cost: Label = $Cost
@onready var icon: TextureRect = $Icon
@onready var drop_point_detector: Area2D = $dropPointDetector
@onready var card_state_machine: CardStateMachine = $cardStateMachine as CardStateMachine
@onready var targets: Array[Node] = []

var original_index := 0
var parent: Control
var tween: Tween
var playable := true : set = _set_playable
var disabled := false

func _ready() -> void:
	Events.card_aim_started.connect(_on_card_drag_or_aiming_started)
	Events.card_drag_started.connect(_on_card_drag_or_aiming_started)
	Events.card_drag_ended.connect(_on_card_drag_or_aiming_ended)
	Events.card_aim_ended.connect(_on_card_drag_or_aiming_ended)
	card_state_machine.init(self)
	
func _input(event: InputEvent) -> void:
	card_state_machine.on_input(event)
	
func animate_to_position(new_position: Vector2, duration: float) -> void:
	tween = create_tween().set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", new_position, duration)
	
func play(effect_bonus := 0) -> void:
	if not card:
		return
	
	card.play(targets, char_stats, effect_bonus)
	queue_free()

func resolve_drop_at(viewport_position: Vector2) -> void:
	targets.clear()
	if not playable:
		return

	# Physics overlap signals can lag the release event by a frame.
	var query := PhysicsPointQueryParameters2D.new()
	query.position = get_viewport().get_canvas_transform().affine_inverse() * viewport_position
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var single_target := card.is_single_targeted()
	query.collision_mask = ENEMY_COLLISION_MASK if single_target else drop_point_detector.collision_mask
	var closest: Node2D
	var distance := INF
	for hit in get_world_2d().direct_space_state.intersect_point(query):
		var candidate := hit.collider as Node2D
		if single_target and (not candidate is Enemy or candidate.stats.health <= 0):
			continue
		var candidate_distance := candidate.global_position.distance_squared_to(query.position)
		if candidate_distance < distance:
			closest = candidate
			distance = candidate_distance
	if closest != null:
		targets.append(closest)
	
func _on_gui_input(event: InputEvent) -> void:
	card_state_machine.on_gui_input(event)

func _on_mouse_entered() -> void:
	card_state_machine.on_mouse_entered()
	
func _on_mouse_exited() -> void:
	card_state_machine.on_mouse_exited()
	
func _set_card(value: Card) -> void:
	if not is_node_ready():
		await ready
	
	card = value
	cost.text = str(card.cost)
	icon.texture = card.icon
	
func _set_playable(value: bool) -> void:
	playable = value
	if not playable:
		cost.add_theme_color_override("font_color", Color.RED)
		icon.modulate = Color(1, 1, 1, 0.5)
	else:
		cost.remove_theme_color_override("font_color")
		icon.modulate = Color(1, 1, 1, 1)
		
func _set_char_stats(value: CharacterStats) -> void:
	char_stats = value
	char_stats.stats_changed.connect(_on_char_stats_changed)


func _on_drop_point_detector_area_entered(area: Area2D) -> void:
	if not targets.has(area):
		targets.append(area)


func _on_drop_point_detector_area_exited(area: Area2D) -> void:
	targets.erase(area)
	
func _on_card_drag_or_aiming_started(used_card: CardUI) -> void:
	if used_card == self:
		return
	disabled = true
	
func _on_card_drag_or_aiming_ended(_card: CardUI) -> void:
	disabled = false
	self.playable = char_stats.can_play_card(card)
	
func _on_char_stats_changed() -> void:
	self.playable = char_stats.can_play_card(card)
