extends SceneTree

# M3: Passenger boarding
const SCREEN_WIDTH := 1280
const SCREEN_HEIGHT := 720
const GRID_COLS := 10
const GRID_ROWS := 10
const CELL_SIZE := 56
const BOARD_LEFT := 150
const BOARD_TOP := 80

const COLORS := [
	Color(0.95, 0.85, 0.25),  # Yellow
	Color(0.30, 0.70, 0.35),  # Green
	Color(0.30, 0.45, 0.85),  # Blue
	Color(0.85, 0.35, 0.65),  # Pink
]

func _initialize() -> void:
	print("Generating: main.tscn (M3 - Boarding)")
	
	var root := Node2D.new()
	root.name = "Main"
	root.set_script(load("res://scripts/game_manager.gd"))
	
	# Background
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.22, 0.22, 0.27)
	bg.position = Vector2.ZERO
	bg.size = Vector2(SCREEN_WIDTH, SCREEN_HEIGHT)
	root.add_child(bg)
	
	# Board background
	var board_bg := ColorRect.new()
	board_bg.name = "BoardBg"
	board_bg.color = Color(0.45, 0.52, 0.32)
	board_bg.position = Vector2(BOARD_LEFT, BOARD_TOP)
	board_bg.size = Vector2(GRID_COLS * CELL_SIZE, GRID_ROWS * CELL_SIZE)
	root.add_child(board_bg)
	
	# Grid container
	var grid := Node2D.new()
	grid.name = "Grid"
	grid.position = Vector2(BOARD_LEFT, BOARD_TOP)
	root.add_child(grid)
	
	# Create grid cells with passengers
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			# Cell background
			var cell := ColorRect.new()
			cell.name = "Cell_%d_%d" % [col, row]
			cell.color = Color(0.40, 0.48, 0.28)
			cell.position = Vector2(col * CELL_SIZE + 2, row * CELL_SIZE + 2)
			cell.size = Vector2(CELL_SIZE - 4, CELL_SIZE - 4)
			grid.add_child(cell)
			
			# Passenger (Area2D with circle visual and collision)
			var color_idx: int = (col + row * 3) % 4
			var passenger := create_passenger(col, row, color_idx)
			grid.add_child(passenger)
	
	# Conveyor path
	var conveyor := Path2D.new()
	conveyor.name = "ConveyorPath"
	conveyor.position = Vector2(BOARD_LEFT, BOARD_TOP)
	var curve := Curve2D.new()
	var margin := CELL_SIZE * 0.5
	var grid_w: float = GRID_COLS * CELL_SIZE
	var grid_h: float = GRID_ROWS * CELL_SIZE
	curve.add_point(Vector2(margin, margin))
	curve.add_point(Vector2(grid_w - margin, margin))
	curve.add_point(Vector2(grid_w - margin, grid_h - margin))
	curve.add_point(Vector2(margin, grid_h - margin))
	curve.add_point(Vector2(margin, margin))
	conveyor.curve = curve
	conveyor.set_script(load("res://scripts/conveyor_path.gd"))
	root.add_child(conveyor)
	
	# Train
	var train_follow := PathFollow2D.new()
	train_follow.name = "TrainFollow"
	train_follow.loop = true
	train_follow.rotates = true
	conveyor.add_child(train_follow)
	
	var train := Node2D.new()
	train.name = "Train"
	train.set_script(load("res://scripts/train.gd"))
	train_follow.add_child(train)
	
	# Create 4 wagons, one for each color
	for i in range(4):
		var wagon := ColorRect.new()
		wagon.name = "Wagon%d" % i
		wagon.set_script(load("res://scripts/wagon.gd"))
		wagon.size = Vector2(36, 22)
		wagon.position = Vector2(-i * 40 - 18, -11)
		wagon.set("color_index", i)
		wagon.color = COLORS[i]
		train.add_child(wagon)
	
	# UI - Speed label
	var speed_label := Label.new()
	speed_label.name = "SpeedLabel"
	speed_label.text = "Speed: 1x"
	speed_label.position = Vector2(10, 10)
	speed_label.add_theme_font_size_override("font_size", 20)
	speed_label.add_theme_color_override("font_color", Color.WHITE)
	root.add_child(speed_label)
	
	# UI - Instructions
	var instructions := Label.new()
	instructions.name = "Instructions"
	instructions.text = "Click a passenger when matching wagon is nearby!"
	instructions.position = Vector2(10, 680)
	instructions.add_theme_font_size_override("font_size", 16)
	instructions.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	root.add_child(instructions)
	
	# UI - Color legend
	var legend := Node2D.new()
	legend.name = "Legend"
	legend.position = Vector2(BOARD_LEFT + GRID_COLS * CELL_SIZE + 40, BOARD_TOP)
	root.add_child(legend)
	
	var color_names := ["Yellow", "Green", "Blue", "Pink"]
	for i in range(4):
		var swatch := Polygon2D.new()
		swatch.name = "Swatch%d" % i
		swatch.color = COLORS[i]
		var swatch_center := Vector2(15, i * 50 + 15)
		var swatch_points := PackedVector2Array()
		for j in range(16):
			var angle: float = j * TAU / 16.0
			swatch_points.append(swatch_center + Vector2(cos(angle), sin(angle)) * 12)
		swatch.polygon = swatch_points
		legend.add_child(swatch)
		
		var lbl := Label.new()
		lbl.name = "Label%d" % i
		lbl.text = color_names[i]
		lbl.position = Vector2(40, i * 50 + 5)
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		legend.add_child(lbl)
	
	set_owner_on_new_nodes(root, root)
	
	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		push_error("Pack failed")
		quit(1)
		return
	if ResourceSaver.save(packed, "res://scenes/main.tscn") != OK:
		push_error("Save failed")
		quit(1)
		return
	
	print("Saved: res://scenes/main.tscn")
	quit(0)

func create_passenger(col: int, row: int, color_idx: int) -> Area2D:
	var passenger := Area2D.new()
	passenger.name = "Passenger_%d_%d" % [col, row]
	passenger.set_script(load("res://scripts/passenger.gd"))
	passenger.position = Vector2(col * CELL_SIZE + CELL_SIZE/2.0, row * CELL_SIZE + CELL_SIZE/2.0)
	passenger.set("color_index", color_idx)
	passenger.set("grid_pos", Vector2i(col, row))
	
	# Visual (Polygon2D circle)
	var visual := Polygon2D.new()
	visual.name = "Visual"
	var radius := (CELL_SIZE - 16) / 2.0
	var points := PackedVector2Array()
	for i in range(16):
		var angle: float = i * TAU / 16.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	visual.polygon = points
	visual.color = COLORS[color_idx]
	passenger.add_child(visual)
	
	# Collision shape
	var collision := CollisionShape2D.new()
	collision.name = "Collision"
	var shape := CircleShape2D.new()
	shape.radius = radius
	collision.shape = shape
	passenger.add_child(collision)
	
	return passenger

func set_owner_on_new_nodes(node: Node, scene_owner: Node) -> void:
	for child in node.get_children():
		child.owner = scene_owner
		if child.scene_file_path.is_empty():
			set_owner_on_new_nodes(child, scene_owner)
