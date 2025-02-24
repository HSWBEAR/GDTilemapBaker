@tool
extends Control

var category_name: String = "TileMap Baker"

func _init():
	custom_minimum_size.y = 30
	size_flags_horizontal = SIZE_EXPAND_FILL

func set_category_name(name: String):
	category_name = name
	queue_redraw()

func _draw():
	var font = get_theme_default_font()
	var font_size = get_theme_default_font_size()
	var color = get_theme_color("font_color", "Editor")
	var height = custom_minimum_size.y
	
	draw_string(font, Vector2(10, height / 2 + font_size / 2), category_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color) 