extends GutTest

const BATTLE := preload("res://scenes/battle/battle.tscn")
const ATTACK := preload("res://characters/warrior/cards/warrior_axe_attack.tres")
const BLOCK := preload("res://characters/warrior/cards/warrior_block.tres")
const SWEEP := preload("res://characters/warrior/cards/warrior_sweep_attack.tres")
const MANA_SURGE := preload("res://characters/warrior/cards/warrior_mana_surge.tres")

var battle: Node2D
var stats: CharacterStats
var hand: Hand
var ghost: Enemy
var goblin: Enemy
var golem: Enemy
var end_turn: Button
var time_scale: float


func before_each() -> void:
	time_scale = Engine.time_scale
	Engine.time_scale = 3.0
	battle = BATTLE.instantiate()
	# The export tests exercise audio startup and shutdown in a separate process.
	battle.music = null
	add_child_autofree(battle)
	stats = battle.player.stats
	hand = battle.battle_ui.hand
	end_turn = battle.battle_ui.end_turn_button
	ghost = battle.enemy_handler.get_node("GhostEnemy")
	goblin = battle.enemy_handler.get_node("GobEnemy")
	golem = battle.enemy_handler.get_node("GolemEnemy")
	await wait_for_signal(Events.player_hand_drawn, 3.0)


func after_each() -> void:
	get_tree().paused = false
	Engine.time_scale = time_scale
	SfxPlayer.stop()
	for sound in SfxPlayer.get_children():
		(sound as AudioStreamPlayer).stream = null


func test_opening_turn_deals_a_hand_and_enables_end_turn() -> void:
	assert_eq(hand.get_child_count(), 4)
	assert_eq(stats.draw_pile.cards.size(), 6)
	assert_eq(stats.mana, 3)
	assert_eq(stats.health, 35)
	assert_false(end_turn.disabled)


func test_card_ui_play_spends_mana_discards_card_and_damages_only_target() -> void:
	var attack := ATTACK.duplicate() as Card
	hand.add_card(attack)
	var card_ui := hand.get_child(hand.get_child_count() - 1) as CardUI
	card_ui.targets = [goblin]
	card_ui.play()
	await wait_until(func() -> bool: return goblin.sprite_2d.material == null, 2.0)

	assert_eq(stats.mana, 2)
	assert_eq(goblin.stats.health, 1)
	assert_eq(ghost.stats.health, 10)
	assert_eq(golem.stats.health, 40)
	assert_has(stats.discard.cards, attack)
	assert_eq(hand.get_child_count(), 4, "Played card leaves the hand")


func test_defence_grants_five_block_to_the_player() -> void:
	BLOCK.play([goblin], stats)
	assert_eq(stats.block, 5)
	assert_eq(stats.mana, 2)
	assert_eq(goblin.stats.block, 0)


func test_sweep_damages_each_enemy_without_hitting_player() -> void:
	SWEEP.play([goblin], stats)
	await wait_until(func() -> bool: return golem.sprite_2d.material == null, 2.0)

	assert_eq(stats.mana, 1)
	assert_eq(stats.health, 35)
	assert_eq(ghost.stats.health, 7)
	assert_eq(goblin.stats.health, 4)
	assert_eq(golem.stats.health, 37)


func test_cards_become_unplayable_when_mana_runs_out() -> void:
	var card := hand.get_child(0) as CardUI
	stats.mana = 0
	assert_false(card.playable)
	stats.reset_mana()
	assert_true(card.playable)


func test_enemy_turn_discards_hand_and_redraws_after_attack() -> void:
	ghost.current_action = ghost.enemy_action_picker.get_node("AttackAction")
	goblin.current_action = goblin.enemy_action_picker.get_node("GobBlockAction")
	golem.current_action = golem.enemy_action_picker.get_node("GolemBlockAction")
	stats.mana = 1
	stats.block = 5
	end_turn.pressed.emit()

	assert_true(end_turn.disabled)
	await wait_for_signal(Events.player_hand_drawn, 6.0)
	assert_eq(stats.health, 33, "Enemy attack deals 7 damage through 5 block")
	assert_eq(stats.block, 0)
	assert_eq(stats.mana, 3)
	assert_eq(hand.get_child_count(), 4)
	assert_eq(stats.discard.cards.size(), 4)
	assert_false(end_turn.disabled)


func test_draw_recycles_discard_only_when_draw_pile_is_empty() -> void:
	stats.discard.add_card(BLOCK)
	battle.player_handler.reshuffle_deck_from_discard()
	assert_eq(stats.discard.cards.size(), 1)
	stats.draw_pile.clear()
	battle.player_handler.reshuffle_deck_from_discard()
	assert_true(stats.discard.empty())
	assert_same(stats.draw_pile.draw_card(), BLOCK)


func test_mana_surge_grants_overflow_after_the_next_hand_only() -> void:
	var surge := MANA_SURGE.duplicate() as Card
	surge.play([goblin], stats)
	assert_eq(stats.mana, 2)

	ghost.current_action = ghost.enemy_action_picker.get_node("BlockAction")
	goblin.current_action = goblin.enemy_action_picker.get_node("GobBlockAction")
	golem.current_action = golem.enemy_action_picker.get_node("GolemBlockAction")
	end_turn.pressed.emit()
	await wait_for_signal(Events.player_hand_drawn, 6.0)
	assert_eq(stats.mana, 5)

	stats.reset_mana()
	Events.player_hand_drawn.emit()
	assert_eq(stats.mana, 3, "Overflow is consumed after one hand")


func test_killing_final_enemy_requests_win_and_pauses_the_battle() -> void:
	watch_signals(Events)
	ghost.take_damage(50)
	goblin.take_damage(50)
	golem.take_damage(50)
	var ended: bool = await wait_for_signal(Events.battle_over_screen_requested, 2.0)
	assert_true(ended, "The battle reports victory after all three enemies die")

	assert_eq(battle.enemy_handler.get_child_count(), 0)
	if ended:
		var result: Array = get_signal_parameters(Events, "battle_over_screen_requested")
		assert_eq(result[1], BattleOverPanel.Type.WIN)
	assert_true(get_tree().paused)
	assert_true(battle.get_node("BattleOverLayer/BattleOverPanel").visible)


func test_lethal_player_damage_requests_loss_and_pauses_the_battle() -> void:
	# Leave the damage flash and shake enough time to finish before the player is freed.
	Engine.time_scale = 1.0
	watch_signals(Events)
	battle.player.take_damage(100)
	var ended: bool = await wait_for_signal(Events.battle_over_screen_requested, 2.0)
	assert_true(ended, "The battle reports a loss after lethal damage")

	assert_eq(stats.health, 0)
	if ended:
		var result: Array = get_signal_parameters(Events, "battle_over_screen_requested")
		assert_eq(result[1], BattleOverPanel.Type.LOSE)
	assert_true(get_tree().paused)
	assert_true(battle.get_node("BattleOverLayer/BattleOverPanel").visible)
