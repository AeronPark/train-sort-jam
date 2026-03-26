extends Path2D
## Conveyor path that trains travel along
## In later milestones, this will reshape inward when collections happen

signal path_reshaped

var _original_curve: Curve2D

func _ready() -> void:
	# Store original curve for potential reset
	_original_curve = curve.duplicate()

func get_path_length() -> float:
	return curve.get_baked_length()

## Reshape the path inward by a given amount (for M3+)
func reshape_inward(amount: float) -> void:
	# TODO: Implement path reshaping logic in M3
	# For now, this is a placeholder
	path_reshaped.emit()

## Reset path to original shape
func reset_path() -> void:
	curve = _original_curve.duplicate()
	path_reshaped.emit()
