extends GutTest

const BATTLE := preload("res://scenes/battle/battle.tscn")
const ATTACK := preload("res://characters/warrior/cards/warrior_axe_attack.tres")
const BLOCK := preload("res://characters/warrior/cards/warrior_block.tres")

var battle: Node2D
var controls: Node
var stats: CharacterStats
var hand: Hand
var ghost: Enemy
var goblin: Enemy
var golem: Enemy


func before_each() -> void:
	battle = BATTLE.instantiate()
	battle.music = null
	add_child_autofree(battle)
	controls = battle.get_node_or_null("BattleUI/KeyboardBattle")
	stats = battle.player.stats
	hand = battle.battle_ui.hand
	ghost = battle.enemy_handler.get_node("GhostEnemy")
	goblin = battle.enemy_handler.get_node("GobEnemy")
	golem = battle.enemy_handler.get_node("GolemEnemy")
	await wait_for_signal(Events.player_hand_drawn, 3.0)


func after_each() -> void:
	SfxPlayer.stop()
	for sound in SfxPlayer.get_children():
		(sound as AudioStreamPlayer).stream = null


func test_shift_and_number_target_enemies_and_default_to_the_first() -> void:
	assert_not_null(controls, "The battle has keyboard controls")
	if controls == null:
		return
	assert_same(controls.selected_enemy, ghost)
	_press(KEY_3, true)
	assert_same(controls.selected_enemy, golem)
	_press(KEY_6, true)
	assert_same(controls.selected_enemy, golem)


func test_digit_arms_a_card_and_enter_plays_it_at_the_selected_enemy() -> void:
	hand.add_card(ATTACK)
	_press(KEY_2, true)
	_press(KEY_5)
	assert_same(controls.armed_card, hand.get_child(4))
	assert_same(controls.selected_enemy, goblin)
	assert_eq(stats.mana, 3, "Arming does not spend mana")
	_press(KEY_ENTER)
	await wait_until(func() -> bool: return goblin.stats.health == 1 and goblin.sprite_2d.material == null, 2.0)

	assert_eq(goblin.stats.health, 1)
	assert_eq(ghost.stats.health, 10)
	assert_eq(stats.mana, 2)
	assert_eq(hand.get_child_count(), 4)


func test_combo_adds_one_to_the_effect_and_spends_mana_once() -> void:
	hand.add_card(BLOCK)
	_press(KEY_5)
	_press(KEY_LEFT)
	_key(KEY_LEFT, true, true)
	_press(KEY_DOWN)
	_press(KEY_LEFT)

	assert_eq(stats.block, 6)
	assert_eq(stats.mana, 2)


func test_combo_shows_direction_sprites_then_a_temporary_burst() -> void:
	var prompt := controls.get_node_or_null("ComboPrompt") as Control
	assert_not_null(prompt, "The battle has a visual combo prompt")
	if prompt == null:
		return
	assert_false(prompt.visible)
	assert_null(controls.get_node_or_null("Hint"), "No keyboard legend remains")

	hand.add_card(BLOCK)
	_press(KEY_5)
	assert_true(prompt.visible)
	var arrows := prompt.get_node("Arrows")
	assert_eq(arrows.get_child_count(), 3)
	var first := arrows.get_child(0).get_node("Arrow") as Sprite2D
	var second := arrows.get_child(1).get_node("Arrow") as Sprite2D
	assert_not_null(first.texture)
	assert_ne(first.rotation, second.rotation)
	var original_color := first.modulate
	_press(KEY_LEFT)
	assert_ne(first.modulate, original_color, "The completed step lights up")
	_press(KEY_DOWN)
	_press(KEY_LEFT)

	var burst := controls.get_node("ComboBurst") as Node2D
	assert_false(prompt.visible)
	assert_true(burst.visible)
	assert_true(await wait_until(func() -> bool: return not burst.visible, 1.0))


func test_slot_numbers_sit_below_the_art_and_center_on_their_owner() -> void:
	var card := hand.get_child(0) as CardUI
	var card_number := card.get_node("KeyboardSlot") as Control
	var enemy_number := ghost.get_node("KeyboardSlot") as Control
	assert_almost_eq(card_number.position.x + card_number.size.x * 0.5, card.size.x * 0.5, 1.0)
	assert_gt(card_number.position.y, card.size.y * 0.5)
	assert_almost_eq(enemy_number.position.x + enemy_number.size.x * 0.5, 0.0, 1.0)
	assert_gt(enemy_number.position.y, 20.0)


func test_selected_enemy_death_falls_back_without_renumbering() -> void:
	if controls == null:
		fail_test("The battle has keyboard controls")
		return
	ghost.stats.health = 7
	hand.add_card(ATTACK)
	_press(KEY_5)
	_press(KEY_UP)
	_press(KEY_RIGHT)
	_press(KEY_DOWN)
	await wait_until(func() -> bool: return not is_instance_valid(ghost), 2.0)

	assert_false(is_instance_valid(ghost))
	assert_same(controls.selected_enemy, goblin)
	_press(KEY_3, true)
	assert_same(controls.selected_enemy, golem)


func test_wrong_arrow_and_timeout_play_the_normal_card() -> void:
	assert_not_null(controls, "The battle has keyboard controls")
	if controls == null:
		return
	hand.add_card(BLOCK)
	_press(KEY_5)
	_press(KEY_RIGHT)
	assert_eq(stats.block, 5)
	await wait_process_frames(2)
	hand.add_card(BLOCK)
	_press(KEY_5)
	controls._process(6.0)
	assert_eq(stats.block, 10)
	assert_eq(stats.mana, 1)


func test_escape_cancels_without_spending_and_pressing_enter_ends_the_turn() -> void:
	hand.add_card(BLOCK)
	_press(KEY_5)
	_press(KEY_ESCAPE)
	assert_eq(stats.mana, 3)
	assert_eq(stats.block, 0)
	watch_signals(Events)
	_press(KEY_ENTER)
	assert_signal_emitted(Events.player_turn_ended)
	assert_true(battle.battle_ui.end_turn_button.disabled)


func test_later_hands_have_less_combo_time_with_a_floor() -> void:
	assert_not_null(controls, "The battle has keyboard controls")
	if controls == null:
		return
	hand.add_card(BLOCK)
	_press(KEY_5)
	assert_eq(controls.combo_timer.max_value, 5.0)
	_press(KEY_ESCAPE)
	Events.player_hand_drawn.emit()
	_press(KEY_5)
	assert_eq(controls.combo_timer.max_value, 4.5)
	_press(KEY_ESCAPE)
	for i in range(14):
		Events.player_hand_drawn.emit()
	_press(KEY_5)
	assert_eq(controls.combo_timer.max_value, 1.5)


func _press(key: Key, shift := false) -> void:
	_key(key, true, false, shift)
	_key(key, false, false, shift)


func _key(value: Key, pressed: bool, echo := false, shift := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = value
	event.pressed = pressed
	event.echo = echo
	event.shift_pressed = shift
	get_viewport().push_input(event)
