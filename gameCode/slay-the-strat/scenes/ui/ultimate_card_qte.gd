extends CanvasLayer

const DURATION := 3.0

@onready var panel: Panel = $Panel
@onready var keys: HBoxContainer = %Keys
@onready var meter: ProgressBar = %Meter

var active := false
var elapsed := 0.0
var sequence: Array[String] = []
var progress := 0
var keycaps: Array[PanelContainer] = []
var keycap_styles: Array[StyleBoxFlat] = []
var success_callback: Callable
var failure_callback: Callable

func _ready() -> void:
	panel.hide()
	Events.ultimate_card_qte_started.connect(start)
	Events.battle_over_screen_requested.connect(_on_battle_over)

func start(new_sequence: Array[String], success: Callable, failure: Callable) -> void:
	if active:
		return
	sequence = new_sequence
	progress = 0
	elapsed = 0.0
	success_callback = success
	failure_callback = failure
	active = true
	meter.value = 0.0
	_build_key_prompt()
	panel.show()

func _build_key_prompt() -> void:
	for child in keys.get_children():
		child.queue_free()
	keycaps.clear()
	keycap_styles.clear()
	for direction in sequence:
		var keycap := PanelContainer.new()
		keycap.custom_minimum_size = Vector2(12, 12)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.09, 0.22)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.42, 0.34, 0.72)
		style.corner_radius_top_left = 2
		style.corner_radius_top_right = 2
		style.corner_radius_bottom_right = 2
		style.corner_radius_bottom_left = 2
		keycap.add_theme_stylebox_override("panel", style)

		var label := Label.new()
		label.text = _direction_letter(direction)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 9)
		label.add_theme_color_override("font_color", Color(0.88, 0.84, 1.0))
		keycap.add_child(label)
		keys.add_child(keycap)
		keycaps.append(keycap)
		keycap_styles.append(style)
	_update_keycaps()

func _direction_letter(direction: String) -> String:
	match direction:
		"up":
			return "W"
		"down":
			return "S"
		"left":
			return "A"
		"right":
			return "D"
		_:
			return "?"

func _update_keycaps() -> void:
	for index in range(keycap_styles.size()):
		var style := keycap_styles[index]
		if index < progress:
			style.bg_color = Color(0.08, 0.32, 0.3)
			style.border_color = Color(0.35, 0.9, 0.76)
		elif index == progress:
			style.bg_color = Color(0.24, 0.18, 0.44)
			style.border_color = Color(0.72, 0.6, 1.0)
		else:
			style.bg_color = Color(0.1, 0.09, 0.22)
			style.border_color = Color(0.42, 0.34, 0.72)
		keycaps[index].add_theme_stylebox_override("panel", style)

func _process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	meter.value = elapsed / DURATION * 100.0
	if elapsed >= DURATION:
		_resolve(false)

func _unhandled_input(event: InputEvent) -> void:
	if not active or not event is InputEventKey or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	var direction := ""
	match key_event.keycode:
		KEY_W:
			direction = "up"
		KEY_S:
			direction = "down"
		KEY_A:
			direction = "left"
		KEY_D:
			direction = "right"
		_:
			return
	get_viewport().set_input_as_handled()
	if direction == sequence[progress]:
		progress += 1
		_update_keycaps()
		if progress >= sequence.size():
			_resolve(true)
	else:
		progress = 0
		_update_keycaps()

func _resolve(success: bool) -> void:
	if not active:
		return
	active = false
	panel.hide()
	var callback := success_callback if success else failure_callback
	success_callback = Callable()
	failure_callback = Callable()
	if callback.is_valid():
		callback.call()

func _on_battle_over(_text: String, _type: BattleOverPanel.Type) -> void:
	active = false
	panel.hide()
	success_callback = Callable()
	failure_callback = Callable()
