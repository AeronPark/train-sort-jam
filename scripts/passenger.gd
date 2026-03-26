extends Area2D
class_name Passenger

signal clicked(passenger: Passenger)

@export var color_index: int = 0
var grid_pos: Vector2i  # Grid position (col, row)

func _ready() -> void:
	input_pickable = true
	input_event.connect(_on_input_event)

func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)

func set_color_index(idx: int) -> void:
	color_index = idx

func board_train() -> void:
	# Animate boarding (for now just hide)
	visible = false
	queue_free()
