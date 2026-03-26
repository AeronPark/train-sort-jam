extends Node2D

const WAGON_WIDTH := 30
const WAGON_HEIGHT := 20

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var color_value = get_meta("color_value", Color.WHITE)
	var idx = get_meta("index", 0)
	
	# Draw wagon body
	var rect = Rect2(-WAGON_WIDTH/2, -WAGON_HEIGHT/2, WAGON_WIDTH, WAGON_HEIGHT)
	draw_rect(rect, color_value)
	draw_rect(rect, Color.WHITE, false, 2)
	
	# Draw locomotive indicator on first wagon
	if idx == 0:
		draw_circle(Vector2(WAGON_WIDTH/4, -WAGON_HEIGHT/4), 4, Color.WHITE)
