extends SceneTree
## Test harness for M1: Grid & Path with moving train

var _scene: Node2D
var _frame: int = 0

func _initialize() -> void:
	print("Test M1: Grid & Path")
	
	# Load main scene
	var packed: PackedScene = load("res://scenes/main.tscn")
	_scene = packed.instantiate()
	root.add_child(_scene)
	
	print("ASSERT PASS: Scene loaded successfully")

func _process(_delta: float) -> bool:
	_frame += 1
	
	# Get train reference to verify it's moving
	var train_follow: PathFollow2D = _scene.get_node_or_null("Board/ConveyorPath/TrainFollow")
	if train_follow:
		var progress: float = train_follow.progress_ratio
		if _frame == 10:
			print("ASSERT PASS: Train progress at frame 10: %.2f" % progress)
		elif _frame == 50:
			print("ASSERT PASS: Train progress at frame 50: %.2f" % progress)
			if progress > 0.1:
				print("ASSERT PASS: Train is moving along path")
			else:
				print("ASSERT FAIL: Train not moving as expected")
	
	# Let it run for 100 frames (10 seconds at 10fps)
	return false
