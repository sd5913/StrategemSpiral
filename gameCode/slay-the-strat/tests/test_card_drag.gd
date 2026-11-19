extends GutTest

const BATTLE := preload("res://scenes/battle/battle.tscn")
const ATTACK := preload("res://characters/warrior/cards/warrior_axe_attack.tres")
const BLOCK := preload("res://characters/warrior/cards/warrior_block.tres")

var battle: Node2D
var stats: CharacterStats
var hand: Hand
var goblin: Enemy
var viewport: SubViewport


func before_each() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(256, 144)
	viewport.world_2d = World2D.new()
	add_child_autofree(viewport)
	battle = BATTLE.instantiate()
	battle.music = null
	viewport.add_child(battle)
	stats = battle.player.stats
	hand = battle.battle_ui.hand
	goblin = battle.enemy_handler.get_node("GobEnemy")
	await wait_for_signal(Events.player_hand_drawn, 3.0)


func after_each() -> void:
	_mouse_motion(Vector2.ZERO, Vector2.ZERO, false)
	SfxPlayer.stop()
	for sound in SfxPlayer.get_children():
		(sound as AudioStreamPlayer).stream = null


func test_one_held_drag_and_release_plays_an_attack() -> void:
	var card: CardUI = await _add_card(ATTACK)
	var start := card.get_global_rect().get_center()
	var target := goblin.get_global_transform_with_canvas().origin
	_mouse_motion(start, start, false)
	_mouse_button(start, true)
	assert_eq(card.card_state_machine.current_state.state, CardStates.State.CLICKED)
	_mouse_motion(start, target)
	assert_ne(card.get_parent(), hand, "The card leaves the hand while the mouse is held")
	assert_false(card.get_node("KeyboardSlot").visible, "A dragged card has no hand shortcut")
	_mouse_button(target, false)
	await wait_until(func() -> bool: return goblin.stats.health == 1 and goblin.sprite_2d.material == null, 1.5)

	assert_eq(goblin.stats.health, 1)
	assert_eq(stats.mana, 2)
	assert_false(is_instance_valid(card))


func test_attack_dropped_on_empty_space_returns_to_its_slot() -> void:
	var card: CardUI = await _add_card(ATTACK)
	var start := card.get_global_rect().get_center()
	var empty := Vector2(122, 52)
	_mouse_motion(start, start, false)
	_mouse_button(start, true)
	_mouse_motion(start, empty)
	_mouse_button(empty, false)
	await wait_process_frames(2)

	assert_same(card.get_parent(), hand)
	assert_eq(card.get_index(), 4)
	assert_true(card.get_node("KeyboardSlot").visible)
	assert_eq(card.card_state_machine.current_state.state, CardStates.State.BASE)
	assert_eq(stats.mana, 3)
	assert_eq(goblin.stats.health, 7)


func test_block_card_plays_when_released_over_the_battlefield() -> void:
	var card: CardUI = await _add_card(BLOCK)
	var start := card.get_global_rect().get_center()
	var destination := Vector2(120, 54)
	_mouse_motion(start, start, false)
	_mouse_button(start, true)
	_mouse_motion(start, destination)
	_mouse_button(destination, false)
	await wait_process_frames(2)

	assert_eq(stats.block, 5)
	assert_eq(stats.mana, 2)
	assert_false(is_instance_valid(card))


func test_plain_click_leaves_the_card_in_the_hand() -> void:
	var card: CardUI = await _add_card(ATTACK)
	var start := card.get_global_rect().get_center()
	_mouse_motion(start, start, false)
	_mouse_button(start, true)
	assert_eq(card.card_state_machine.current_state.state, CardStates.State.CLICKED)
	_mouse_button(start, false)

	assert_same(card.get_parent(), hand)
	assert_eq(card.card_state_machine.current_state.state, CardStates.State.BASE)
	assert_eq(stats.mana, 3)


func _add_card(resource: Card) -> CardUI:
	hand.add_card(resource)
	await wait_process_frames(2)
	await wait_physics_frames(2)
	return hand.get_child(4) as CardUI


func _mouse_button(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	viewport.push_input(event, true)


func _mouse_motion(from: Vector2, to: Vector2, held := true) -> void:
	var event := InputEventMouseMotion.new()
	event.position = to
	event.global_position = to
	event.relative = to - from
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	viewport.push_input(event, true)
