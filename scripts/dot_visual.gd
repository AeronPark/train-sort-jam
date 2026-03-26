extends Node2D

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var color_value = get_meta("color_value", Color.WHITE)
	var radius = get_meta("radius", 10)
	draw_circle(Vector2.ZERO, radius, color_value)
	
	# Subtle highlight
	draw_circle(Vector2(-radius * 0.3, -radius * 0.3), radius * 0.25, Color(1, 1, 1, 0.3))
