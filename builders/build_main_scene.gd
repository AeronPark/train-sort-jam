extends SceneTree

const GRID_SIZE := 10  # 10x10 grid
const CELL_SIZE := 64  # pixels per cell
const BOARD_OFFSET := Vector2(140, 60)  # offset from top-left

func _initialize() -> void:
	print("Generating: main.tscn")
	
	var root := Node2D.new()
	root.name = "Main"
	
	# Background
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.2, 0.2, 0.25)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.size = Vector2(1280, 720)
	root.add_child(bg)
	
	# Game board container
	var board := Node2D.new()
	board.name = "Board"
	board.position = BOARD_OFFSET
	root.add_child(board)
	
	# Grid visual (cells)
	var grid := Node2D.new()
	grid.name = "Grid"
	board.add_child(grid)
	
	# Create grid cells
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var cell := ColorRect.new()
			cell.name = "Cell_%d_%d" % [x, y]
			cell.size = Vector2(CELL_SIZE - 4, CELL_SIZE - 4)
			cell.position = Vector2(x * CELL_SIZE + 2, y * CELL_SIZE + 2)
			cell.color = Color(0.3, 0.5, 0.3) if (x + y) % 2 == 0 else Color(0.35, 0.55, 0.35)
			grid.add_child(cell)
	
	# Conveyor path - rectangular loop around the grid edge
	var conveyor := Path2D.new()
	conveyor.name = "ConveyorPath"
	var curve := Curve2D.new()
	
	# Create rectangular path around the grid (clockwise from top-left)
	var margin := CELL_SIZE * 0.5
	var grid_width: float = GRID_SIZE * CELL_SIZE
	var grid_height: float = GRID_SIZE * CELL_SIZE
	
	# Path points (rectangular loop with rounded corners via control points)
	# Top-left
	curve.add_point(Vector2(margin, margin))
	# Top-right
	curve.add_point(Vector2(grid_width - margin, margin))
	# Bottom-right  
	curve.add_point(Vector2(grid_width - margin, grid_height - margin))
	# Bottom-left
	curve.add_point(Vector2(margin, grid_height - margin))
	# Close the loop back to start
	curve.add_point(Vector2(margin, margin))
	
	conveyor.curve = curve
	conveyor.set_script(load("res://scripts/conveyor_path.gd"))
	board.add_child(conveyor)
	
	# Train container (PathFollow2D)
	var train_follow := PathFollow2D.new()
	train_follow.name = "TrainFollow"
	train_follow.loop = true
	train_follow.rotates = true
	conveyor.add_child(train_follow)
	
	# Train visual (wagon)
	var train := Node2D.new()
	train.name = "Train"
	train.set_script(load("res://scripts/train.gd"))
	train_follow.add_child(train)
	
	# Train wagon visual (simple colored rectangles)
	for i in range(3):  # 3 wagon cars
		var wagon := ColorRect.new()
		wagon.name = "Wagon%d" % i
		wagon.size = Vector2(40, 24)
		wagon.position = Vector2(-i * 45 - 20, -12)  # Offset each wagon behind
		wagon.color = Color(0.8, 0.2, 0.2) if i == 0 else Color(0.6, 0.3, 0.3)
		train.add_child(wagon)
	
	# UI container
	var ui := CanvasLayer.new()
	ui.name = "UI"
	root.add_child(ui)
	
	# Wagon buttons panel (bottom of screen)
	var button_panel := Control.new()
	button_panel.name = "ButtonPanel"
	button_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	button_panel.position = Vector2(140, 520)
	button_panel.size = Vector2(1000, 180)
	ui.add_child(button_panel)
	
	# Create numbered wagon buttons (3x3 grid like in the GDD)
	var button_colors := [
		Color(0.6, 0.3, 0.7),  # Purple - 3
		Color(0.8, 0.3, 0.4),  # Red - 2
		Color(0.3, 0.7, 0.4),  # Green - 4
	]
	var button_numbers := [3, 2, 4]
	
	for row in range(3):
		for col in range(3):
			var btn := Button.new()
			btn.name = "WagonBtn_%d_%d" % [row, col]
			btn.text = str(button_numbers[col])
			btn.position = Vector2(col * 80, row * 50)
			btn.size = Vector2(70, 45)
			# Lighter colors for lower rows
			var alpha := 1.0 - row * 0.25
			btn.modulate = Color(1, 1, 1, alpha)
			button_panel.add_child(btn)
	
	# Speed label
	var speed_label := Label.new()
	speed_label.name = "SpeedLabel"
	speed_label.text = "Speed: 1x"
	speed_label.position = Vector2(10, 10)
	ui.add_child(speed_label)
	
	# Set ownership chain
	set_owner_on_new_nodes(root, root)
	
	# Save scene
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("Pack failed: " + str(err))
		quit(1)
		return
	
	err = ResourceSaver.save(packed, "res://scenes/main.tscn")
	if err != OK:
		push_error("Save failed: " + str(err))
		quit(1)
		return
	
	print("Saved: res://scenes/main.tscn")
	quit(0)

func set_owner_on_new_nodes(node: Node, scene_owner: Node) -> void:
	for child in node.get_children():
		child.owner = scene_owner
		if child.scene_file_path.is_empty():
			set_owner_on_new_nodes(child, scene_owner)
