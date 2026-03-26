extends Node2D

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var color_value = get_meta("color_value", Color.WHITE)
	var size = get_meta("size", 24)
	draw_circle(Vector2.ZERO, size / 2, color_value)
