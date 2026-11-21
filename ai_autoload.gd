extends Node

const OVERLAY_SCENE := preload("res://ai_tester/ai_overlay.tscn")

var active_overlay: CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	_check_current_scene()

func _check_current_scene() -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	_try_attach_overlay(scene)

func _on_node_added(node: Node) -> void:
	if node == get_tree().current_scene:
		_try_attach_overlay(node)

func _try_attach_overlay(scene: Node) -> void:
	if not scene:
		return
	# Check if this scene is a battle scene
	if scene.has_node("EnemyHandler") and scene.has_node("PlayerHandler"):
		if not scene.has_node("AIOverlay"):
			active_overlay = OVERLAY_SCENE.instantiate()
			active_overlay.name = "AIOverlay"
			scene.call_deferred("add_child", active_overlay)
