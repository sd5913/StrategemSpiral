class_name AIBattleAgent
extends Node

signal match_completed(summary: Dictionary)
signal agent_status_updated(status_text: String)

var battle: Node2D
var strategy: AIBotBrain.Strategy = AIBotBrain.Strategy.TACTICAL_PRO
var qte_accuracy: float = 1.0
var action_delay: float = 0.0
var enabled: bool = true
var max_turns_watchdog: int = 45
var max_battle_virtual_seconds: float = 180.0

var turn_number: int = 0
var cards_played_total: int = 0
var cards_played_by_id: Dictionary = {}
var cards_drawn_by_id: Dictionary = {}
var qte_stats_by_id: Dictionary = {}
var encounter_enemies: Array[String] = []
var encounter_signature: String = ""
var damage_taken_events: int = 0
var total_block_gained_cards: int = 0
var invariant_errors: Array[String] = []
var action_trace: Array[String] = []

var _is_acting: bool = false
var _qte_handling: bool = false
var _battle_done: bool = false
var _elapsed_virtual_time: float = 0.0
var _turn_idle_watchdog: float = 0.0


func setup(
	battle_node: Node2D,
	bot_strategy: AIBotBrain.Strategy,
	custom_qte_accuracy: float = -1.0,
	step_delay: float = 0.0
) -> void:
	battle = battle_node
	strategy = bot_strategy
	qte_accuracy = custom_qte_accuracy if custom_qte_accuracy >= 0.0 else AIBotBrain.get_default_qte_accuracy(bot_strategy)
	action_delay = step_delay


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not is_instance_valid(battle):
		battle = get_parent() as Node2D

	Events.player_hand_drawn.connect(_on_player_hand_drawn)
	Events.card_played.connect(_on_card_played)
	Events.player_hit.connect(_on_player_hit)
	Events.ultimate_card_qte_started.connect(_on_ultimate_qte_started)
	Events.battle_over_screen_requested.connect(_on_battle_over_screen_requested)

	# Capture initial enemy lineup once battle _ready has populated stats
	call_deferred("_capture_initial_lineup")


func _exit_tree() -> void:
	if Events.player_hand_drawn.is_connected(_on_player_hand_drawn):
		Events.player_hand_drawn.disconnect(_on_player_hand_drawn)
	if Events.card_played.is_connected(_on_card_played):
		Events.card_played.disconnect(_on_card_played)
	if Events.player_hit.is_connected(_on_player_hit):
		Events.player_hit.disconnect(_on_player_hit)
	if Events.ultimate_card_qte_started.is_connected(_on_ultimate_qte_started):
		Events.ultimate_card_qte_started.disconnect(_on_ultimate_qte_started)
	if Events.battle_over_screen_requested.is_connected(_on_battle_over_screen_requested):
		Events.battle_over_screen_requested.disconnect(_on_battle_over_screen_requested)


func _capture_initial_lineup() -> void:
	if not is_instance_valid(battle):
		return
	var enemy_handler: EnemyHandler = battle.get_node_or_null("EnemyHandler") as EnemyHandler
	if not enemy_handler:
		return
	encounter_enemies.clear()
	for child in enemy_handler.get_children():
		var enemy := child as Enemy
		if enemy:
			encounter_enemies.append(AIBotBrain.identify_enemy_type(enemy))
	var sorted_names: Array[String] = encounter_enemies.duplicate()
	sorted_names.sort()
	encounter_signature = " + ".join(sorted_names)

	# Check if hand was already drawn before agent attached (e.g. toggled ON mid-battle via HUD)
	var battle_ui: BattleUI = battle.get_node_or_null("BattleUI") as BattleUI
	var hand_node: Hand = _get_hand()
	if enabled and turn_number == 0 and battle_ui and battle_ui.end_turn_button and not battle_ui.end_turn_button.disabled and hand_node and hand_node.get_child_count() > 0:
		_on_player_hand_drawn()


func _process(delta: float) -> void:
	if _battle_done or not enabled or not is_instance_valid(battle):
		return

	_elapsed_virtual_time += delta
	if _elapsed_virtual_time > max_battle_virtual_seconds:
		_record_invariant("Battle exceeded max virtual time (%.1fs) without finishing - potential state deadlock." % max_battle_virtual_seconds)
		_finalize_match("TIMEOUT")
		return

	# Watchdog if player turn is ready (EndTurnButton enabled) and bot isn't acting
	var battle_ui: BattleUI = battle.get_node_or_null("BattleUI") as BattleUI
	if battle_ui and battle_ui.end_turn_button and not battle_ui.end_turn_button.disabled and not _is_acting and not _qte_handling:
		_turn_idle_watchdog += delta
		if _turn_idle_watchdog > 1.5:
			_turn_idle_watchdog = 0.0
			_execute_turn_loop()
	else:
		_turn_idle_watchdog = 0.0


func _on_player_hand_drawn() -> void:
	if _battle_done:
		return
	turn_number += 1
	_turn_idle_watchdog = 0.0

	# Record drawn hand cards & verify max-1-ultimate invariant
	var hand: Hand = _get_hand()
	if hand:
		var ult_in_hand: int = 0
		for child in hand.get_children():
			var c_ui := child as CardUI
			if c_ui and c_ui.card:
				var cid: String = c_ui.card.id
				cards_drawn_by_id[cid] = int(cards_drawn_by_id.get(cid, 0)) + 1
				if c_ui.card.is_ultimate:
					ult_in_hand += 1
		if ult_in_hand > 1:
			_record_invariant("Hand contains %d Ultimate cards simultaneously (expected <= 1)." % ult_in_hand)

	_verify_invariants("turn_%d_start" % turn_number)

	if turn_number > max_turns_watchdog:
		_record_invariant("Exceeded max turn limit (%d turns) - possible stalemate." % max_turns_watchdog)
		_finalize_match("TIMEOUT")
		return

	if enabled and not _is_acting:
		_execute_turn_loop()


func _execute_turn_loop() -> void:
	if _is_acting or _battle_done or not enabled:
		return
	_is_acting = true

	await get_tree().process_frame

	var safety_plays_this_turn: int = 0
	while enabled and not _battle_done and is_instance_valid(battle):
		if bool(battle.get("battle_over_requested")) or bool(battle.get("battle_over_resolution_in_progress")) or get_tree().paused:
			break

		var player: Player = _get_player()
		var hand: Hand = _get_hand()
		var enemies: Array[Enemy] = _get_living_enemies()

		if not player or not hand or enemies.is_empty():
			break

		_verify_invariants("turn_%d_step_%d" % [turn_number, safety_plays_this_turn])

		if action_delay > 0.0:
			await get_tree().create_timer(action_delay, true, false, true).timeout
			if _battle_done or not enabled or not is_instance_valid(battle):
				break

		# Wait if QTE is currently active
		var qte_layer: CanvasLayer = battle.get_node_or_null("UltimateCardQTE") as CanvasLayer
		while qte_layer and bool(qte_layer.get("active")) and not _battle_done:
			await get_tree().process_frame

		enemies = _get_living_enemies()
		if enemies.is_empty() or _battle_done or bool(battle.get("battle_over_requested")):
			break

		var decision: AIBotBrain.Decision = AIBotBrain.choose_next_action(strategy, player, hand, enemies)
		if decision.action == "END_TURN" or not is_instance_valid(decision.card_ui):
			agent_status_updated.emit("[T%d] End Turn (%s)" % [turn_number, decision.reason])
			action_trace.append("T%d: END_TURN (%s)" % [turn_number, decision.reason])
			_press_end_turn()
			break

		safety_plays_this_turn += 1
		if safety_plays_this_turn > 15:
			_record_invariant("Played >15 cards in a single turn (turn %d) - aborting turn loop." % turn_number)
			_press_end_turn()
			break

		var chosen_ui: CardUI = decision.card_ui
		var chosen_card: Card = chosen_ui.card
		var is_ult: bool = chosen_card.is_ultimate
		var is_attack: bool = chosen_card.type == Card.Type.ATTACK and not is_ult
		var card_id: String = chosen_card.id

		agent_status_updated.emit("[T%d] Play %s (%s)" % [turn_number, card_id, decision.reason])
		action_trace.append("T%d: PLAY %s -> %s" % [turn_number, card_id, decision.reason])

		# Populate targets accurately to match CardUI drag/aim behavior
		chosen_ui.targets.clear()
		if chosen_card.is_single_targeted():
			if is_instance_valid(decision.target_enemy):
				chosen_ui.targets.append(decision.target_enemy)
			else:
				chosen_ui.targets.append(enemies[0])
		else:
			var drop_area: Node = battle.get_node_or_null("cardDropArea")
			if drop_area:
				chosen_ui.targets.append(drop_area)
			else:
				chosen_ui.targets.append(player)

		chosen_ui.play()

		# Wait appropriately for animations, QTE input, or cutscenes to settle
		if is_ult:
			await _wait_for_qte_and_cutscene()
		elif is_attack:
			await get_tree().create_timer(0.58).timeout
		else:
			await get_tree().create_timer(0.14).timeout

		_verify_invariants("after_card_%s" % card_id)

	_is_acting = false


func _wait_for_qte_and_cutscene() -> void:
	if not is_instance_valid(battle):
		return
	var qte_layer: CanvasLayer = battle.get_node_or_null("UltimateCardQTE") as CanvasLayer
	var qte_wait_start: int = Time.get_ticks_msec()
	while qte_layer and bool(qte_layer.get("active")) and not _battle_done and (Time.get_ticks_msec() - qte_wait_start) < 5000:
		await get_tree().process_frame

	# Wait if Nuke cutscene (battle_over_resolution_in_progress, ~4.8s virtual time) is running
	var cutscene_wait_start: int = Time.get_ticks_msec()
	while is_instance_valid(battle) and bool(battle.get("battle_over_resolution_in_progress")) and not _battle_done and (Time.get_ticks_msec() - cutscene_wait_start) < 8000:
		await get_tree().process_frame

	if not _battle_done and is_inside_tree():
		await get_tree().create_timer(0.28).timeout


func _on_ultimate_qte_started(sequence: Array[String], _success: Callable, _failure: Callable) -> void:
	if not enabled or _battle_done or _qte_handling:
		return
	_qte_handling = true
	_perform_qte_inputs(sequence)


func _perform_qte_inputs(sequence: Array[String]) -> void:
	var will_succeed: bool = randf() <= qte_accuracy
	var qte_layer: CanvasLayer = battle.get_node_or_null("UltimateCardQTE") as CanvasLayer if is_instance_valid(battle) else null

	# Temporarily moderate Engine.time_scale if running ultra-fast so QTE 2.0s timer never races frame spikes
	var saved_scale: float = Engine.time_scale
	var restore_scale: bool = false
	if will_succeed and saved_scale > 6.0:
		Engine.time_scale = 5.0
		restore_scale = true

	await get_tree().process_frame

	if will_succeed:
		for dir_name in sequence:
			if not qte_layer or not bool(qte_layer.get("active")) or _battle_done:
				break
			_send_qte_key(_direction_to_keycode(dir_name))
			if action_delay > 0.0:
				await get_tree().create_timer(minf(action_delay * 0.35, 0.12), true, false, true).timeout
			else:
				await get_tree().process_frame
		_record_last_qte_result(true)
	else:
		# Simulate mistake + timeout failure to exercise QTE failure penalty paths!
		if not sequence.is_empty() and qte_layer and bool(qte_layer.get("active")):
			var wrong_dir: String = "up" if sequence[0] != "up" else "down"
			_send_qte_key(_direction_to_keycode(wrong_dir))
		if qte_layer and bool(qte_layer.get("active")) and qte_layer.has_method("_resolve"):
			# If in fast headless mode, let timer expire naturally or wait until elapsed >= DURATION
			while qte_layer and bool(qte_layer.get("active")) and not _battle_done:
				await get_tree().process_frame
		_record_last_qte_result(false)

	if restore_scale and not _battle_done:
		Engine.time_scale = saved_scale

	_qte_handling = false


func _record_last_qte_result(succeeded: bool) -> void:
	# Attribute QTE outcome to most recently played ultimate card
	var last_ult: String = "ultimate_unknown"
	for i in range(action_trace.size() - 1, -1, -1):
		var entry: String = action_trace[i]
		for ult_id in ["adda_swap_health", "wssws_blood_ritual", "last_gasp", "nuke_30_kill_streak"]:
			if entry.contains(ult_id):
				last_ult = ult_id
				break
		if last_ult != "ultimate_unknown":
			break

	if not qte_stats_by_id.has(last_ult):
		qte_stats_by_id[last_ult] = {"attempts": 0, "successes": 0, "failures": 0}
	var rec: Dictionary = qte_stats_by_id[last_ult]
	rec["attempts"] = int(rec["attempts"]) + 1
	if succeeded:
		rec["successes"] = int(rec["successes"]) + 1
	else:
		rec["failures"] = int(rec["failures"]) + 1


func _direction_to_keycode(direction: String) -> Key:
	match direction:
		"up":
			return KEY_W
		"down":
			return KEY_S
		"left":
			return KEY_A
		"right":
			return KEY_D
	return KEY_W


func _send_qte_key(keycode: Key) -> void:
	if not is_inside_tree() or not get_viewport():
		return
	var press := InputEventKey.new()
	press.keycode = keycode
	press.physical_keycode = keycode
	press.pressed = true
	press.echo = false
	get_viewport().push_input(press)

	var release := InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	release.pressed = false
	release.echo = false
	get_viewport().push_input(release)


func _press_end_turn() -> void:
	if not is_instance_valid(battle) or _battle_done:
		return
	var battle_ui: BattleUI = battle.get_node_or_null("BattleUI") as BattleUI
	if battle_ui and battle_ui.end_turn_button and not battle_ui.end_turn_button.disabled:
		battle_ui.end_turn_button.pressed.emit()


func _on_card_played(card: Card) -> void:
	if not card:
		return
	cards_played_total += 1
	cards_played_by_id[card.id] = int(cards_played_by_id.get(card.id, 0)) + 1
	if card.id == "warrior_block":
		total_block_gained_cards += 5


func _on_player_hit() -> void:
	damage_taken_events += 1


func _on_battle_over_screen_requested(_text: String, type: BattleOverPanel.Type) -> void:
	if _battle_done:
		return
	var outcome: String = "LOSE"
	match type:
		BattleOverPanel.Type.WIN:
			outcome = "WIN"
		BattleOverPanel.Type.LOSE:
			outcome = "LOSE"
		BattleOverPanel.Type.OBLITERATED:
			outcome = "OBLITERATED"

	# Also mirror BattleOverPanel._is_obliteration() check
	var player: Player = _get_player()
	var enemies: Array[Enemy] = _get_living_enemies()
	var p_alive: bool = player != null and player.stats != null and player.stats.health > 0
	if not p_alive and enemies.is_empty():
		outcome = "OBLITERATED"

	_finalize_match(outcome)


func _finalize_match(outcome: String) -> void:
	if _battle_done:
		return
	_battle_done = true
	_verify_invariants("battle_end")

	var player: Player = _get_player()
	var final_hp: int = 0
	var max_hp: int = 45
	if player and player.stats:
		final_hp = maxi(0, player.stats.health)
		max_hp = player.stats.max_health

	var remaining_enemy_hp: int = 0
	for e in _get_living_enemies():
		remaining_enemy_hp += e.stats.health

	var summary: Dictionary = {
		"strategy": AIBotBrain.get_strategy_name(strategy),
		"qte_accuracy_target": qte_accuracy,
		"outcome": outcome,
		"turns": maxi(1, turn_number),
		"player_final_hp": final_hp,
		"player_max_hp": max_hp,
		"remaining_enemy_hp": remaining_enemy_hp,
		"encounter_enemies": encounter_enemies.duplicate(),
		"encounter_signature": encounter_signature,
		"cards_played_total": cards_played_total,
		"cards_played_by_id": cards_played_by_id.duplicate(true),
		"cards_drawn_by_id": cards_drawn_by_id.duplicate(true),
		"qte_stats_by_id": qte_stats_by_id.duplicate(true),
		"damage_taken_events": damage_taken_events,
		"block_from_cards": total_block_gained_cards,
		"invariant_errors": invariant_errors.duplicate(),
		"action_trace": action_trace.duplicate()
	}
	agent_status_updated.emit("Match Finished: %s in %d turns (HP: %d/%d)" % [outcome, summary["turns"], final_hp, max_hp])
	match_completed.emit(summary)


func _verify_invariants(context_tag: String) -> void:
	if not is_instance_valid(battle):
		return
	var battle_ui: BattleUI = battle.get_node_or_null("BattleUI") as BattleUI
	if battle_ui and battle_ui.char_stats:
		var st: CharacterStats = battle_ui.char_stats
		if st.mana < 0:
			_record_invariant("[%s] Player mana dropped below 0 (mana=%d)." % [context_tag, st.mana])
		if st.health < 0 or st.health > st.max_health:
			_record_invariant("[%s] Player health out of bounds (%d / %d)." % [context_tag, st.health, st.max_health])
		if st.block < 0:
			_record_invariant("[%s] Player block dropped below 0 (block=%d)." % [context_tag, st.block])

	for e in _get_living_enemies():
		if e.stats.health > e.stats.max_health:
			_record_invariant("[%s] Enemy %s health exceeded max_health (%d > %d)." % [
				context_tag, AIBotBrain.identify_enemy_type(e), e.stats.health, e.stats.max_health
			])
		if e.stats.block < 0:
			_record_invariant("[%s] Enemy %s block negative (%d)." % [
				context_tag, AIBotBrain.identify_enemy_type(e), e.stats.block
			])


func _record_invariant(msg: String) -> void:
	if not invariant_errors.has(msg):
		invariant_errors.append(msg)
		push_warning("[AITestSystem Invariant] " + msg)


func _get_player() -> Player:
	if not is_instance_valid(battle):
		return null
	var p: Player = battle.get_node_or_null("Player") as Player
	if is_instance_valid(p) and not p.is_queued_for_deletion():
		return p
	return null


func _get_hand() -> Hand:
	if not is_instance_valid(battle):
		return null
	return battle.get_node_or_null("BattleUI/hand") as Hand


func _get_living_enemies() -> Array[Enemy]:
	var result: Array[Enemy] = []
	if not is_instance_valid(battle):
		return result
	var handler: EnemyHandler = battle.get_node_or_null("EnemyHandler") as EnemyHandler
	if not handler:
		return result
	for child in handler.get_children():
		var e := child as Enemy
		if is_instance_valid(e) and not e.is_queued_for_deletion() and e.stats and e.stats.health > 0:
			result.append(e)
	return result
