extends Control

const FIRST_COMBO_TIME := 5.0
const ROUND_TIME_STEP := 0.5
const MIN_COMBO_TIME := 1.5
const COMBO_BOOST := 2
const COMBOS := {
	Card.Type.ATTACK: [KEY_UP, KEY_RIGHT, KEY_DOWN],
	Card.Type.SKILL: [KEY_LEFT, KEY_DOWN, KEY_LEFT],
	Card.Type.POWER: [KEY_UP, KEY_UP, KEY_DOWN],
}
const DIRECTION_NAMES := {
	KEY_UP: "UP",
	KEY_RIGHT: "RIGHT",
	KEY_DOWN: "DOWN",
	KEY_LEFT: "LEFT",
}
const SLOT_STYLE := preload("res://scenes/ui/keyboard_slot.tres")
const SELECTED_SLOT_STYLE := preload("res://scenes/ui/keyboard_slot_selected.tres")

@export var enemy_handler: EnemyHandler
@export var hand: Hand
@export var end_turn_button: Button

@onready var hint: Label = $Hint
@onready var action: Label = $Action
@onready var card_keys: Label = $CardKeys
@onready var combo_timer: ProgressBar = $ComboTimer

var selected_enemy: Enemy
var enemy_slots: Array[int] = []
var armed_card: CardUI
var combo: Array
var combo_step := 0
var combo_remaining := 0.0
var round_number := 0
var space_held := false
var tooltip_markup := RegEx.create_from_string("\\[[^\\]]*\\]")


func _ready() -> void:
	for enemy in enemy_handler.get_children():
		if enemy is Enemy:
			enemy_slots.append(enemy.get_instance_id())
	enemy_handler.child_order_changed.connect(_refresh_enemies)
	hand.child_order_changed.connect(_refresh_cards.call_deferred)
	Events.player_hand_drawn.connect(_on_hand_drawn)
	Events.player_turn_ended.connect(_on_turn_ended)
	_refresh_enemies()
	_show_idle("Drawing cards")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		space_held = false
		if is_instance_valid(armed_card):
			_show_idle("Card selection canceled")


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	if key == KEY_SPACE:
		space_held = event.pressed
		get_viewport().set_input_as_handled()
		return
	if not event.pressed:
		return

	var number := _key_number(key)
	if number == 0 and not (key in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE] or DIRECTION_NAMES.has(key)):
		return
	get_viewport().set_input_as_handled()
	if event.echo or end_turn_button.disabled or round_number == 0:
		return

	if number > 0:
		if space_held:
			_arm_card(number - 1)
		elif number <= enemy_slots.size():
			var enemy := _enemy_at(number - 1)
			if _is_alive(enemy):
				selected_enemy = enemy
				_refresh_enemies()
	elif key == KEY_ESCAPE and is_instance_valid(armed_card):
		_show_idle("Card selection canceled")
	elif key == KEY_ENTER or key == KEY_KP_ENTER:
		if is_instance_valid(armed_card):
			_play_card(1, "Card played")
		else:
			end_turn_button.pressed.emit()
	elif is_instance_valid(armed_card) and DIRECTION_NAMES.has(key):
		_enter_direction(key)


func _process(delta: float) -> void:
	if not is_instance_valid(armed_card):
		_show_idle("Choose a card")
		return
	combo_remaining -= delta
	if combo_remaining <= 0.0:
		_play_card(1, "Time up. Normal play.")
	else:
		_update_combo_hint()


func _arm_card(slot: int) -> void:
	if slot >= hand.get_child_count():
		return
	var card := hand.get_child(slot) as CardUI
	if card == armed_card:
		return
	if not _can_play(card):
		_show_idle("Not enough mana")
		return
	armed_card = card
	combo = COMBOS[card.card.type]
	combo_step = 0
	combo_remaining = maxf(MIN_COMBO_TIME, FIRST_COMBO_TIME - (round_number - 1) * ROUND_TIME_STEP)
	combo_timer.max_value = combo_remaining
	size.y = 33.0
	combo_timer.show()
	card_keys.show()
	hint.text = tooltip_markup.sub(card.card.tooltip_text, "", true)
	_update_combo_hint()
	_refresh_cards()
	set_process(true)


func _enter_direction(key: Key) -> void:
	if key != combo[combo_step]:
		_play_card(1, "Combo missed. Normal play.")
		return
	combo_step += 1
	if combo_step == combo.size():
		_play_card(COMBO_BOOST, "Combo hit! Double effect.")
	else:
		_update_combo_hint()


func _play_card(multiplier: int, feedback: String) -> void:
	var card := armed_card
	if not _can_play(card):
		_show_idle("Choose another card")
		return
	_refresh_enemies()
	if card.card.is_single_targeted() and not _is_alive(selected_enemy):
		_show_idle("Choose a living target")
		return
	if card.card.is_single_targeted():
		card.targets = [selected_enemy]
	else:
		card.targets = [hand]
	_show_idle(feedback)
	card.play(multiplier)


func _show_idle(feedback: String) -> void:
	armed_card = null
	set_process(false)
	size.y = 22.0
	combo_timer.hide()
	card_keys.hide()
	hint.text = "1-3 Enemy   Space+1-4 Card"
	action.text = feedback
	_refresh_cards()


func _update_combo_hint() -> void:
	var remaining_steps := PackedStringArray()
	for i in range(combo_step, combo.size()):
		remaining_steps.append(DIRECTION_NAMES[combo[i]])
	action.text = "2x %d/%d  %s  %.1fs" % [
		combo_step, combo.size(), " ".join(remaining_steps), combo_remaining]
	combo_timer.value = combo_remaining


func _on_hand_drawn() -> void:
	round_number += 1
	_show_idle("Round %d" % round_number)


func _on_turn_ended() -> void:
	_show_idle("Enemy turn")


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
			_update_badge(enemy, i + 1, enemy == selected_enemy, Vector2(-25, -12))


func _refresh_cards() -> void:
	for card in hand.get_children():
		if card is CardUI and not card.is_queued_for_deletion():
			_update_badge(card, card.get_index() + 1, card == armed_card, Vector2(13, 2))


func _update_badge(node: Node, number: int, selected: bool, offset: Vector2) -> void:
	var badge := node.get_node_or_null("KeyboardSlot") as Label
	if badge == null:
		badge = Label.new()
		badge.name = "KeyboardSlot"
		badge.position = offset
		badge.custom_minimum_size = Vector2(10, 9)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 6)
		node.add_child(badge)
	badge.text = str(number)
	badge.add_theme_stylebox_override("normal", SELECTED_SLOT_STYLE if selected else SLOT_STYLE)
	badge.add_theme_color_override("font_color", Color("#231725") if selected else Color("#fff0d8"))


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
