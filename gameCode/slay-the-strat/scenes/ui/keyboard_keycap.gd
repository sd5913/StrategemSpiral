class_name KeyboardKeycap
extends Control

const SIZE := Vector2(9, 8)
const NUMBER_FONT := preload("res://art/pixel_rpg.ttf")
const FONT_SIZE := 6
const FONT_CACHE_SIZE := Vector2i(FONT_SIZE, 0)

var number := 1
var selected := false


func set_key(value: int, is_selected: bool) -> void:
	number = value
	selected = is_selected
	visible = value >= 1 and value <= 9
	queue_redraw()


func _draw() -> void:
	if number < 1 or number > 9:
		return
	var face := Color("#ffda8d") if selected else Color("#c8bda5")
	var highlight := Color("#fff0c5") if selected else Color("#e7ddc4")
	var rim := Color("#96613a") if selected else Color("#6d6052")
	var ink := Color("#29202b")
	draw_rect(Rect2(0, 1, 9, 6), rim)
	draw_rect(Rect2(1, 0, 7, 1), highlight)
	draw_rect(Rect2(1, 1, 7, 6), face)
	draw_rect(Rect2(1, 7, 7, 1), rim)
	# Center the glyph's drawn bounds rather than its advance width.
	var digit := str(number)
	var glyph := NUMBER_FONT.get_glyph_index(FONT_SIZE, digit.unicode_at(0), 0)
	NUMBER_FONT.render_glyph(0, FONT_CACHE_SIZE, glyph)
	var glyph_size := NUMBER_FONT.get_glyph_size(0, FONT_CACHE_SIZE, glyph)
	var glyph_offset := NUMBER_FONT.get_glyph_offset(0, FONT_CACHE_SIZE, glyph)
	var face_size := Vector2(SIZE.x, SIZE.y - 1)
	var baseline := (face_size - glyph_size) * 0.5 - glyph_offset
	draw_char(NUMBER_FONT, baseline, digit, FONT_SIZE, ink)
