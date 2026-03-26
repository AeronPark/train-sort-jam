extends ColorRect

@export var color_index: int = 0
@export var capacity: int = 3
var passengers: Array = []

# Colors matching the passenger colors
const WAGON_COLORS := [
	Color(0.95, 0.85, 0.25),  # Yellow
	Color(0.30, 0.70, 0.35),  # Green
	Color(0.30, 0.45, 0.85),  # Blue
	Color(0.85, 0.35, 0.65),  # Pink
]

func _ready() -> void:
	update_color()

func update_color() -> void:
	if color_index >= 0 and color_index < WAGON_COLORS.size():
		color = WAGON_COLORS[color_index]

func can_board() -> bool:
	return passengers.size() < capacity

func board_passenger(p) -> bool:
	if not can_board():
		return false
	if p.color_index != color_index:
		return false
	passengers.append(p)
	p.board_train()
	return true

func get_passenger_count() -> int:
	return passengers.size()

func is_full() -> bool:
	return passengers.size() >= capacity
