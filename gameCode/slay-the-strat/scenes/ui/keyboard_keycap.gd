class_name KeyboardKeycap
extends Control

const SIZE := Vector2(11, 9)
const DIGITS := [
	[2, 6, 2, 2, 7],
	[7, 1, 7, 4, 7],
	[7, 1, 7, 1, 7],
	[5, 5, 7, 1, 1],
	[7, 4, 7, 1, 7],
	[7, 4, 7, 5, 7],
	[7, 1, 2, 2, 2],
	[7, 5, 7, 5, 7],
	[7, 5, 7, 1, 7],
]

var number := 1
var selected := false


func set_key(value: int, is_selected: bool) -> void:
	number = value
	selected = is_selected
	visible = value >= 1 and value <= DIGITS.size()
	queue_redraw()


func _draw() -> void:
	if number < 1 or number > DIGITS.size():
		return
	var face := Color("#ffda8d") if selected else Color("#c8bda5")
	var highlight := Color("#fff0c5") if selected else Color("#e7ddc4")
	var rim := Color("#96613a") if selected else Color("#6d6052")
	var ink := Color("#29202b")
	draw_rect(Rect2(0, 1, 11, 7), rim)
	draw_rect(Rect2(1, 0, 9, 1), highlight)
	draw_rect(Rect2(1, 1, 9, 6), face)
	draw_rect(Rect2(1, 7, 9, 1), rim)
	draw_rect(Rect2(1, 8, 9, 1), ink)
	# Center the ink on the face, independently of the pixel font's bearings.
	var rows: Array = DIGITS[number - 1]
	for y in range(rows.size()):
		for x in range(3):
			if rows[y] & (1 << (2 - x)):
				draw_rect(Rect2(4 + x, 1 + y, 1, 1), ink)
