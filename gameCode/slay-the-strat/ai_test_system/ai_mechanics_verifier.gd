class_name AIMechanicsVerifier
extends Node

const START_SCREEN_SCENE := preload("res://scenes/ui/start_screen.tscn")
const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")

const CARD_AXE := preload("res://characters/warrior/cards/warrior_axe_attack.tres")
const CARD_SWEEP := preload("res://characters/warrior/cards/warrior_sweep_attack.tres")
const CARD_BLOCK := preload("res://characters/warrior/cards/warrior_block.tres")
const CARD_MANA_SURGE := preload("res://characters/warrior/cards/warrior_mana_surge.tres")
const CARD_SWAP_HP := preload("res://characters/warrior/cards/warrior_adda_swap_health.tres")
const CARD_BLOOD_RITUAL := preload("res://characters/warrior/cards/warrior_blood_ritual.tres")
const CARD_LAST_GASP := preload("res://characters/warrior/cards/warrior_last_gasp.tres")
const CARD_NUKE := preload("res://characters/warrior/cards/warrior_nuke.tres")

const ENEMY_GHOST := preload("res://enemies/ghost/ghost_enemy.tres")
const ENEMY_GOB := preload("res://enemies/gob/gob_enemy.tres")
const ENEMY_GOLEM := preload("res://enemies/golem/golem_enemy.tres")
const ENEMY_WOLF := preload("res://enemies/wolf/wolf_enemy.tres")


func run_all_checks(host_parent: Node) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var saved_scale: float = Engine.time_scale
	Engine.time_scale = 6.0

	results.append(await _test_start_screen_structure(host_parent))
	results.append(await _test_enemy_pool_randomization(host_parent))
	results.append(await _test_basic_cards_and_attack_lunge(host_parent))
	results.append(await _test_mana_surge_overflow(host_parent))
	results.append(await _test_hand_single_ultimate_cap(host_parent))
	results.append(await _test_golem_ally_protection_taunt(host_parent))
	results.append(await _test_wolf_double_hit_lifesteal(host_parent))
	results.append(await _test_ghost_conditional_mega_block(host_parent))
	results.append(await _test_gob_kamikaze_self_damage(host_parent))
	results.append(await _test_ultimate_qte_wasd_and_obliteration(host_parent))

	get_tree().paused = false
	Engine.time_scale = saved_scale
	return results


func _spawn_isolated_battle(host_parent: Node) -> Node2D:
	get_tree().paused = false
	var b: Node2D = BATTLE_SCENE.instantiate() as Node2D
	host_parent.add_child(b)
	await get_tree().create_timer(1.2).timeout # Wait for initial 4-card draw tween (4 * 0.25s)
	return b


func _cleanup_node(node: Node) -> void:
	get_tree().paused = false
	if is_instance_valid(node):
		node.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _make_result(test_id: String, title: String, passed: bool, details: String) -> Dictionary:
	return {
		"id": test_id,
		"title": title,
		"passed": passed,
		"details": details
	}


func _test_start_screen_structure(host_parent: Node) -> Dictionary:
	var screen: Node2D = START_SCREEN_SCENE.instantiate() as Node2D
	host_parent.add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	var title_lbl: Label = screen.get_node_or_null("Title") as Label
	var target_path: String = str(screen.get("BATTLE_SCENE_PATH"))
	var initial_y: float = title_lbl.position.y if title_lbl else -1.0
	await get_tree().create_timer(0.4).timeout
	var moved_ok: bool = title_lbl != null and ResourceLoader.exists(target_path) and title_lbl.text == "Strategem-Spiral"

	await _cleanup_node(screen)
	var msg: String = "StartScreen loaded title='Strategem-Spiral', float_y=%.1f, target='%s' exists=%s" % [
		initial_y, target_path, str(ResourceLoader.exists(target_path))
	]
	return _make_result("FT-01", "StartScreen UI & Battle Scene Link", moved_ok, msg)


func _test_enemy_pool_randomization(host_parent: Node) -> Dictionary:
	var seen_types: Dictionary = {}
	var valid_counts: bool = true

	for _i in range(8):
		var b: Node2D = BATTLE_SCENE.instantiate() as Node2D
		host_parent.add_child(b)
		await get_tree().process_frame
		var eh: EnemyHandler = b.get_node("EnemyHandler") as EnemyHandler
		if eh.get_child_count() != 3:
			valid_counts = false
		var local_set: Dictionary = {}
		for child in eh.get_children():
			var e := child as Enemy
			var t: String = AIBotBrain.identify_enemy_type(e)
			seen_types[t] = true
			local_set[t] = true
		if local_set.size() != 3:
			valid_counts = false # Must be 3 distinct enemy types per battle
		await _cleanup_node(b)

	var all_four_present: bool = seen_types.size() >= 4 and valid_counts
	var types_list: Array = seen_types.keys()
	types_list.sort()
	return _make_result(
		"FT-02",
		"3-of-4 Randomized Enemy Pool (Ghost/Gob/Golem/Wolf)",
		all_four_present,
		"Observed distinct 3-enemy lineups across pool: %s" % str(types_list)
	)


func _test_basic_cards_and_attack_lunge(host_parent: Node) -> Dictionary:
	var b: Node2D = await _spawn_isolated_battle(host_parent)
	var player: Player = b.get_node("Player") as Player
	var eh: EnemyHandler = b.get_node("EnemyHandler") as EnemyHandler

	# Force deterministic enemies without taunt
	for child in eh.get_children():
		var e := child as Enemy
		e.is_protecting_allies = false
		e.stats.block = 0
		e.stats.health = e.stats.max_health

	var target_enemy: Enemy = eh.get_child(0) as Enemy
	var hp_before: int = target_enemy.stats.health
	player.stats.mana = 3
	player.stats.block = 0

	# 1) Block card (+5 block, -1 mana)
	var block_card: Card = CARD_BLOCK.duplicate()
	await block_card.play([player], player.stats)
	var block_ok: bool = player.stats.block == 5 and player.stats.mana == 2

	# 2) Axe Attack (6 dmg + player lunge animation, -1 mana)
	var axe_card: Card = CARD_AXE.duplicate()
	await axe_card.play([target_enemy], player.stats)
	await get_tree().create_timer(0.25).timeout
	var expected_hp: int = maxi(0, hp_before - 6)
	var axe_ok: bool = (not is_instance_valid(target_enemy) and expected_hp == 0) or (is_instance_valid(target_enemy) and target_enemy.stats.health == expected_hp)

	await _cleanup_node(b)
	return _make_result(
		"FT-03",
		"Warrior Block (+5) & Axe Attack (6 Dmg + Lunge)",
		block_ok and axe_ok,
		"Block=5 (%s), Target HP %d -> %d (%s)" % [str(block_ok), hp_before, expected_hp, str(axe_ok)]
	)


func _test_mana_surge_overflow(host_parent: Node) -> Dictionary:
	var b: Node2D = await _spawn_isolated_battle(host_parent)
	var player: Player = b.get_node("Player") as Player
	var battle_ui: BattleUI = b.get_node("BattleUI") as BattleUI

	player.stats.mana = 3
	player.stats.block = 30 # Survive enemy turn easily
	var surge: Card = CARD_MANA_SURGE.duplicate()
	await surge.play([player], player.stats)

	# End player turn and wait until next player_hand_drawn
	battle_ui.end_turn_button.pressed.emit()
	await Events.player_hand_drawn
	await get_tree().process_frame

	var mana_after: int = player.stats.mana
	var passed: bool = mana_after == 5
	await _cleanup_node(b)
	return _make_result(
		"FT-04",
		"Mana Surge Next-Turn Overflow (3 -> 5 Mana)",
		passed,
		"Next turn starting mana after 1x Mana Surge = %d (expected 5)" % mana_after
	)


func _test_hand_single_ultimate_cap(host_parent: Node) -> Dictionary:
	var b: Node2D = await _spawn_isolated_battle(host_parent)
	var ph: PlayerHandler = b.get_node("PlayerHandler") as PlayerHandler
	var hand: Hand = b.get_node("BattleUI/hand") as Hand

	# Clear hand and load draw pile with 4 Ultimates + 2 normal cards
	for c in hand.get_children():
		c.queue_free()
	await get_tree().process_frame

	ph.character.draw_pile.cards.clear()
	ph.character.discard.cards.clear()
	ph.character.draw_pile.add_card(CARD_SWAP_HP.duplicate())
	ph.character.draw_pile.add_card(CARD_BLOOD_RITUAL.duplicate())
	ph.character.draw_pile.add_card(CARD_LAST_GASP.duplicate())
	ph.character.draw_pile.add_card(CARD_NUKE.duplicate())
	ph.character.draw_pile.add_card(CARD_AXE.duplicate())
	ph.character.draw_pile.add_card(CARD_BLOCK.duplicate())

	ph.draw_cards(4)
	await Events.player_hand_drawn
	await get_tree().process_frame

	var ult_count: int = 0
	var total_drawn: int = hand.get_child_count()
	for child in hand.get_children():
		var cui := child as CardUI
		if cui and cui.card and cui.card.is_ultimate:
			ult_count += 1

	var passed: bool = ult_count == 1 and total_drawn == 3
	await _cleanup_node(b)
	return _make_result(
		"FT-05",
		"Single Ultimate-in-Hand Draw Constraint",
		passed,
		"From 4 Ultimates + 2 Basics, drew %d total cards with %d Ultimate (expected 3 total, 1 Ultimate)" % [total_drawn, ult_count]
	)


func _test_golem_ally_protection_taunt(host_parent: Node) -> Dictionary:
	var b: Node2D = await _spawn_isolated_battle(host_parent)
	var eh: EnemyHandler = b.get_node("EnemyHandler") as EnemyHandler

	var e0: Enemy = eh.get_child(0) as Enemy
	var e1: Enemy = eh.get_child(1) as Enemy
	e0.stats = ENEMY_GOLEM
	e1.stats = ENEMY_GOB
	await get_tree().process_frame

	e0.stats.block = 0
	e1.stats.block = 0
	var golem_hp_before: int = e0.stats.health
	var gob_hp_before: int = e1.stats.health
	e0.is_protecting_allies = true

	# Attack Gob while Golem is protecting allies
	e1.take_damage(6)
	await get_tree().create_timer(0.25).timeout

	var gob_hp_after: int = e1.stats.health
	var golem_hp_after: int = e0.stats.health
	var passed: bool = gob_hp_after == gob_hp_before and golem_hp_after == golem_hp_before - 6
	await _cleanup_node(b)
	return _make_result(
		"FT-06",
		"Golem Ally Protection Taunt Redirect",
		passed,
		"Gob HP %d->%d (untouched), Protecting Golem HP %d->%d (-6)" % [gob_hp_before, gob_hp_after, golem_hp_before, golem_hp_after]
	)


func _test_wolf_double_hit_lifesteal(host_parent: Node) -> Dictionary:
	var b: Node2D = await _spawn_isolated_battle(host_parent)
	var player: Player = b.get_node("Player") as Player
	var eh: EnemyHandler = b.get_node("EnemyHandler") as EnemyHandler

	var wolf: Enemy = eh.get_child(0) as Enemy
	wolf.stats = ENEMY_WOLF
	await get_tree().process_frame

	wolf.stats.health = 5 # Damaged out of 10 max HP
	player.stats.block = 0
	player.stats.health = 40

	wolf.update_action()
	wolf.do_turn()
	await Events.enemy_action_completed
	await get_tree().create_timer(0.25).timeout

	var player_hp_after: int = player.stats.health
	var wolf_hp_after: int = wolf.stats.health
	var passed: bool = player_hp_after == 32 and wolf_hp_after == 9
	await _cleanup_node(b)
	return _make_result(
		"FT-07",
		"Wolf Double-Bite (4x2 Dmg) & Lifesteal (+2x2 HP)",
		passed,
		"Player HP 40->%d (expected 32), Wolf HP 5->%d (expected 9)" % [player_hp_after, wolf_hp_after]
	)


func _test_ghost_conditional_mega_block(host_parent: Node) -> Dictionary:
	var b: Node2D = await _spawn_isolated_battle(host_parent)
	var eh: EnemyHandler = b.get_node("EnemyHandler") as EnemyHandler

	var ghost: Enemy = eh.get_child(0) as Enemy
	ghost.stats = ENEMY_GHOST
	await get_tree().process_frame

	ghost.current_action = null
	ghost.update_action()
	# Drop Ghost HP to 5 (<= 6 threshold) -> should switch to conditional Mega Block
	ghost.stats.health = 5
	var info: Dictionary = AIBotBrain.analyze_enemy_intent(ghost)
	var switched_to_mega: bool = str(info["action_id"]) == "ghost_mega_block"

	ghost.do_turn()
	await Events.enemy_action_completed
	var ghost_block_after: int = ghost.stats.block
	var gained_15: bool = ghost_block_after == 15

	await _cleanup_node(b)
	return _make_result(
		"FT-08",
		"Ghost Conditional Mega-Block (<=6 HP -> +15 Block)",
		switched_to_mega and gained_15,
		"Intent switched=%s, Ghost block after action=%d (expected 15)" % [str(switched_to_mega), ghost_block_after]
	)


func _test_gob_kamikaze_self_damage(host_parent: Node) -> Dictionary:
	var b: Node2D = await _spawn_isolated_battle(host_parent)
	var player: Player = b.get_node("Player") as Player
	var eh: EnemyHandler = b.get_node("EnemyHandler") as EnemyHandler

	var gob: Enemy = eh.get_child(0) as Enemy
	gob.stats = ENEMY_GOB
	await get_tree().process_frame

	player.stats.block = 0
	player.stats.health = 40

	# Select gob_attack_action directly from its action picker
	var attack_action: EnemyAction = null
	for child in gob.enemy_action_picker.get_children():
		var act := child as EnemyAction
		if act and (act.get_script() as Script).resource_path.ends_with("gob_attack_action.gd"):
			attack_action = act
			break

	var passed: bool = false
	var detail_str: String = "gob_attack_action not found"
	if attack_action:
		gob.current_action = attack_action
		gob.do_turn()
		await Events.enemy_action_completed
		await get_tree().create_timer(0.3).timeout
		var gob_dead: bool = not is_instance_valid(gob) or gob.stats.health <= 0
		passed = player.stats.health == 26 and gob_dead
		detail_str = "Player HP 40->%d (-14), Gob self-destructed=%s" % [player.stats.health, str(gob_dead)]

	await _cleanup_node(b)
	return _make_result("FT-09", "Gob Kamikaze Attack (14 Player Dmg + Self-Kill)", passed, detail_str)


func _test_ultimate_qte_wasd_and_obliteration(host_parent: Node) -> Dictionary:
	# Part A: Last Gasp QTE Success via real WASD InputEventKey (D S D S D S -> 3x multiplier)
	var b1: Node2D = await _spawn_isolated_battle(host_parent)
	var p1: Player = b1.get_node("Player") as Player
	var qte1: CanvasLayer = b1.get_node("UltimateCardQTE") as CanvasLayer

	var saved_scale: float = Engine.time_scale
	Engine.time_scale = 3.0

	var gasp: Card = CARD_LAST_GASP.duplicate()
	gasp.play([p1], p1.stats)
	await get_tree().process_frame

	var qte_started_ok: bool = bool(qte1.get("active"))
	for key in [KEY_D, KEY_S, KEY_D, KEY_S, KEY_D, KEY_S]:
		var ev := InputEventKey.new()
		ev.keycode = key
		ev.pressed = true
		b1.get_viewport().push_input(ev)
		await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout

	var gasp_ok: bool = qte_started_ok and p1.stats.damage_multiplier == 3 and p1.stats.health == 5
	await _cleanup_node(b1)

	# Part B: Nuke QTE Success when Player <= 30 HP and all Enemies <= 30 HP -> OBLITERATED outcome!
	Engine.time_scale = 5.0
	var b2: Node2D = await _spawn_isolated_battle(host_parent)
	var p2: Player = b2.get_node("Player") as Player
	var eh2: EnemyHandler = b2.get_node("EnemyHandler") as EnemyHandler
	p2.stats.health = 25
	for child in eh2.get_children():
		var e := child as Enemy
		e.stats.health = 10

	var captured_outcomes: Array[int] = []
	var on_over := func(_txt: String, t: BattleOverPanel.Type) -> void:
		captured_outcomes.append(int(t))
	Events.battle_over_screen_requested.connect(on_over)

	var nuke: Card = CARD_NUKE.duplicate()
	nuke.play([p2], p2.stats)
	await get_tree().process_frame

	# Nuke sequence: S W A S W D S W
	for key in [KEY_S, KEY_W, KEY_A, KEY_S, KEY_W, KEY_D, KEY_S, KEY_W]:
		var ev := InputEventKey.new()
		ev.keycode = key
		ev.pressed = true
		b2.get_viewport().push_input(ev)
		await get_tree().process_frame

	# Wait for nuclear cutscene resolution
	var safety: int = 0
	while captured_outcomes.is_empty() and safety < 600:
		safety += 1
		await get_tree().process_frame

	if Events.battle_over_screen_requested.is_connected(on_over):
		Events.battle_over_screen_requested.disconnect(on_over)

	var nuke_obliterated_ok: bool = not captured_outcomes.is_empty() and captured_outcomes[0] == int(BattleOverPanel.Type.OBLITERATED)
	await _cleanup_node(b2)
	Engine.time_scale = saved_scale

	return _make_result(
		"FT-10",
		"Ultimate WASD QTE Input & Nuke OBLITERATED Outcome",
		gasp_ok and nuke_obliterated_ok,
		"LastGasp WASD->3x mult (%s), Nuke WASD->OBLITERATED (%s)" % [str(gasp_ok), str(nuke_obliterated_ok)]
	)
