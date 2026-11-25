class_name Player
extends Node2D

const WHITE_SPRITE_MATERIAL := preload("res://art/white_sprite_material.tres")

@export var stats: CharacterStats : set = set_character_stats

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var stats_ui: StatsUI = $StatsUI as StatsUI

var shiver_tween: Tween
var shiver_origin := Vector2.ZERO

const ATTACK_STOP_GAP := 20.0
const ATTACK_LUNGE_SPEED := 560.0
const ATTACK_LUNGE_MIN_TIME := 0.10
const ATTACK_LUNGE_MAX_TIME := 0.22
const ATTACK_HIT_PAUSE := 0.045

func _ready() -> void:
	shiver_origin = position
	Events.battle_over_screen_requested.connect(stop_shiver)

func start_shiver() -> void:
	stop_shiver()
	shiver_origin = position
	shiver_tween = Shaker.shake_loop(self, 3.0)

func stop_shiver(_text := "", _type = null) -> void:
	if shiver_tween and shiver_tween.is_running():
		shiver_tween.kill()
		position = shiver_origin
	shiver_tween = null

func set_character_stats(value: CharacterStats) -> void:
	stats = value
	
	if not stats.stats_changed.is_connected(update_stats):
		stats.stats_changed.connect(update_stats)
		
	update_player()
	
func update_player() -> void:
	if not stats is CharacterStats:
		return
	if not is_inside_tree():
		await ready
	
	sprite_2d.texture = stats.art
	update_stats()
	
func update_stats() -> void:
	stats_ui.update_stats(stats)

func play_attack(targets: Array[Node], on_hit: Callable) -> void:
	var target: Node2D
	var nearest_distance := INF
	for candidate in targets:
		if not candidate is Node2D or not candidate.is_in_group("enemies"):
			continue
		var enemy := candidate as Node2D
		var distance := global_position.distance_squared_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			target = enemy
	if not target:
		if on_hit.is_valid():
			on_hit.call()
		return

	var start_position := sprite_2d.position
	var target_in_player_space := to_local(target.global_position)
	var to_target := target_in_player_space - start_position
	var distance_to_target := to_target.length()
	if distance_to_target <= ATTACK_STOP_GAP:
		if on_hit.is_valid():
			on_hit.call()
		return

	var direction := to_target / distance_to_target
	var travel_distance := distance_to_target - ATTACK_STOP_GAP
	var hit_position := target_in_player_space - direction * ATTACK_STOP_GAP
	var travel_time := clampf(
		travel_distance / ATTACK_LUNGE_SPEED,
		ATTACK_LUNGE_MIN_TIME,
		ATTACK_LUNGE_MAX_TIME
	)

	var approach_tween := create_tween()
	approach_tween.tween_method(_set_attack_sprite_position, start_position, hit_position, travel_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await approach_tween.finished

	var sprite_scale := sprite_2d.scale
	sprite_2d.scale = sprite_scale * Vector2(1.15, 0.85)
	var impact_tween := create_tween()
	impact_tween.tween_property(sprite_2d, "scale", sprite_scale, 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if on_hit.is_valid():
		on_hit.call()
	await get_tree().create_timer(ATTACK_HIT_PAUSE).timeout

	var return_tween := create_tween()
	return_tween.tween_method(_set_attack_sprite_position, hit_position, start_position, travel_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await return_tween.finished

func _set_attack_sprite_position(value: Vector2) -> void:
	sprite_2d.position = value.round()
	
func take_damage(damage: int) -> void:
	if stats.health <= 0:
		return
		
		
	sprite_2d.material = WHITE_SPRITE_MATERIAL
		
	var tween := create_tween()
	tween.tween_callback(Shaker.shake.bind(self, 16, 0.15))
	tween.tween_callback(stats.take_damage.bind(damage))
	tween.tween_interval(0.18)
	
	tween.finished.connect(
		func():
			sprite_2d.material = null
			if stats.health <= 0:
				Events.player_died.emit()
				queue_free()
	)
