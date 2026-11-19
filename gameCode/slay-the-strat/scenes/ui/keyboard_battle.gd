extends Control

const FIRST_COMBO_TIME := 5.0
const ROUND_TIME_STEP := 0.5
const MIN_COMBO_TIME := 1.5
const COMBO_BONUS := 1
const COMBOS := {
	Card.Type.ATTACK: [KEY_UP, KEY_RIGHT, KEY_DOWN],
	Card.Type.SKILL: [KEY_LEFT, KEY_DOWN, KEY_LEFT],
	Card.Type.POWER: [KEY_UP, KEY_UP, KEY_DOWN],
}
const DIRECTION_ANGLES := {
	KEY_UP: 0.0,
	KEY_RIGHT: 90.0,
	KEY_DOWN: 180.0,
	KEY_LEFT: 270.0,
}
const SLOT_STYLE := preload("res://scenes/ui/keyboard_slot.tres")
const SELECTED_SLOT_STYLE := preload("res://scenes/ui/keyboard_slot_selected.tres")
const DARK_INK := Color("#231725")
const GOLD := Color("#ffe3a3")
const MUTED_ARROW := Color("#c5b5a2")

@export var enemy_handler: EnemyHandler
@export var hand: Hand
@export var end_turn_button: Button

@onready var combo_prompt: Control = $ComboPrompt
@onready var arrows: HBoxContainer = $ComboPrompt/Arrows
@onready var combo_timer: ProgressBar = $ComboPrompt/ComboTimer
@onready var combo_burst = $ComboBurst

var selected_enemy: Enemy
var enemy_slots: Array[int] = []
var armed_card: CardUI
var combo: Array
var combo_step := 0
var combo_remaining := 0.0
var round_number := 0


func _ready() -> void:
	for enemy in enemy_handler.get_children():
		if enemy is Enemy:
			enemy_slots.append(enemy.get_instance_id())
	enemy_handler.child_order_changed.connect(_refresh_enemies)
	hand.child_order_changed.connect(_refresh_cards.call_deferred)
	Events.player_hand_drawn.connect(_on_hand_drawn)
	Events.player_turn_ended.connect(_clear_card)
	Events.card_drag_started.connect(_on_card_drag_started)
	_refresh_enemies()
	_clear_card()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if is_instance_valid(armed_card):
			_clear_card()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	if not event.pressed:
		return

	var number := _key_number(key)
	if number == 0 and not (key in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE] or DIRECTION_ANGLES.has(key)):
		return
	get_viewport().set_input_as_handled()
	if event.echo or end_turn_button.disabled or round_number == 0:
		return

	if number > 0:
		if not event.shift_pressed:
			_arm_card(number - 1)
		elif number <= enemy_slots.size():
			var enemy := _enemy_at(number - 1)
			if _is_alive(enemy):
				selected_enemy = enemy
				_refresh_enemies()
	elif key == KEY_ESCAPE and is_instance_valid(armed_card):
		_clear_card()
	elif key == KEY_ENTER or key == KEY_KP_ENTER:
		if is_instance_valid(armed_card):
			_play_card(0, false)
		else:
			end_turn_button.pressed.emit()
	elif is_instance_valid(armed_card) and DIRECTION_ANGLES.has(key):
		_enter_direction(key)


func _process(delta: float) -> void:
	if not is_instance_valid(armed_card):
		_clear_card()
		return
	combo_remaining -= delta
	if combo_remaining <= 0.0:
		_play_card(0)
	else:
		combo_timer.value = combo_remaining


func _arm_card(slot: int) -> void:
	if slot >= hand.get_child_count():
		return
	var card := hand.get_child(slot) as CardUI
	if card == armed_card:
		return
	if not _can_play(card):
		_clear_card()
		return
	armed_card = card
	combo = COMBOS[card.card.type]
	combo_step = 0
	combo_remaining = maxf(MIN_COMBO_TIME, FIRST_COMBO_TIME - (round_number - 1) * ROUND_TIME_STEP)
	combo_timer.max_value = combo_remaining
	combo_timer.value = combo_remaining
	combo_prompt.show()
	_update_combo_arrows()
	_refresh_cards()
	set_process(true)


func _enter_direction(key: Key) -> void:
	if key != combo[combo_step]:
		_play_card(0)
		return
	combo_step += 1
	if combo_step == combo.size():
		_play_card(COMBO_BONUS)
	else:
		_update_combo_arrows()


func _play_card(effect_bonus: int, show_burst := true) -> void:
	var card := armed_card
	if not _can_play(card):
		_clear_card()
		return
	_refresh_enemies()
	if card.card.is_single_targeted() and not _is_alive(selected_enemy):
		_clear_card()
		return
	if card.card.is_single_targeted():
		card.targets = [selected_enemy]
	else:
		card.targets = [hand]
	if show_burst:
		var actor := selected_enemy if card.card.is_single_targeted() else get_tree().get_first_node_in_group("player") as Node2D
		if is_instance_valid(actor):
			combo_burst.play(actor.get_global_transform_with_canvas().origin, effect_bonus > 0)
	_clear_card()
	card.play(effect_bonus)


func _clear_card() -> void:
	armed_card = null
	set_process(false)
	combo_prompt.hide()
	_refresh_cards()


func _update_combo_arrows() -> void:
	for i in range(combo.size()):
		var slot := arrows.get_child(i) as Panel
		var arrow := slot.get_node("Arrow") as Sprite2D
		var completed := i < combo_step
		slot.add_theme_stylebox_override("panel", SELECTED_SLOT_STYLE if completed else SLOT_STYLE)
		arrow.rotation_degrees = DIRECTION_ANGLES[combo[i]]
		arrow.modulate = DARK_INK if completed else (GOLD if i == combo_step else MUTED_ARROW)


func _on_hand_drawn() -> void:
	round_number += 1
	_clear_card()


func _on_card_drag_started(card: CardUI) -> void:
	var badge := card.get_node_or_null("KeyboardSlot") as KeyboardKeycap
	if badge:
		badge.hide()
	_clear_card()


func _refresh_enemies() -> void:
	if not is_instance_valid(selected_enemy) or not _is_alive(selected_enemy):
		selected_enemy = null
		for i in range(enemy_slots.size()):
			var enemy := _enemy_at(i)
			if _is_alive(enemy):
				selected_enemy = enemy
				break
	for i in range(enemy_slots.size()):
		var enemy := _enemy_at(i)
		if _is_alive(enemy):
			_update_badge(enemy, i + 1, enemy == selected_enemy)


func _refresh_cards() -> void:
	for card in hand.get_children():
		if card is CardUI and not card.is_queued_for_deletion():
			_update_badge(card, card.get_index() + 1, card == armed_card)


func _update_badge(node: Node, number: int, selected: bool) -> void:
	var badge := node.get_node_or_null("KeyboardSlot") as KeyboardKeycap
	if badge == null:
		badge = KeyboardKeycap.new()
		badge.name = "KeyboardSlot"
		badge.custom_minimum_size = KeyboardKeycap.SIZE
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(badge)
		if node is CardUI:
			badge.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
			badge.offset_left = -KeyboardKeycap.SIZE.x * 0.5
			badge.offset_right = KeyboardKeycap.SIZE.x * 0.5
			badge.offset_top = -KeyboardKeycap.SIZE.y - 1
			badge.offset_bottom = -1
		else:
			badge.position = Vector2(-KeyboardKeycap.SIZE.x * 0.5, 22)
	badge.set_key(number, selected)


func _can_play(card: CardUI) -> bool:
	return (is_instance_valid(card) and card.get_parent() == hand
		and not card.is_queued_for_deletion() and not card.disabled
		and card.char_stats.can_play_card(card.card))


func _is_alive(enemy: Enemy) -> bool:
	return is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy.stats.health > 0


func _enemy_at(slot: int) -> Enemy:
	return instance_from_id(enemy_slots[slot]) as Enemy


func _key_number(key: Key) -> int:
	if key >= KEY_1 and key <= KEY_9:
		return key - KEY_1 + 1
	if key >= KEY_KP_1 and key <= KEY_KP_9:
		return key - KEY_KP_1 + 1
	return 0
