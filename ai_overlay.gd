class_name AIOverlay
extends CanvasLayer

const AIBot = preload("res://ai_tester/ai_bot.gd")
const AIController = preload("res://ai_tester/ai_controller.gd")

@onready var controller: AIController = $AIController as AIController
@onready var toggle_btn: Button = %ToggleBtn
@onready var strat_btn: Button = %StratBtn
@onready var speed_btn: Button = %SpeedBtn
@onready var status_label: Label = %StatusLabel
@onready var score_label: Label = %ScoreLabel

var current_speed_idx: int = 0
var speed_presets := [
	{"label": "1x", "scale": 1.0, "delay": 0.35},
	{"label": "3x", "scale": 3.0, "delay": 0.15},
	{"label": "10x", "scale": 10.0, "delay": 0.02}
]

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	toggle_btn.pressed.connect(_on_toggle_pressed)
	strat_btn.pressed.connect(_on_strat_pressed)
	speed_btn.pressed.connect(_on_speed_pressed)

	controller.action_taken.connect(_on_action_taken)
	controller.game_finished.connect(_on_game_finished)

	_update_ui()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		match event.keycode:
			KEY_F1:
				_on_toggle_pressed()
			KEY_F2:
				_on_strat_pressed()
			KEY_F3:
				_on_speed_pressed()
			KEY_F4:
				get_tree().paused = false
				get_tree().reload_current_scene()

func _on_toggle_pressed() -> void:
	controller.enabled = not controller.enabled
	_update_ui()
	if controller.enabled and not controller.is_taking_turn:
		controller._play_ai_turn()

func _on_strat_pressed() -> void:
	var next_strat := (int(controller.strategy) + 1) % 4
	controller.strategy = next_strat as AIBot.Strategy
	_update_ui()

func _on_speed_pressed() -> void:
	current_speed_idx = (current_speed_idx + 1) % speed_presets.size()
	var preset = speed_presets[current_speed_idx]
	Engine.time_scale = preset.scale
	controller.play_delay = preset.delay
	_update_ui()

func _on_action_taken(msg: String) -> void:
	if status_label:
		status_label.text = msg

func _on_game_finished(_result: String, _stats: Dictionary) -> void:
	_update_ui()

func _update_ui() -> void:
	if not toggle_btn:
		return

	if controller.enabled:
		toggle_btn.text = "🤖 AI: ON"
		toggle_btn.modulate = Color(0.4, 1.0, 0.4)
	else:
		toggle_btn.text = "👤 AI: OFF"
		toggle_btn.modulate = Color(1.0, 0.6, 0.6)

	match controller.strategy:
		AIBot.Strategy.BALANCED:
			strat_btn.text = "⚖️ Bal"
		AIBot.Strategy.AGGRESSIVE:
			strat_btn.text = "⚔️ Atk"
		AIBot.Strategy.DEFENSIVE:
			strat_btn.text = "🛡️ Def"
		AIBot.Strategy.RANDOM_FUZZ:
			strat_btn.text = "🎲 Rnd"

	speed_btn.text = "⚡ " + speed_presets[current_speed_idx].label
	score_label.text = "W:%d L:%d" % [controller.wins, controller.losses]
