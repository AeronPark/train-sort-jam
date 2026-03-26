extends SceneTree

func _initialize() -> void:
	print("Loading test scene...")
	var scene: PackedScene = load("res://scenes/test_node2d.tscn")
	if scene == null:
		push_error("Failed to load scene")
		quit(1)
		return
	
	var instance = scene.instantiate()
	root.add_child(instance)
	print("Scene instantiated")

func _process(_delta: float) -> bool:
	print("Taking screenshot...")
	var viewport = root.get_viewport()
	var img = viewport.get_texture().get_image()
	if img == null:
		push_error("Failed to get image")
		return false
	
	print("Image size: %d x %d" % [img.get_width(), img.get_height()])
	var err = img.save_png("/tmp/godot_test.png")
	if err != OK:
		push_error("Failed to save: " + str(err))
	else:
		print("Saved to /tmp/godot_test.png")
	
	return true  # Exit
