extends Node2D

var progress := 0.0
var boosted := false
var tween: Tween


func play(at_position: Vector2, is_boosted: bool) -> void:
	if tween and tween.is_running():
		tween.kill()
	position = at_position
	boosted = is_boosted
	_draw_frame(0.0)
	show()
	tween = create_tween()
	tween.tween_method(_draw_frame, 0.0, 1.0, 0.42 if boosted else 0.26)
	tween.tween_callback(hide)


func _draw_frame(value: float) -> void:
	progress = value
	queue_redraw()


func _draw() -> void:
	var color := Color("#ffdc8d") if boosted else Color("#b5aca1")
	color.a = (1.0 - progress) * (1.0 if boosted else 0.65)
	var distance := lerpf(4.0, 23.0 if boosted else 12.0, ease(progress, 0.42))
	var spark_count := 8 if boosted else 4
	for i in range(spark_count):
		var direction := Vector2.RIGHT.rotated(TAU * i / spark_count)
		var size := Vector2(2, 2) if boosted else Vector2.ONE
		draw_rect(Rect2((direction * distance).round(), size), color)
