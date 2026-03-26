extends Node2D
## Train that travels along the conveyor path
## Consists of multiple wagon cars that follow the lead wagon

signal completed_lap
signal collected_item(item: Node)

@export var speed: float = 150.0  # pixels per second
@export var wagon_count: int = 3

var _path_follow: PathFollow2D
var _is_moving: bool = true
var _laps_completed: int = 0

func _ready() -> void:
	# Get reference to parent PathFollow2D
	_path_follow = get_parent() as PathFollow2D
	if not _path_follow:
		push_error("Train must be child of PathFollow2D")
		return

func _process(delta: float) -> void:
	if not _is_moving or not _path_follow:
		return
	
	# Move along the path
	var old_progress: float = _path_follow.progress_ratio
	_path_follow.progress += speed * delta
	var new_progress: float = _path_follow.progress_ratio
	
	# Check if we completed a lap (wrapped around)
	if new_progress < old_progress:
		_laps_completed += 1
		completed_lap.emit()

func start_moving() -> void:
	_is_moving = true

func stop_moving() -> void:
	_is_moving = false

func set_speed(new_speed: float) -> void:
	speed = new_speed

func get_laps_completed() -> int:
	return _laps_completed

func reset() -> void:
	if _path_follow:
		_path_follow.progress = 0
	_laps_completed = 0
	_is_moving = true
