extends Node

const AIBot = preload("res://ai_tester/ai_bot.gd")
const AIController = preload("res://ai_tester/ai_controller.gd")
const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")

var target_games: int = 10
var current_strategy: AIBot.Strategy = AIBot.Strategy.BALANCED
var play_delay: float = 0.0
var output_json_path: String = "res://ai_tester/test_report.json"
var output_md_path: String = "res://ai_tester/test_report.md"

var current_game_index: int = 0
var current_battle_node: Node2D
var current_controller: AIController

var wins: int = 0
var losses: int = 0
var total_turns: int = 0
var win_turns: Array[int] = []
var lose_turns: Array[int] = []
var win_final_hps: Array[int] = []
var all_assertions: Array[String] = []
var game_records: Array[Dictionary] = []

var start_time_msec: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_cmdline_args()
	Engine.time_scale = 10.0 if play_delay == 0.0 else 2.0
	start_time_msec = Time.get_ticks_msec()

	print("\n========================================================")
	print("       STRATEGEM SPIRAL - AI PLAYTEST TEST SUITE        ")
	print("========================================================")
	print(" Target Games : %d" % target_games)
	print(" Strategy     : %s" % AIBot.get_strategy_name(current_strategy))
	print(" Engine Speed : %.1fx (Play Delay: %.2fs)" % [Engine.time_scale, play_delay])
	print("========================================================\n")

	_run_next_game()

func _parse_cmdline_args() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		args = OS.get_cmdline_args()

	for arg in args:
		if arg.begins_with("--games="):
			target_games = arg.split("=")[1].to_int()
		elif arg.begins_with("--strategy="):
			var s := arg.split("=")[1].to_lower()
			match s:
				"aggro", "aggressive": current_strategy = AIBot.Strategy.AGGRESSIVE
				"def", "defensive": current_strategy = AIBot.Strategy.DEFENSIVE
				"fuzz", "random": current_strategy = AIBot.Strategy.RANDOM_FUZZ
				_: current_strategy = AIBot.Strategy.BALANCED
		elif arg.begins_with("--delay="):
			play_delay = arg.split("=")[1].to_float()

func _run_next_game() -> void:
	current_game_index += 1
	if current_game_index > target_games:
		_finish_suite()
		return

	print("--- Running Match %d / %d ---" % [current_game_index, target_games])

	# Clean up old battle if any
	if is_instance_valid(current_battle_node):
		current_battle_node.queue_free()
		await get_tree().process_frame

	get_tree().paused = false

	# Instantiate fresh battle scene
	current_battle_node = BATTLE_SCENE.instantiate()
	add_child(current_battle_node)

	# Attach AI Controller
	current_controller = AIController.new()
	current_controller.enabled = true
	current_controller.strategy = current_strategy
	current_controller.play_delay = play_delay
	current_controller.auto_restart = false
	current_battle_node.add_child(current_controller)
	current_controller.hook_battle_scene(current_battle_node)

	current_controller.game_finished.connect(_on_single_game_finished, CONNECT_ONE_SHOT)

func _on_single_game_finished(result: String, record: Dictionary) -> void:
	var turns: int = record.turns
	var hp: int = record.player_hp
	total_turns += turns

	if result == "WIN":
		wins += 1
		win_turns.append(turns)
		win_final_hps.append(hp)
		print("  -> Result: WIN  | Turns: %d | Player HP: %d" % [turns, hp])
	else:
		losses += 1
		lose_turns.append(turns)
		print("  -> Result: LOSE | Turns: %d | Player HP: %d" % [turns, hp])

	if current_controller and not current_controller.assertion_failures.is_empty():
		for err in current_controller.assertion_failures:
			all_assertions.append("[Game %d] %s" % [current_game_index, err])

	record["game_index"] = current_game_index
	game_records.append(record)

	# Schedule next match after brief delay
	await get_tree().create_timer(0.05).timeout
	_run_next_game()

func _finish_suite() -> void:
	var elapsed_sec := float(Time.get_ticks_msec() - start_time_msec) / 1000.0
	var win_rate := float(wins) / float(max(1, target_games)) * 100.0

	var avg_win_turns := 0.0
	if not win_turns.is_empty():
		var sum := 0
		for t in win_turns: sum += t
		avg_win_turns = float(sum) / float(win_turns.size())

	var avg_win_hp := 0.0
	if not win_final_hps.is_empty():
		var sum_hp := 0
		for h in win_final_hps: sum_hp += h
		avg_win_hp = float(sum_hp) / float(win_final_hps.size())

	print("\n========================================================")
	print("                 AI TEST SUITE RESULTS                  ")
	print("========================================================")
	print(" Strategy          : %s" % AIBot.get_strategy_name(current_strategy))
	print(" Matches Played    : %d" % target_games)
	print(" Wins              : %d (%.1f%%)" % [wins, win_rate])
	print(" Losses            : %d (%.1f%%)" % [losses, (100.0 - win_rate)])
	print(" Avg Turns (Win)   : %.1f" % avg_win_turns)
	print(" Avg Remaining HP  : %.1f / 35" % avg_win_hp)
	print(" Total Time        : %.2f seconds" % elapsed_sec)
	print(" Assertion Errors  : %d" % all_assertions.size())
	print("========================================================\n")

	_export_json_report(elapsed_sec, win_rate, avg_win_turns, avg_win_hp)
	_export_markdown_report(elapsed_sec, win_rate, avg_win_turns, avg_win_hp)

	var exit_code := 0 if all_assertions.is_empty() else 1
	get_tree().quit(exit_code)

func _export_json_report(elapsed: float, win_rate: float, avg_turns: float, avg_hp: float) -> void:
	var data := {
		"timestamp": Time.get_datetime_string_from_system(),
		"strategy": AIBot.get_strategy_name(current_strategy),
		"total_games": target_games,
		"wins": wins,
		"losses": losses,
		"win_rate_percent": win_rate,
		"avg_win_turns": avg_turns,
		"avg_win_hp": avg_hp,
		"duration_seconds": elapsed,
		"assertion_failures_count": all_assertions.size(),
		"assertion_details": all_assertions,
		"game_history": game_records
	}
	var f := FileAccess.open(output_json_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))
		f.close()
		print("JSON Report saved to: " + output_json_path)

func _export_markdown_report(elapsed: float, win_rate: float, avg_turns: float, avg_hp: float) -> void:
	var md := ""
	md += "# 🧪 StrategemSpiral AI 自动化游玩测试报告\n\n"
	md += "- **测试时间**: %s\n" % Time.get_datetime_string_from_system()
	md += "- **AI 策略**: `%s`\n" % AIBot.get_strategy_name(current_strategy)
	md += "- **总测试轮数**: %d 局\n" % target_games
	md += "- **总耗时**: %.2f 秒\n\n" % elapsed

	md += "## 📊 核心测试指标\n\n"
	md += "| 指标名称 | 结果 |\n"
	md += "| :--- | :--- |\n"
	md += "| 胜场 (Wins) | **%d** |\n" % wins
	md += "| 败场 (Losses) | **%d** |\n" % losses
	md += "| 胜率 (Win Rate) | **%.1f%%** |\n" % win_rate
	md += "| 获胜平均回合数 | **%.1f 回合** |\n" % avg_turns
	md += "| 获胜平均剩余生命值 | **%.1f / 35** |\n" % avg_hp
	md += "| 断言/不变式异常数 | **%d** |\n\n" % all_assertions.size()

	md += "## 🎮 每局对战明细\n\n"
	md += "| 局数 | 结果 | 回合数 | 玩家剩余 HP | 策略 |\n"
	md += "| :---: | :---: | :---: | :---: | :---: |\n"
	for g in game_records:
		var icon = "✅ 胜利" if g.result == "WIN" else "❌ 失败"
		md += "| %d | %s | %d | %d | %s |\n" % [g.game_index, icon, g.turns, g.player_hp, g.strategy]

	if not all_assertions.is_empty():
		md += "\n## ⚠️ 异常与断言失败记录\n\n"
		for err in all_assertions:
			md += "- %s\n" % err
	else:
		md += "\n> ✅ **状态良好**：所有对局均正常闭环，未检测到任何死锁、负法力值或空指针异常！\n"

	var f := FileAccess.open(output_md_path, FileAccess.WRITE)
	if f:
		f.store_string(md)
		f.close()
		print("Markdown Report saved to: " + output_md_path)
