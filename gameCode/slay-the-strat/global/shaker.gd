extends Node

func shake(thing: Node2D, strength: float, duration: float = 0.2) -> void:
	if not thing:
		return
	
	var orig_pos := thing.position
	var shake_count := 15
	var tween := create_tween()
	
	for i in shake_count:
		var shake_offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		var target := orig_pos + strength * shake_offset
		if i % 2 == 0:
			target = orig_pos
		tween.tween_property(thing, "position", target, duration / float(shake_count))
		strength *= 0.75
		
	tween.finished.connect(func(): thing.position = orig_pos)

func shake_loop(thing: Node2D, strength: float) -> Tween:
	if not thing:
		return null
	var orig_pos := thing.position
	var tween := create_tween().set_loops()
	tween.tween_callback(func():
		if not is_instance_valid(thing):
			return
		var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		thing.position = orig_pos + strength * offset
	)
	tween.tween_interval(0.05)
	tween.tween_callback(func():
		if is_instance_valid(thing):
			thing.position = orig_pos
	)
	tween.tween_interval(0.05)
	return tween
