extends Node

const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")
const START_SCREEN_PATH := "res://scenes/ui/start_screen.tscn"

const REPORT_JSON_PATH := "res://ai_test_system/reports/test_report.json"
const REPORT_MD_PATH := "res://ai_test_system/reports/test_report.md"
const REPORT_HTML_PATH := "res://ai_test_system/reports/test_report_dashboard.html"

var games_per_strategy: int = 10
var selected_strategies: Array[AIBotBrain.Strategy] = [
	AIBotBrain.Strategy.TACTICAL_PRO,
	AIBotBrain.Strategy.AGGRESSIVE,
	AIBotBrain.Strategy.DEFENSIVE,
	AIBotBrain.Strategy.HUMAN_SIM,
	AIBotBrain.Strategy.RANDOM_FUZZ
]
var batch_qte_mode: AIBattleAgent.QTEMode = AIBattleAgent.QTEMode.STRATEGY_DEFAULT
var run_functional_tests: bool = true
var run_qte_matrix_tests: bool = true
var sim_time_scale: float = 8.0
var step_delay: float = 0.0
var auto_quit: bool = false

var _arena_holder: Node2D
var _hud_layer: CanvasLayer
var _title_lbl: Label
var _status_lbl: Label
var _stats_lbl: Label
var _progress_bar: ProgressBar
var _back_btn: Button

var _functional_results: Array[Dictionary] = []
var _qte_matrix_results: Array[Dictionary] = []
var _match_records: Array[Dictionary] = []
var _start_msec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	var autoload_node: Node = get_node_or_null("/root/AITestSystem")
	if autoload_node:
		autoload_node.set("runner_mode_active", true)

	auto_quit = DisplayServer.get_name() == "headless"
	_parse_cli_args()
	_build_runner_ui()

	if DisplayServer.get_name() == "headless" or sim_time_scale >= 4.0:
		AudioServer.set_bus_mute(0, true)

	_run_full_pipeline()


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	AudioServer.set_bus_mute(0, false)
	var autoload_node: Node = get_node_or_null("/root/AITestSystem")
	if autoload_node:
		autoload_node.set("runner_mode_active", false)


func _parse_cli_args() -> void:
	var all_args: PackedStringArray = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for arg in all_args:
		if arg.begins_with("--games-per-strategy=") or arg.begins_with("--games="):
			var val: int = arg.split("=")[1].to_int()
			if val > 0:
				games_per_strategy = val
		elif arg.begins_with("--speed="):
			var sp: float = arg.split("=")[1].to_float()
			if sp > 0.0:
				sim_time_scale = sp
		elif arg.begins_with("--delay="):
			step_delay = maxf(0.0, arg.split("=")[1].to_float())
		elif arg == "--skip-functional":
			run_functional_tests = false
		elif arg == "--skip-qte-matrix":
			run_qte_matrix_tests = false
		elif arg == "--auto-quit":
			auto_quit = true
		elif arg == "--no-quit":
			auto_quit = false
		elif arg.begins_with("--qte-mode="):
			var qm: String = arg.split("=")[1].to_lower()
			match qm:
				"input", "success":
					batch_qte_mode = AIBattleAgent.QTEMode.INPUT_DRIVEN_SUCCESS
				"mistake", "reset", "recover":
					batch_qte_mode = AIBattleAgent.QTEMode.INPUT_DRIVEN_MISTAKE_RECOVERY
				"fail", "timeout":
					batch_qte_mode = AIBattleAgent.QTEMode.INPUT_DRIVEN_TIMEOUT_FAILURE
				_:
					batch_qte_mode = AIBattleAgent.QTEMode.STRATEGY_DEFAULT
		elif arg.begins_with("--strategy="):
			var s_name: String = arg.split("=")[1].to_lower()
			match s_name:
				"pro", "tactical":
					selected_strategies = [AIBotBrain.Strategy.TACTICAL_PRO]
				"aggro", "aggressive":
					selected_strategies = [AIBotBrain.Strategy.AGGRESSIVE]
				"def", "defensive":
					selected_strategies = [AIBotBrain.Strategy.DEFENSIVE]
				"human":
					selected_strategies = [AIBotBrain.Strategy.HUMAN_SIM]
				"fuzz", "random":
					selected_strategies = [AIBotBrain.Strategy.RANDOM_FUZZ]


func _build_runner_ui() -> void:
	_arena_holder = Node2D.new()
	_arena_holder.name = "ArenaHolder"
	add_child(_arena_holder)

	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 129
	_hud_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_hud_layer)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 2.0
	panel.offset_top = 2.0
	panel.offset_right = -2.0
	panel.offset_bottom = 44.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.14, 0.88)
	style.border_width_bottom = 1
	style.border_width_top = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_color = Color(0.45, 0.38, 0.85, 0.95)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", style)
	_hud_layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	panel.add_child(vbox)

	var top_row := HBoxContainer.new()
	vbox.add_child(top_row)

	_title_lbl = Label.new()
	_title_lbl.text = "AI & WASD QTE TEST SUITE..."
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_lbl.add_theme_font_size_override("font_size", 6)
	_title_lbl.add_theme_color_override("font_color", Color(0.82, 0.76, 1.0))
	top_row.add_child(_title_lbl)

	_back_btn = Button.new()
	_back_btn.text = "Exit"
	_back_btn.visible = false
	_back_btn.add_theme_font_size_override("font_size", 6)
	_back_btn.pressed.connect(_on_exit_pressed)
	top_row.add_child(_back_btn)

	_status_lbl = Label.new()
	_status_lbl.text = "Initializing..."
	_status_lbl.clip_text = true
	_status_lbl.add_theme_font_size_override("font_size", 6)
	_status_lbl.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
	vbox.add_child(_status_lbl)

	_stats_lbl = Label.new()
	_stats_lbl.text = "FT: 0/11 | QTE: 0/8 | Matches: 0"
	_stats_lbl.add_theme_font_size_override("font_size", 6)
	_stats_lbl.add_theme_color_override("font_color", Color(0.68, 0.95, 0.76))
	vbox.add_child(_stats_lbl)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0, 4)
	_progress_bar.show_percentage = false
	vbox.add_child(_progress_bar)


func _run_full_pipeline() -> void:
	_start_msec = Time.get_ticks_msec()
	var total_matches_planned: int = selected_strategies.size() * games_per_strategy
	var ft_steps: int = 11 if run_functional_tests else 0
	var qte_steps: int = 8 if run_qte_matrix_tests else 0
	var total_steps: int = ft_steps + qte_steps + total_matches_planned
	_progress_bar.max_value = float(maxi(1, total_steps))
	_progress_bar.value = 0.0

	print("\n======================================================================")
	print("   STRATEGEM SPIRAL (slayTheStrat) - AI & INPUT-DRIVEN QTE SUITE      ")
	print("======================================================================")
	print(" Functional Checks : %s" % ("Enabled (11 tests)" if run_functional_tests else "Skipped"))
	print(" Ultimate QTE Paths: %s" % ("Enabled (8 paths: 4 Win + 4 Fail)" if run_qte_matrix_tests else "Skipped"))
	print(" Batch Strategies  : %d (%d matches each -> %d total battles)" % [
		selected_strategies.size(), games_per_strategy, total_matches_planned
	])
	print(" Batch QTE Mode    : %s" % AIBattleAgent.get_qte_mode_name(batch_qte_mode))
	print(" Time Scale        : %.1fx | Step Delay: %.2fs" % [sim_time_scale, step_delay])
	print("======================================================================\n")

	var verifier := AIMechanicsVerifier.new()
	add_child(verifier)

	# Phase 1: Core Mechanics & Export-Gating Verification
	if run_functional_tests:
		_status_lbl.text = "Phase 1: Running 11 Core & Export Checks..."
		print("[Phase 1] Running Core Mechanics & Export-Safety Verification...")
		_functional_results = await verifier.run_all_checks(_arena_holder)
		var ft_ok: int = 0
		for r in _functional_results:
			var passed_flag: bool = bool(r.get("passed", false))
			if passed_flag:
				ft_ok += 1
			print("  [%s] %s - %s (%s)" % [
				"PASS" if passed_flag else "FAIL",
				str(r.get("id", "?")),
				str(r.get("title", "Unknown")),
				str(r.get("details", ""))
			])
		_progress_bar.value = float(ft_steps)
		_stats_lbl.text = "FT: %d/%d PASS" % [ft_ok, _functional_results.size()]

	# Phase 2: Input-Driven Ultimate Card QTE Success & Failure Matrix
	if run_qte_matrix_tests:
		_status_lbl.text = "Phase 2: Testing All 4 Ultimate Cards (Win + Fail)..."
		print("\n[Phase 2] Running Input-Driven WASD QTE Matrix (4 Ultimates x Success + Failure)...")
		_qte_matrix_results = await verifier.run_ultimate_qte_matrix(_arena_holder)
		var qte_ok: int = 0
		for qr in _qte_matrix_results:
			var passed_flag: bool = bool(qr.get("passed", false))
			if passed_flag:
				qte_ok += 1
			print("  [%s] %s [%s | %s] - %s" % [
				"PASS" if passed_flag else "FAIL",
				str(qr.get("id", "?")),
				str(qr.get("card_id", "?")),
				str(qr.get("path", "?")),
				str(qr.get("details", ""))
			])
		_progress_bar.value = float(ft_steps + qte_steps)
		_stats_lbl.text = "FT: %d | QTE Matrix: %d/%d PASS" % [
			_functional_results.size(), qte_ok, _qte_matrix_results.size()
		]

	verifier.queue_free()

	# Phase 3: Multi-Strategy AI Playtest Simulation
	print("\n[Phase 3] Running Multi-Strategy AI Bot Playtest Battles...")
	Engine.time_scale = sim_time_scale
	var completed_matches: int = 0
	var wins_so_far: int = 0
	var losses_so_far: int = 0
	var oblit_so_far: int = 0

	for strat in selected_strategies:
		var strat_name: String = AIBotBrain.get_strategy_name(strat)
		print("  >> Benchmarking Persona: %s (%d matches, QTE=%s)" % [
			strat_name, games_per_strategy, AIBattleAgent.get_qte_mode_name(batch_qte_mode)
		])
		for m_idx in range(1, games_per_strategy + 1):
			_status_lbl.text = "%s: Match %d/%d" % [strat_name, m_idx, games_per_strategy]
			var summary: Dictionary = await _run_single_match(strat, batch_qte_mode)
			summary["match_index"] = completed_matches + 1
			_match_records.append(summary)
			completed_matches += 1

			var out_str: String = str(summary["outcome"])
			if out_str == "WIN":
				wins_so_far += 1
			elif out_str == "OBLITERATED":
				oblit_so_far += 1
			else:
				losses_so_far += 1

			_progress_bar.value = float(ft_steps + qte_steps + completed_matches)
			_stats_lbl.text = "W:%d L:%d O:%d (%d/%d)" % [
				wins_so_far, losses_so_far, oblit_so_far, completed_matches, total_matches_planned
			]
			print("     Match #%02d [%s] vs [%s] -> %s in %d turns (HP: %d/45, Cards: %d)" % [
				completed_matches,
				strat_name,
				str(summary["encounter_signature"]),
				out_str,
				int(summary["turns"]),
				int(summary["player_final_hp"]),
				int(summary["cards_played_total"])
			])

	# Phase 4: Build & Export Programmatic Reports
	Engine.time_scale = 1.0
	get_tree().paused = false
	AudioServer.set_bus_mute(0, false)

	var elapsed_sec: float = float(Time.get_ticks_msec() - _start_msec) / 1000.0
	var full_report: Dictionary = AIReportGenerator.build_full_report(
		_functional_results,
		_qte_matrix_results,
		_match_records,
		elapsed_sec
	)
	AIReportGenerator.save_reports(full_report, REPORT_JSON_PATH, REPORT_MD_PATH, REPORT_HTML_PATH)

	_print_final_console_summary(full_report)
	_show_final_ui_summary(full_report)

	if auto_quit:
		var ft_failed: int = int(full_report["functional_suite"]["failed"])
		var qte_failed: int = int(full_report["ultimate_qte_verification"]["failed"])
		var inv_failed: int = int(full_report["simulation_overview"]["invariant_errors_count"])
		var exit_code: int = 0 if (ft_failed == 0 and qte_failed == 0 and inv_failed == 0) else 1
		await get_tree().process_frame
		get_tree().quit(exit_code)


func _run_single_match(strat: AIBotBrain.Strategy, q_mode: AIBattleAgent.QTEMode) -> Dictionary:
	get_tree().paused = false
	var battle_instance: Node2D = BATTLE_SCENE.instantiate() as Node2D
	_arena_holder.add_child(battle_instance)

	var agent := AIBattleAgent.new()
	agent.setup(battle_instance, strat, -1.0, step_delay, q_mode)
	battle_instance.add_child(agent)

	var result_box: Array[Dictionary] = []
	agent.match_completed.connect(func(res: Dictionary) -> void:
		result_box.append(res)
	, CONNECT_ONE_SHOT)

	while result_box.is_empty():
		await get_tree().process_frame

	get_tree().paused = false
	if is_instance_valid(battle_instance):
		battle_instance.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	return result_box[0]


func _print_final_console_summary(report: Dictionary) -> void:
	var ft: Dictionary = report["functional_suite"]
	var qm: Dictionary = report["ultimate_qte_verification"]
	var sim: Dictionary = report["simulation_overview"]
	print("\n======================================================================")
	print("                     FINAL AI TEST REPORT SUMMARY                     ")
	print("======================================================================")
	print(" Functional Tests   : %d / %d PASSED" % [int(ft["passed"]), int(ft["total"])])
	print(" Ultimate QTE Paths : %d / %d PASSED (All 4 Ultimates Win + Fail)" % [int(qm["passed"]), int(qm["total"])])
	print(" Total AI Battles   : %d (Wins: %d | Losses: %d | Obliterated: %d)" % [
		int(sim["total_matches"]), int(sim["wins"]), int(sim["losses"]), int(sim["obliterated"])
	])
	print(" Overall Win Rate   : %.1f%%" % float(sim["overall_win_rate_pct"]))
	print(" Invariant Errors   : %d" % int(sim["invariant_errors_count"]))
	print(" Duration           : %.2f seconds" % float(report["duration_seconds"]))
	print("----------------------------------------------------------------------")
	print(" Saved JSON Report  : %s" % ProjectSettings.globalize_path(REPORT_JSON_PATH))
	print(" Saved MD Report    : %s" % ProjectSettings.globalize_path(REPORT_MD_PATH))
	print(" Saved HTML Report  : %s" % ProjectSettings.globalize_path(REPORT_HTML_PATH))
	print("======================================================================\n")


func _show_final_ui_summary(report: Dictionary) -> void:
	var ft: Dictionary = report["functional_suite"]
	var qm: Dictionary = report["ultimate_qte_verification"]
	var sim: Dictionary = report["simulation_overview"]
	_title_lbl.text = "AI & QTE SUITE COMPLETE (%.1fs)" % float(report["duration_seconds"])
	_status_lbl.text = "Reports saved to ai_test_system/reports/"
	_stats_lbl.text = "FT:%d/%d | QTE:%d/%d | Win:%.1f%% | Err:%d" % [
		int(ft["passed"]), int(ft["total"]),
		int(qm["passed"]), int(qm["total"]),
		float(sim["overall_win_rate_pct"]),
		int(sim["invariant_errors_count"])
	]
	_back_btn.visible = true


func _on_exit_pressed() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(START_SCREEN_PATH)
