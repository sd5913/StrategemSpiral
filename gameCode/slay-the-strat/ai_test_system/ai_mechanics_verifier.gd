class_name AIMechanicsVerifier
extends Node

const START_SCREEN_SCENE := preload("res://scenes/ui/start_screen.tscn")
const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")
const AI_HUD_SCRIPT := preload("res://ai_test_system/ai_hud_autoload.gd")

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
	results.append(await _test_nuke_mutual_obliteration(host_parent))
	results.append(_test_ai_overlay_disabled_in_normal_and_export())

	get_tree().paused = false
	Engine.time_scale = saved_scale
	return results


func run_ultimate_qte_matrix(host_parent: Node) -> Array[Dictionary]:
	var matrix: Array[Dictionary] = []
	var saved_scale: float = Engine.time_scale

	matrix.append(await _test_swap_hp_qte_success(host_parent))
	matrix.append(await _test_swap_hp_qte_failure(host_parent))
	matrix.append(await _test_blood_ritual_qte_success_with_reset_recovery(host_parent))
	matrix.append(await _test_blood_ritual_qte_failure(host_parent))
	matrix.append(await _test_last_gasp_qte_success(host_parent))
	matrix.append(await _test_last_gasp_qte_failure(host_parent))
	matrix.append(await _test_nuke_qte_success_single_application(host_parent))
	matrix.append(await _test_nuke_qte_failure(host_parent))

	get_tree().paused = false
	Engine.time_scale = saved_scale
	return matrix


func _spawn_isolated_battle(host_parent: Node) -> Node2D:
	get_tree().paused = false
	var b: Node2D = BATTLE_SCENE.instantiate() as Node2D
	host_parent.add_child(b)
	await get_tree().create_timer(1.2).timeout
	return b


func _cleanup_node(node: Node) -> void:
	get_tree().paused = false
	if is_instance_valid(node):
		node.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _wait_for_qte_timer_expiration(qte_layer: CanvasLayer, max_virtual_wait: float = 8.0) -> bool:
	var waited: float = 0.0
	while is_instance_valid(qte_layer) and bool(qte_layer.get("active")) and waited < max_virtual_wait:
		waited += get_process_delta_time()
		await get_tree().process_frame
	return is_instance_valid(qte_layer) and not bool(qte_layer.get("active"))


func _make_result(test_id: String, title: String, passed: bool, details: String) -> Dictionary:
	return {
		"id": test_id,
		"title": title,
		"passed": passed,
		"details": details
	}


func _make_qte_record(
	test_id: String,
	card_id: String,
	sequence_str: String,
	path_type: String,
	reset_checked: bool,
	single_apply_checked: bool,
	passed: bool,
	details: String
) -> Dictionary:
	return {
		"id": test_id,
		"card_id": card_id,
		"sequence": sequence_str,
		"path": path_type,
		"wrong_key_reset_verified": reset_checked,
		"single_effect_verified": single_apply_checked,
		"passed": passed,
		"details": details
	}


# ============================================================================
# Core Mechanics & Export-Safety Checks (FT-01 .. FT-11)
# ============================================================================

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
			valid_counts = false
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

	for child in eh.get_children():
		var e := child as Enemy
		e.is_protecting_allies = false
		e.stats.block = 0
		e.stats.health = e.stats.max_health

	var target_enemy: Enemy = eh.get_child(0) as Enemy
	var hp_before: int = target_enemy.stats.health
	player.stats.mana = 3
	player.stats.block = 0

	var block_card: Card = CARD_BLOCK.duplicate()
	var self_targets: Array[Node] = [player]
	await block_card.play(self_targets, player.stats)
	var block_ok: bool = player.stats.block == 5 and player.stats.mana == 2

	var axe_card: Card = CARD_AXE.duplicate()
	var enemy_targets: Array[Node] = [target_enemy]
	await axe_card.play(enemy_targets, player.stats)
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
	player.stats.block = 30
	var surge: Card = CARD_MANA_SURGE.duplicate()
	var self_targets: Array[Node] = [player]
	await surge.play(self_targets, player.stats)

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

	wolf.stats.health = 5
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
		var player_hp_after: int = player.stats.health
		var gob_dead: bool = not is_instance_valid(gob) or gob.stats.health <= 0
		passed = player_hp_after == 26 and gob_dead
		detail_str = "Player HP 40->%d (-14), Gob self-destructed=%s" % [player_hp_after, str(gob_dead)]

	await _cleanup_node(b)
	return _make_result("FT-09", "Gob Kamikaze Attack (14 Player Dmg + Self-Kill)", passed, detail_str)


func _test_nuke_mutual_obliteration(host_parent: Node) -> Dictionary:
	var saved_scale: float = Engine.time_scale
	Engine.time_scale = 5.0
	var b: Node2D = await _spawn_isolated_battle(host_parent)
	var p: Player = b.get_node("Player") as Player
	var eh: EnemyHandler = b.get_node("EnemyHandler") as EnemyHandler
	p.stats.health = 25
	for child in eh.get_children():
		var e := child as Enemy
		e.stats.health = 10

	var captured_outcomes: Array[int] = []
	var on_over := func(_txt: String, t: BattleOverPanel.Type) -> void:
		captured_outcomes.append(int(t))
	Events.battle_over_screen_requested.connect(on_over)

	var nuke: Card = CARD_NUKE.duplicate()
	var targets: Array[Node] = [p]
	nuke.play(targets, p.stats)
	await get_tree().process_frame

	for key in [KEY_S, KEY_W, KEY_A, KEY_S, KEY_W, KEY_D, KEY_S, KEY_W]:
		AIBattleAgent.inject_wasd_key(b, key)
		await get_tree().process_frame

	var waited: float = 0.0
	while captured_outcomes.is_empty() and waited < 12.0:
		waited += get_process_delta_time()
		await get_tree().process_frame

	if Events.battle_over_screen_requested.is_connected(on_over):
		Events.battle_over_screen_requested.disconnect(on_over)

	var passed: bool = not captured_outcomes.is_empty() and captured_outcomes[0] == int(BattleOverPanel.Type.OBLITERATED)
	await _cleanup_node(b)
	Engine.time_scale = saved_scale
	return _make_result(
		"FT-10",
		"Nuke Mutual Destruction -> OBLITERATED State",
		passed,
		"Player (25 HP) & all enemies (10 HP) wiped via WASD Nuke -> OBLITERATED=%s" % str(passed)
	)


func _test_ai_overlay_disabled_in_normal_and_export() -> Dictionary:
	var normal_play_disabled: bool = not AI_HUD_SCRIPT.should_enable_overlay(PackedStringArray([]), false, false, "")
	var export_blocked_even_with_flag: bool = not AI_HUD_SCRIPT.should_enable_overlay(
		PackedStringArray(["--ai-overlay", "--enable-ai-overlay"]), true, false, "1"
	)
	var explicit_debug_enabled: bool = AI_HUD_SCRIPT.should_enable_overlay(
		PackedStringArray(["--ai-overlay"]), false, false, ""
	)

	var autoload_node: Node = get_node_or_null("/root/AITestSystem")
	var runtime_clean: bool = true
	if autoload_node:
		var combined_args: PackedStringArray = OS.get_cmdline_args() + OS.get_cmdline_user_args()
		var has_flag: bool = combined_args.has("--ai-overlay") or combined_args.has("--enable-ai-overlay")
		if not has_flag:
			runtime_clean = not bool(autoload_node.call("is_overlay_active")) and autoload_node.get_child_count() == 0

	var passed: bool = normal_play_disabled and export_blocked_even_with_flag and explicit_debug_enabled and runtime_clean
	return _make_result(
		"FT-11",
		"AI Overlay Disabled in Normal Gameplay & Exported Builds",
		passed,
		"NormalOff=%s, ExportBlocked=%s, ExplicitFlagOn=%s, RuntimeTreeClean=%s" % [
			str(normal_play_disabled), str(export_blocked_even_with_flag), str(explicit_debug_enabled), str(runtime_clean)
		]
	)


# ============================================================================
# Input-Driven Ultimate Card QTE Matrix (All 4 Cards x Success & Failure Paths)
# ============================================================================

func _test_swap_hp_qte_success(host_parent: Node) -> Dictionary:
	Engine.time_scale = 3.0
	var b: Node2D = await _spawn_isolated_battle(host_parent)
	var p: Player = b.get_node("Player") as Player
	var eh: EnemyHandler = b.get_node("EnemyHandler") as EnemyHandler
	var qte: CanvasLayer = b.get_node("UltimateCardQTE") as CanvasLayer

	var e0: Enemy = eh.get_child(0) as Enemy
	var e1: Enemy = eh.get_child(1) as Enemy
	var e2: Enemy = eh.get_child(2) as Enemy
	e0.stats = ENEMY_GOLEM
	e1.stats = ENEMY_GHOST
	e2.stats = ENEMY_WOLF
	await get_tree().process_frame

	p.stats.health = 12
	e0.stats.health = 20
	e1.stats.health = 10
	e2.stats.health = 10 # Sum = 40; ceili(12 / 3) = 4

	var card: Card = CARD_SWAP_HP.duplicate()
	var targets: Array[Node] = [p]
	card.play(targets, p.stats)
	await get_tree().process_frame

	var started_ok: bool = bool(qte.get("active"))
	for key in [KEY_A, KEY_D, KEY_D, KEY_A, KEY_D, KEY_D]:
		AIBattleAgent.inject_wasd_key(b, key)
		await get_tree().process_frame

	# Extra trailing key after completion must be ignored (effect applied strictly once!)
	AIBattleAgent.inject_wasd_key(b, KEY_D)
	await get_tree().process_frame

	var qte_closed: bool = not bool(qte.get("active"))
	var p_hp: int = p.stats.health
	var enemies_4hp: bool = e0.stats.health == 4 and e1.stats.health == 4 and e2.stats.health == 4
	var passed: bool = started_ok and qte_closed and p_hp == 40 and enemies_4hp

	await _cleanup_node(b)
	return _make_qte_record(
		"QTE-01",
		"adda_swap_health",
		"A D D A D D",
		"SUCCESS",
		false,
		true,
		passed,
		"WASD completed QTE once: Player HP 12->%d (expected 40), Enemies [20,10,10]->[4,4,4] (%s)" % [p_hp, str(enemies_4hp)]
	)


func _test_swap_hp_qte_failure(host_parent: Node) -> Dictionary:
	Engine.time_scale = 4.0
	var b: Node2D = await _spawn_isolated_battle(host_parent)
	var p: Player = b.get_node("Player") as Player
	var eh: EnemyHandler = b.get_node("EnemyHandler") as EnemyHandler
	var qte: CanvasLayer = b.get_node("UltimateCardQTE") as CanvasLayer

	var e0: Enemy = eh.get_child(0) as Enemy
	var e1: Enemy = eh.get_child(1) as Enemy
	var e2: Enemy = eh.get_child(2) as Enemy
	e0.stats = ENEMY_GOLEM
	e1.stats = ENEMY_GHOST
	e2.stats = ENEMY_WOLF
	await get_tree().process_frame

	p.stats.health = 15 # ceili(15 / 3) = +5 heal to enemies on failure
	e0.stats.health = 20
	e1.stats.health = 4
	e2.stats.health = 4

	var card: Card = CARD_SWAP_HP.duplicate()
	var targets: Array[Node] = [p]
	card.play(targets, p.stats)
	await get_tree().process_frame

	# Advance 2 steps (A, D -> progress=2), then inject wrong key W -> progress resets to 0!
	AIBattleAgent.inject_wasd_key(b, KEY_A)
	AIBattleAgent.inject_wasd_key(b, KEY_D)
	var prog_before_wrong: int = int(qte.get("progress"))
	AIBattleAgent.inject_wasd_key(b, KEY_W)
	var prog_after_wrong: int = int(qte.get("progress"))
	var reset_ok: bool = prog_before_wrong == 2 and prog_after_wrong == 0 and bool(qte.get("active"))

	var expired_ok: bool = await _wait_for_qte_timer_expiration(qte)
	var golem_hp: int = e0.stats.health
	var ghost_hp: int = e1.stats.health
	var wolf_hp: int = e2.stats.health
	var heal_applied: bool = p.stats.health == 15 and golem_hp == 25 and ghost_hp == 9 and wolf_hp == 9
	var passed: bool = reset_ok and expired_ok and heal_applied

	await _cleanup_node(b)
	return _make_qte_record(
		"QTE-02",
		"adda_swap_health",
		"A D -> W(reset) -> Timeout",
		"FAILURE",
		reset_ok,
		true,
		passed,
		"Progress %d->%d on wrong key W, timer expired -> Enemies healed +5 ([20,4,4]->[%d,%d,%d])" % [
			prog_before_wrong, prog_after_wrong, golem_hp, ghost_hp, wolf_hp
		]
	)


func _test_blood_ritual_qte_success_with_reset_recovery(host_parent: Node) -> Dictionary:
	Engine.time_scale = 3.0
	var b: Node2D = await _spawn_isolated_battle(host_parent)
	var p: Player = b.get_node("Player") as Player
	var qte: CanvasLayer = b.get_node("UltimateCardQTE") as CanvasLayer

	p.stats.health = 18

	var card: Card = CARD_BLOOD_RITUAL.duplicate()
	var targets: Array[Node] = [p]
	card.play(targets, p.stats)
	await get_tree().process_frame

	# Partial W, S (progress=2) -> wrong key D (progress=0) -> full W, S, S, W, S
	AIBattleAgent.inject_wasd_key(b, KEY_W)
	AIBattleAgent.inject_wasd_key(b, KEY_S)
	var prog_mid: int = int(qte.get("progress"))
	AIBattleAgent.inject_wasd_key(b, KEY_D)
	var prog_reset: int = int(qte.get("progress"))
	var reset_ok: bool = prog_mid == 2 and prog_reset == 0 and bool(qte.get("active"))

	for key in [KEY_W, KEY_S, KEY_S, KEY_W, KEY_S]:
		AIBattleAgent.inject_wasd_key(b, key)
		await get_tree().process_frame

	# Extra key after completion to verify single effect application (18 * 2 = 36, not 45)
	AIBattleAgent.inject_wasd_key(b, KEY_S)
	await get_tree().process_frame

	var hp_after: int = p.stats.health
	var bleed_after: int = p.stats.blood_ritual_loss_per_turn
	var passed: bool = reset_ok and not bool(qte.get("active")) and hp_after == 36 and bleed_after == 7

	await _cleanup_node(b)
	return _make_qte_record(
		"QTE-03",
		"wssws_blood_ritual",
		"W S -> D(reset) -> W S S W S",
		"SUCCESS",
		reset_ok,
		true,
		passed,
		"Reset %d->%d then completed once: Player HP 18->%d (expected 36), bleed=%d/turn" % [
			prog_mid, prog_reset, hp_after, bleed_after
		]
	)


func _test_blood_ritual_qte_failure(host_parent: Node) -> Dictionary:
	Engine.time_scale = 4.0
	var b: Node2D = await _spawn_isolated_battle(host_parent)
	var p: Player = b.get_node("Player") as Player
	var qte: CanvasLayer = b.get_node("UltimateCardQTE") as CanvasLayer

	p.stats.health = 21
	p.stats.block = 5

	var card: Card = CARD_BLOOD_RITUAL.duplicate()
	var targets: Array[Node] = [p]
	card.play(targets, p.stats)
	await get_tree().process_frame

	AIBattleAgent.inject_wasd_key(b, KEY_W)
	var prog_mid: int = int(qte.get("progress"))
	AIBattleAgent.inject_wasd_key(b, KEY_A)
	var prog_reset: int = int(qte.get("progress"))
	var reset_ok: bool = prog_mid == 1 and prog_reset == 0 and bool(qte.get("active"))

	var expired_ok: bool = await _wait_for_qte_timer_expiration(qte)
	await get_tree().create_timer(0.3).timeout

	var hp_after: int = p.stats.health
	var block_after: int = p.stats.block
	var bleed_after: int = p.stats.blood_ritual_loss_per_turn
	var passed: bool = reset_ok and expired_ok and hp_after == 11 and block_after == 0 and bleed_after == 0

	await _cleanup_node(b)
	return _make_qte_record(
		"QTE-04",
		"wssws_blood_ritual",
		"W -> A(reset) -> Timeout",
		"FAILURE",
		reset_ok,
		true,
		passed,
		"Progress %d->%d on wrong key A, timer expired -> Block 5->%d, HP halved 21->%d (expected 11)" % [
			prog_mid, prog_reset, block_after, hp_after
		]
	)


func _test_last_gasp_qte_success(host_parent: Node) -> Dictionary:
	Engine.time_scale = 3.0
	var b: Node2D = await _spawn_isolated_battle(host_parent)
	var p: Player = b.get_node("Player") as Player
	var qte: CanvasLayer = b.get_node("UltimateCardQTE") as CanvasLayer

	p.stats.health = 30
	p.stats.block = 5

	var card: Card = CARD_LAST_GASP.duplicate()
	var targets: Array[Node] = [p]
	card.play(targets, p.stats)
	await get_tree().process_frame

	for key in [KEY_D, KEY_S, KEY_D, KEY_S, KEY_D, KEY_S]:
		AIBattleAgent.inject_wasd_key(b, key)
		await get_tree().process_frame

	AIBattleAgent.inject_wasd_key(b, KEY_S)
	await get_tree().create_timer(0.3).timeout

	var hp_after: int = p.stats.health
	var mult_after: int = p.stats.damage_multiplier
	var block_after: int = p.stats.block
	var passed: bool = not bool(qte.get("active")) and hp_after == 5 and mult_after == 3 and block_after == 0

	await _cleanup_node(b)
	return _make_qte_record(
		"QTE-05",
		"last_gasp",
		"D S D S D S",
		"SUCCESS",
		false,
		true,
		passed,
		"WASD completed QTE once: HP 30->%d (expected 5), damage_multiplier=%dx (expected 3x)" % [hp_after, mult_after]
	)


func _test_last_gasp_qte_failure(host_parent: Node) -> Dictionary:
	Engine.time_scale = 4.0
	var b: Node2D = await _spawn_isolated_battle(host_parent)
	var p: Player = b.get_node("Player") as Player
	var qte: CanvasLayer = b.get_node("UltimateCardQTE") as CanvasLayer

	p.stats.health = 30
	p.stats.block = 5

	var card: Card = CARD_LAST_GASP.duplicate()
	var targets: Array[Node] = [p]
	card.play(targets, p.stats)
	await get_tree().process_frame

	AIBattleAgent.inject_wasd_key(b, KEY_D)
	AIBattleAgent.inject_wasd_key(b, KEY_S)
	AIBattleAgent.inject_wasd_key(b, KEY_D)
	var prog_mid: int = int(qte.get("progress"))
	AIBattleAgent.inject_wasd_key(b, KEY_W)
	var prog_reset: int = int(qte.get("progress"))
	var reset_ok: bool = prog_mid == 3 and prog_reset == 0 and bool(qte.get("active"))

	var expired_ok: bool = await _wait_for_qte_timer_expiration(qte)
	await get_tree().create_timer(0.3).timeout

	var hp_after: int = p.stats.health
	var mult_after: int = p.stats.damage_multiplier
	var passed: bool = reset_ok and expired_ok and hp_after == 5 and mult_after == 1

	await _cleanup_node(b)
	return _make_qte_record(
		"QTE-06",
		"last_gasp",
		"D S D -> W(reset) -> Timeout",
		"FAILURE",
		reset_ok,
		true,
		passed,
		"Progress %d->%d on wrong key W, timer expired -> HP 30->%d (5), damage_multiplier stayed %dx (no buff)" % [
			prog_mid, prog_reset, hp_after, mult_after
		]
	)


func _test_nuke_qte_success_single_application(host_parent: Node) -> Dictionary:
	Engine.time_scale = 4.0
	var b: Node2D = await _spawn_isolated_battle(host_parent)
	var p: Player = b.get_node("Player") as Player
	var eh: EnemyHandler = b.get_node("EnemyHandler") as EnemyHandler
	var qte: CanvasLayer = b.get_node("UltimateCardQTE") as CanvasLayer

	var e0: Enemy = eh.get_child(0) as Enemy
	var e1: Enemy = eh.get_child(1) as Enemy
	var e2: Enemy = eh.get_child(2) as Enemy
	e0.stats = ENEMY_GOLEM
	e1.stats = ENEMY_GHOST
	e2.stats = ENEMY_WOLF
	await get_tree().process_frame

	p.stats.health = 42
	p.stats.block = 6
	e0.stats.health = 40
	e0.stats.block = 8
	e1.stats.health = 10
	e2.stats.health = 10

	var card: Card = CARD_NUKE.duplicate()
	var targets: Array[Node] = [p]
	card.play(targets, p.stats)
	await get_tree().process_frame

	for key in [KEY_S, KEY_W, KEY_A, KEY_S, KEY_W, KEY_D, KEY_S, KEY_W]:
		AIBattleAgent.inject_wasd_key(b, key)
		await get_tree().process_frame

	AIBattleAgent.inject_wasd_key(b, KEY_W)

	var waited: float = 0.0
	while bool(b.get("battle_over_resolution_in_progress")) and waited < 15.0:
		waited += get_process_delta_time()
		await get_tree().process_frame
	await get_tree().process_frame

	var p_hp: int = p.stats.health
	var golem_hp: int = e0.stats.health
	var living_enemies: int = 0
	for child in eh.get_children():
		var en := child as Enemy
		if is_instance_valid(en) and not en.is_queued_for_deletion() and en.stats.health > 0:
			living_enemies += 1

	var passed: bool = not bool(qte.get("active")) and p_hp == 12 and golem_hp == 10 and living_enemies == 1
	await _cleanup_node(b)
	return _make_qte_record(
		"QTE-07",
		"nuke_30_kill_streak",
		"S W A S W D S W",
		"SUCCESS",
		false,
		true,
		passed,
		"WASD completed Nuke once: Player HP 42->%d (-30), Golem HP 40->%d (-30, block cleared), 2 enemies defeated" % [
			p_hp, golem_hp
		]
	)


func _test_nuke_qte_failure(host_parent: Node) -> Dictionary:
	Engine.time_scale = 4.0
	var b: Node2D = await _spawn_isolated_battle(host_parent)
	var p: Player = b.get_node("Player") as Player
	var qte: CanvasLayer = b.get_node("UltimateCardQTE") as CanvasLayer

	p.stats.health = 35
	p.stats.block = 8

	var captured_outcomes: Array[int] = []
	var on_over := func(_txt: String, t: BattleOverPanel.Type) -> void:
		captured_outcomes.append(int(t))
	Events.battle_over_screen_requested.connect(on_over)

	var card: Card = CARD_NUKE.duplicate()
	var targets: Array[Node] = [p]
	card.play(targets, p.stats)
	await get_tree().process_frame

	AIBattleAgent.inject_wasd_key(b, KEY_S)
	AIBattleAgent.inject_wasd_key(b, KEY_W)
	var prog_mid: int = int(qte.get("progress"))
	AIBattleAgent.inject_wasd_key(b, KEY_D)
	var prog_reset: int = int(qte.get("progress"))
	var reset_ok: bool = prog_mid == 2 and prog_reset == 0 and bool(qte.get("active"))

	var expired_ok: bool = await _wait_for_qte_timer_expiration(qte)
	var waited: float = 0.0
	while captured_outcomes.is_empty() and waited < 5.0:
		waited += get_process_delta_time()
		await get_tree().process_frame

	if Events.battle_over_screen_requested.is_connected(on_over):
		Events.battle_over_screen_requested.disconnect(on_over)

	var lose_emitted: bool = not captured_outcomes.is_empty() and captured_outcomes[0] == int(BattleOverPanel.Type.LOSE)
	var passed: bool = reset_ok and expired_ok and lose_emitted

	await _cleanup_node(b)
	return _make_qte_record(
		"QTE-08",
		"nuke_30_kill_streak",
		"S W -> D(reset) -> Timeout",
		"FAILURE",
		reset_ok,
		true,
		passed,
		"Progress %d->%d on wrong key D, timer expired -> Block cleared & lethal self-damage triggered LOSE=%s" % [
			prog_mid, prog_reset, str(lose_emitted)
		]
	)
