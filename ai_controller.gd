class_name AIController
extends Node

const AIBot = preload("res://ai_tester/ai_bot.gd")

signal action_taken(log_message: String)
signal game_finished(result: String, stats: Dictionary)
signal batch_finished(summary: Dictionary)

@export var enabled: bool = true
@export var strategy: AIBot.Strategy = AIBot.Strategy.BALANCED
@export var play_delay: float = 0.3
@export var auto_restart: bool = false
@export var target_game_count: int = 1

var games_played: int = 0
var wins: int = 0
var losses: int = 0
var turn_count: int = 0
var is_taking_turn: bool = false
var battle_in_progress: bool = false

var logs: Array[String] = []
var assertion_failures: Array[String] = []
var game_history: Array[Dictionary] = []

var battle: Node2D
var player: Player
var enemy_handler: EnemyHandler
var battle_ui: BattleUI
var hand: Hand
var end_turn_button: Button
var card_drop_area: Area2D

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	hook_battle_scene()
	Events.player_hand_drawn.connect(_on_player_hand_drawn)
	Events.battle_over_screen_requested.connect(_on_battle_over)

func hook_battle_scene(target_scene: Node = null) -> void:
	var target: Node = target_scene
	if not target:
		if get_parent() and (get_parent().has_node("EnemyHandler") or get_parent().has_node("Player")):
			target = get_parent()
		elif get_tree() and get_tree().current_scene:
			var curr := get_tree().current_scene
			if curr.has_node("EnemyHandler"):
				target = curr
			else:
				var eh := curr.find_child("EnemyHandler", true, false)
				if eh:
					target = eh.get_parent()

	if not target:
		return

	battle = target as Node2D
	player = battle.get_node_or_null("Player") as Player
	enemy_handler = battle.get_node_or_null("EnemyHandler") as EnemyHandler
	battle_ui = battle.get_node_or_null("BattleUI") as BattleUI
	card_drop_area = battle.get_node_or_null("cardDropArea") as Area2D

	if battle_ui:
		hand = battle_ui.get_node_or_null("hand") as Hand
		end_turn_button = battle_ui.get_node_or_null("%EndTurnButton") as Button

	battle_in_progress = true
	turn_count = 0

	# If hand already has cards (e.g. ready fired before we hooked), start turn!
	if hand and hand.get_child_count() > 0:
		call_deferred("_on_player_hand_drawn")
		turn_count = 0

func _on_player_hand_drawn() -> void:
	if not enabled or not battle_in_progress:
		return

	turn_count += 1
	_log("=== [Turn %d] Player Turn Started ===" % turn_count)
	_run_invariants_check()
	_play_ai_turn()

func _play_ai_turn() -> void:
	if is_taking_turn:
		return
	is_taking_turn = true

	while is_taking_turn and enabled and battle_in_progress:
		if not is_instance_valid(battle) or not is_instance_valid(hand) or not is_instance_valid(battle_ui):
			break

		var char_stats: CharacterStats = battle_ui.char_stats
		if not char_stats:
			break

		var alive_enemies: Array[Enemy] = []
		if is_instance_valid(enemy_handler):
			for child in enemy_handler.get_children():
				var e := child as Enemy
				if is_instance_valid(e) and not e.is_queued_for_deletion():
					if e.stats and e.stats.health > 0:
						alive_enemies.append(e)

		if alive_enemies.is_empty():
			_log("[Turn %d] No enemies remaining." % turn_count)
			break

		var hand_cards := hand.get_children()
		var decision := AIBot.evaluate_turn(player, char_stats, hand_cards, alive_enemies, card_drop_area, strategy)

		match decision.action:
			"PLAY_CARD":
				var card_ui: CardUI = decision.card_ui
				var target_node: Node = decision.target
				var target_name: String = target_node.name if target_node else "Area"

				_log("[Turn %d] 🃏 Play '%s' on [%s] -> %s (Mana: %d)" % [
					turn_count,
					card_ui.card.id,
					target_name,
					decision.reason,
					char_stats.mana
				])

				# Invariant check: ensure cost <= mana
				if card_ui.card.cost > char_stats.mana:
					_record_assertion("Card cost (%d) exceeds current mana (%d)" % [card_ui.card.cost, char_stats.mana])

				if card_ui.card.is_single_targeted():
					card_ui.targets = [target_node]
				else:
					card_ui.targets = [card_drop_area]

				card_ui.play()

				# Post-play invariant: mana non-negative
				if char_stats.mana < 0:
					_record_assertion("Mana became negative: %d" % char_stats.mana)

				if play_delay > 0:
					await get_tree().create_timer(play_delay).timeout
				else:
					await get_tree().process_frame

			"END_TURN":
				_log("[Turn %d] ⏭️ End Turn -> %s (Leftover Mana: %d)" % [
					turn_count,
					decision.reason,
					char_stats.mana
				])
				is_taking_turn = false
				if play_delay > 0:
					await get_tree().create_timer(play_delay).timeout
				_execute_end_turn()
				break

			_:
				is_taking_turn = false
				break

	is_taking_turn = false

func _execute_end_turn() -> void:
	if is_instance_valid(end_turn_button) and not end_turn_button.disabled:
		end_turn_button.pressed.emit()
	else:
		Events.player_turn_ended.emit()

func _on_battle_over(text: String, type: BattleOverPanel.Type) -> void:
	if not battle_in_progress:
		return

	battle_in_progress = false
	is_taking_turn = false
	games_played += 1

	var is_win := (type == BattleOverPanel.Type.WIN)
	if is_win:
		wins += 1
		_log("🏆 VICTORY! (%s) in %d turns" % [text, turn_count])
	else:
		losses += 1
		_log("💀 DEFEAT! (%s) in %d turns" % [text, turn_count])

	var player_hp := 0
	if is_instance_valid(player) and player.stats:
		player_hp = player.stats.health

	var record := {
		"game_index": games_played,
		"result": "WIN" if is_win else "LOSE",
		"turns": turn_count,
		"player_hp": player_hp,
		"strategy": AIBot.get_strategy_name(strategy)
	}
	game_history.append(record)
	game_finished.emit(record.result, record)

	if auto_restart and games_played < target_game_count:
		_log("Restarting battle (%d/%d)..." % [games_played + 1, target_game_count])
		# Unpause and reload
		get_tree().paused = false
		get_tree().reload_current_scene()
		# Re-hook after tree reload
		await get_tree().node_added
		hook_battle_scene()
	elif auto_restart and games_played >= target_game_count:
		_finish_batch_testing()

func _finish_batch_testing() -> void:
	var win_rate := float(wins) / float(max(1, games_played)) * 100.0
	var summary := {
		"total_games": games_played,
		"wins": wins,
		"losses": losses,
		"win_rate": win_rate,
		"strategy": AIBot.get_strategy_name(strategy),
		"assertion_failures": assertion_failures.size(),
		"history": game_history
	}
	_log("=== BATCH TEST COMPLETE ===")
	_log("Total Games: %d | Wins: %d | Losses: %d | Win Rate: %.1f%%" % [
		games_played, wins, losses, win_rate
	])
	batch_finished.emit(summary)

func _run_invariants_check() -> void:
	if not is_instance_valid(player) or not player.stats:
		return
	if player.stats.mana < 0:
		_record_assertion("Turn %d: Player mana is negative: %d" % [turn_count, player.stats.mana])
	if player.stats.block < 0:
		_record_assertion("Turn %d: Player block is negative: %d" % [turn_count, player.stats.block])
	if turn_count > 100:
		_record_assertion("Turn %d: Potential infinite loop / softlock detected" % turn_count)

func _record_assertion(msg: String) -> void:
	var err := "[ASSERTION FAILED] " + msg
	printerr(err)
	assertion_failures.append(err)
	_log(err)

func _log(msg: String) -> void:
	logs.append(msg)
	print(msg)
	action_taken.emit(msg)
