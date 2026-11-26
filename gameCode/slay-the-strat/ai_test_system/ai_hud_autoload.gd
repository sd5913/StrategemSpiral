extends Node

const RUNNER_SCENE_PATH := "res://ai_test_system/ai_test_runner.tscn"
const BATTLE_SCENE_PATH := "res://scenes/battle/battle.tscn"

var overlay_enabled: bool = false
var runner_mode_active: bool = false : set = _set_runner_mode_active
var bot_autopilot: bool = false
var auto_restart_battles: bool = true
var current_strategy_idx: int = 0
var current_qte_mode_idx: int = 0
var speed_options: Array[float] = [1.0, 2.0, 4.0]
var current_speed_idx: int = 0

var strategies: Array[AIBotBrain.Strategy] = [
	AIBotBrain.Strategy.TACTICAL_PRO,
	AIBotBrain.Strategy.AGGRESSIVE,
	AIBotBrain.Strategy.DEFENSIVE,
	AIBotBrain.Strategy.HUMAN_SIM,
	AIBotBrain.Strategy.RANDOM_FUZZ
]

var qte_modes: Array[AIBattleAgent.QTEMode] = [
	AIBattleAgent.QTEMode.INPUT_DRIVEN_SUCCESS,
	AIBattleAgent.QTEMode.STRATEGY_DEFAULT,
	AIBattleAgent.QTEMode.INPUT_DRIVEN_MISTAKE_RECOVERY,
	AIBattleAgent.QTEMode.INPUT_DRIVEN_TIMEOUT_FAILURE
]

var session_wins: int = 0
var session_losses: int = 0
var session_obliterated: int = 0

var _hud_layer: CanvasLayer = null
var _panel: PanelContainer = null
var _toggle_btn: Button = null
var _bot_btn: Button = null
var _strat_btn: Button = null
var _qte_btn: Button = null
var _speed_btn: Button = null
var _suite_btn: Button = null
var _status_label: Label = null
var _active_agent: AIBattleAgent = null
var _restarting_scheduled: bool = false


static func should_enable_overlay(
	cmdline_args: PackedStringArray,
	is_release_or_export: bool,
	is_headless: bool,
	env_override: String = ""
) -> bool:
	# Never enable AI overlay in exported builds (Linux/Windows release or debug templates) or headless runs
	if is_release_or_export or is_headless:
		return false
	if env_override == "1":
		return true
	for arg in cmdline_args:
		if arg == "--ai-overlay" or arg == "--enable-ai-overlay" or arg == "--ai-test-hud":
			return true
	return false


func is_overlay_active() -> bool:
	return overlay_enabled and _hud_layer != null


func _ready() -> void:
	var is_exported_or_release: bool = OS.has_feature("template") or not OS.is_debug_build()
	var is_headless: bool = DisplayServer.get_name() == "headless"
	var combined_args: PackedStringArray = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	var env_flag: String = OS.get_environment("STRATEGEM_AI_OVERLAY")

	overlay_enabled = should_enable_overlay(combined_args, is_exported_or_release, is_headless, env_flag)
	if not overlay_enabled:
		# Strictly dormant during normal gameplay and all exported builds: zero UI nodes, zero input hooks
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)
		set_process_unhandled_key_input(false)
		return

	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()
	get_tree().node_added.connect(_on_tree_node_added)
	call_deferred("_inspect_current_scene")


func _set_runner_mode_active(value: bool) -> void:
	runner_mode_active = value
	if _hud_layer:
		_hud_layer.visible = overlay_enabled and not runner_mode_active


func _unhandled_key_input(event: InputEvent) -> void:
	if not overlay_enabled or runner_mode_active or not event is InputEventKey:
		return
	var kev := event as InputEventKey
	if not kev.pressed or kev.echo:
		return
	match kev.keycode:
		KEY_F1:
			if _panel:
				_panel.visible = not _panel.visible
			get_viewport().set_input_as_handled()
		KEY_F2:
			_on_toggle_bot_pressed()
			get_viewport().set_input_as_handled()
		KEY_F3:
			_on_cycle_strategy_pressed()
			get_viewport().set_input_as_handled()
		KEY_F4:
			_on_run_suite_pressed()
			get_viewport().set_input_as_handled()


func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "AITestOverlayLayer"
	_hud_layer.layer = 120
	_hud_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_hud_layer)

	var root_box := VBoxContainer.new()
	root_box.position = Vector2(2, 2)
	root_box.add_theme_constant_override("separation", 1)
	_hud_layer.add_child(root_box)

	_toggle_btn = Button.new()
	_toggle_btn.text = "AI[F1]"
	_toggle_btn.custom_minimum_size = Vector2(30, 10)
	_toggle_btn.add_theme_font_size_override("font_size", 5)
	_toggle_btn.focus_mode = Control.FOCUS_NONE
	_toggle_btn.pressed.connect(func() -> void:
		_panel.visible = not _panel.visible
	)
	root_box.add_child(_toggle_btn)

	_panel = PanelContainer.new()
	_panel.visible = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.15, 0.90)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.45, 0.36, 0.85, 0.9)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	_panel.add_theme_stylebox_override("panel", style)
	root_box.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	_panel.add_child(vbox)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 2)
	vbox.add_child(row1)

	_bot_btn = _make_small_btn("Bot:OFF[F2]", _on_toggle_bot_pressed)
	row1.add_child(_bot_btn)

	_strat_btn = _make_small_btn("Pro[F3]", _on_cycle_strategy_pressed)
	row1.add_child(_strat_btn)

	_qte_btn = _make_small_btn("QTE:Input", _on_cycle_qte_mode_pressed)
	row1.add_child(_qte_btn)

	_speed_btn = _make_small_btn("1x", _on_cycle_speed_pressed)
	row1.add_child(_speed_btn)

	_suite_btn = _make_small_btn("Suite[F4]", _on_run_suite_pressed)
	row1.add_child(_suite_btn)

	_status_label = Label.new()
	_status_label.text = "Test Overlay Active | W:0 L:0 O:0"
	_status_label.custom_minimum_size = Vector2(150, 8)
	_status_label.clip_text = true
	_status_label.add_theme_font_size_override("font_size", 5)
	_status_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	vbox.add_child(_status_label)


func _make_small_btn(txt: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 5)
	b.pressed.connect(cb)
	return b


func _on_tree_node_added(node: Node) -> void:
	if not overlay_enabled or runner_mode_active:
		return
	if node == get_tree().current_scene:
		call_deferred("_inspect_current_scene")


func _inspect_current_scene() -> void:
	if not overlay_enabled or runner_mode_active:
		return
	var scene: Node = get_tree().current_scene
	if not is_instance_valid(scene):
		return

	if scene.name == "AITestRunner":
		runner_mode_active = true
		return

	if scene.name == "StartScreen":
		if bot_autopilot:
			_status_label.text = "StartScreen -> Entering Battle..."
			await get_tree().create_timer(0.35, true, false, true).timeout
			if is_instance_valid(scene) and get_tree().current_scene == scene and bot_autopilot:
				get_tree().change_scene_to_file(BATTLE_SCENE_PATH)
		return

	if scene.has_node("EnemyHandler") and scene.has_node("PlayerHandler"):
		_attach_agent_to_battle(scene as Node2D)


func _attach_agent_to_battle(battle_node: Node2D) -> void:
	if is_instance_valid(_active_agent) and _active_agent.get_parent() == battle_node:
		return

	_restarting_scheduled = false
	_active_agent = AIBattleAgent.new()
	_active_agent.name = "LiveAIBattleAgent"
	_active_agent.setup(
		battle_node,
		strategies[current_strategy_idx],
		-1.0,
		0.30,
		qte_modes[current_qte_mode_idx]
	)
	_active_agent.enabled = bot_autopilot
	_active_agent.agent_status_updated.connect(_on_agent_status_updated)
	_active_agent.match_completed.connect(_on_live_match_completed)
	battle_node.add_child(_active_agent)


func _on_toggle_bot_pressed() -> void:
	bot_autopilot = not bot_autopilot
	_bot_btn.text = "Bot:ON[F2]" if bot_autopilot else "Bot:OFF[F2]"
	if not bot_autopilot:
		Engine.time_scale = 1.0
		_speed_btn.text = "1x"
		current_speed_idx = 0
	else:
		Engine.time_scale = speed_options[current_speed_idx]

	if is_instance_valid(_active_agent):
		_active_agent.enabled = bot_autopilot
		if bot_autopilot:
			_active_agent._capture_initial_lineup()
	else:
		_inspect_current_scene()


func _on_cycle_strategy_pressed() -> void:
	current_strategy_idx = (current_strategy_idx + 1) % strategies.size()
	var strat: AIBotBrain.Strategy = strategies[current_strategy_idx]
	var short_names: Array[String] = ["Pro", "Aggro", "Def", "Human", "Fuzz"]
	_strat_btn.text = "%s[F3]" % short_names[current_strategy_idx]
	if is_instance_valid(_active_agent):
		_active_agent.strategy = strat
		_active_agent.qte_accuracy = AIBotBrain.get_default_qte_accuracy(strat)
	_status_label.text = "Strategy -> %s" % AIBotBrain.get_strategy_name(strat)


func _on_cycle_qte_mode_pressed() -> void:
	current_qte_mode_idx = (current_qte_mode_idx + 1) % qte_modes.size()
	var mode: AIBattleAgent.QTEMode = qte_modes[current_qte_mode_idx]
	var labels: Array[String] = ["QTE:Input", "QTE:Strat", "QTE:Reset", "QTE:Fail"]
	_qte_btn.text = labels[current_qte_mode_idx]
	if is_instance_valid(_active_agent):
		_active_agent.qte_mode = mode
	_status_label.text = "QTE Mode -> %s" % AIBattleAgent.get_qte_mode_name(mode)


func _on_cycle_speed_pressed() -> void:
	current_speed_idx = (current_speed_idx + 1) % speed_options.size()
	var spd: float = speed_options[current_speed_idx]
	_speed_btn.text = "%dx" % int(spd)
	if bot_autopilot:
		Engine.time_scale = spd


func _on_run_suite_pressed() -> void:
	bot_autopilot = false
	_bot_btn.text = "Bot:OFF[F2]"
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(RUNNER_SCENE_PATH)


func _on_agent_status_updated(txt: String) -> void:
	if _status_label:
		_status_label.text = "W:%d L:%d O:%d | %s" % [
			session_wins, session_losses, session_obliterated, txt
		]


func _on_live_match_completed(summary: Dictionary) -> void:
	var out_str: String = str(summary.get("outcome", "LOSE"))
	if out_str == "WIN":
		session_wins += 1
	elif out_str == "OBLITERATED":
		session_obliterated += 1
	else:
		session_losses += 1

	_status_label.text = "%s! W:%d L:%d O:%d" % [
		out_str, session_wins, session_losses, session_obliterated
	]

	if bot_autopilot and auto_restart_battles and not _restarting_scheduled:
		_restarting_scheduled = true
		await get_tree().create_timer(1.0, true, false, true).timeout
		if bot_autopilot and not runner_mode_active:
			get_tree().paused = false
			get_tree().reload_current_scene()
