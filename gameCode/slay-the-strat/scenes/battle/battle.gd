extends Node2D

@export var char_stats: CharacterStats
@export var music: AudioStream
@export var ghost_enemy_stats: EnemyStats
@export var gob_enemy_stats: EnemyStats
@export var golem_enemy_stats: EnemyStats
@export var wolf_enemy_stats: EnemyStats

@onready var battle_ui: BattleUI = $BattleUI as BattleUI
@onready var player_handler: PlayerHandler = $PlayerHandler as PlayerHandler
@onready var player: Player = $Player as Player
@onready var enemy_handler: EnemyHandler = $EnemyHandler as EnemyHandler
var battle_over_requested := false
var battle_over_resolution_in_progress := false


func _ready() -> void:
	_shuffle_enemy_types()

	var new_stats: CharacterStats = char_stats.create_instance()
	battle_ui.char_stats = new_stats
	player.stats = new_stats
	
	enemy_handler.child_order_changed.connect(_on_enemies_child_order_changed)
	Events.enemy_turn_ended.connect(_on_enemy_turn_ended)
	
	Events.player_turn_ended.connect(player_handler.end_turn)
	Events.player_hand_discarded.connect(enemy_handler.start_turn)
	Events.player_died.connect(_on_player_died)
	Events.battle_over_resolution_started.connect(_on_battle_over_resolution_started)
	Events.battle_over_resolution_finished.connect(_on_battle_over_resolution_finished)
	Events.battle_over_screen_requested.connect(_on_battle_over_requested)
	
	start_battle(new_stats)
	
func _shuffle_enemy_types() -> void:
	var shuffled_stats: Array[EnemyStats] = [
		ghost_enemy_stats,
		gob_enemy_stats,
		golem_enemy_stats,
		wolf_enemy_stats,
	]
	shuffled_stats.shuffle()
	shuffled_stats.resize(3)

	var enemy_index := 0
	for child in enemy_handler.get_children():
		var enemy := child as Enemy
		if enemy:
			enemy.stats = shuffled_stats[enemy_index]
			enemy_index += 1

func start_battle(stats: CharacterStats) -> void:
	get_tree().paused = false
	MusicPlayer.play(music, true)
	enemy_handler.reset_enemy_actions()
	player_handler.start_battle(stats)
	
func _on_enemies_child_order_changed() -> void:
	_check_battle_result()
	
func _on_enemy_turn_ended() -> void:
	player_handler.start_turn()
	enemy_handler.reset_enemy_actions()
	
func _on_player_died() -> void:
	_check_battle_result()

func _check_battle_result() -> void:
	if not is_inside_tree() or battle_over_requested or battle_over_resolution_in_progress:
		return

	var scene_tree := get_tree()
	if not scene_tree:
		return

	var player_alive := false
	for player_node in scene_tree.get_nodes_in_group("player"):
		var battle_player := player_node as Player
		if battle_player and battle_player.stats.health > 0:
			player_alive = true
			break

	var enemies_alive := false
	for enemy_node in scene_tree.get_nodes_in_group("enemies"):
		var enemy := enemy_node as Enemy
		if enemy and enemy.stats.health > 0:
			enemies_alive = true
			break

	if not player_alive and not enemies_alive:
		Events.battle_over_screen_requested.emit("OBLITERATED", BattleOverPanel.Type.OBLITERATED)
	elif not player_alive:
		Events.battle_over_screen_requested.emit("Dang.", BattleOverPanel.Type.LOSE)
	elif not enemies_alive:
		Events.battle_over_screen_requested.emit("Gottem! :D", BattleOverPanel.Type.WIN)

func _on_battle_over_resolution_started() -> void:
	battle_over_resolution_in_progress = true

func _on_battle_over_resolution_finished() -> void:
	battle_over_resolution_in_progress = false
	_check_battle_result()

func _on_battle_over_requested(_text: String, _type: BattleOverPanel.Type) -> void:
	battle_over_requested = true
