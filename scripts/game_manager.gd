extends Node2D

# Grid settings - 21 columns × 16 rows
const GRID_COLS := 21
const GRID_ROWS := 16
const CELL_SIZE := 26  # Smaller cells to fit buttons
const GRID_MARGIN := 20  # Space for track around grid

# Colors
const COLORS := ["yellow", "green", "blue", "pink"]
const COLOR_VALUES := {
	"yellow": Color(0.95, 0.77, 0.26),
	"green": Color(0.36, 0.72, 0.36),
	"blue": Color(0.38, 0.55, 0.78),
	"pink": Color(0.85, 0.45, 0.55)
}

# Track settings
const TRACK_WIDTH := 30
const TRAIN_SPEED := 120.0  # pixels per second

# Game state
var grid: Array = []  # 2D array of passenger colors (or null for empty)
var train_position := 0.0  # Position along track (0.0 to 1.0 = full loop)
var train_wagons: Array = []  # Array of wagon colors
var wagon_capacity := 10
var wagon_passengers: Dictionary = {}  # color -> count

# UI elements
var grid_origin: Vector2
var track_rect: Rect2
var buttons_area: Rect2

# Nodes
var passenger_sprites: Array = []  # 2D array matching grid
var wagon_nodes: Array = []
var button_nodes: Dictionary = {}  # "color_number" -> button

func _ready() -> void:
	# Calculate layout
	var viewport_size = get_viewport_rect().size
	
	# Grid takes top 60% of screen
	var grid_area_height = viewport_size.y * 0.65
	var grid_width = GRID_COLS * CELL_SIZE
	var grid_height = GRID_ROWS * CELL_SIZE
	
	# Center grid horizontally, position with track space
	grid_origin = Vector2(
		(viewport_size.x - grid_width) / 2,
		TRACK_WIDTH + GRID_MARGIN
	)
	
	# Track rect surrounds grid
	track_rect = Rect2(
		grid_origin.x - TRACK_WIDTH,
		grid_origin.y - TRACK_WIDTH,
		grid_width + TRACK_WIDTH * 2,
		grid_height + TRACK_WIDTH * 2
	)
	
	# Initialize game
	_init_grid()
	_create_passengers()
	_create_train()
	_create_buttons()
	
	queue_redraw()

func _init_grid() -> void:
	grid.clear()
	for row in range(GRID_ROWS):
		var grid_row = []
		for col in range(GRID_COLS):
			grid_row.append(COLORS[randi() % COLORS.size()])
		grid.append(grid_row)

func _create_passengers() -> void:
	# Clear existing
	for row in passenger_sprites:
		for sprite in row:
			if sprite:
				sprite.queue_free()
	passenger_sprites.clear()
	
	# Create sprite for each passenger
	for row in range(GRID_ROWS):
		var sprite_row = []
		for col in range(GRID_COLS):
			var color = grid[row][col]
			if color:
				var sprite = _create_passenger_sprite(row, col, color)
				sprite_row.append(sprite)
			else:
				sprite_row.append(null)
		passenger_sprites.append(sprite_row)

func _create_passenger_sprite(row: int, col: int, color: String) -> Node2D:
	var sprite = Node2D.new()
	sprite.set_script(preload("res://scripts/passenger_visual.gd"))
	sprite.position = _grid_to_world(row, col)
	sprite.set_meta("color", color)
	sprite.set_meta("color_value", COLOR_VALUES[color])
	sprite.set_meta("size", CELL_SIZE * 0.8)
	add_child(sprite)
	return sprite

func _grid_to_world(row: int, col: int) -> Vector2:
	return grid_origin + Vector2(col * CELL_SIZE + CELL_SIZE/2, row * CELL_SIZE + CELL_SIZE/2)

func _create_train() -> void:
	# Create 4 wagons, one per color
	train_wagons = COLORS.duplicate()
	train_wagons.shuffle()
	
	for color in train_wagons:
		wagon_passengers[color] = 0
	
	# Create wagon visuals
	for i in range(train_wagons.size()):
		var wagon = Node2D.new()
		wagon.set_script(preload("res://scripts/wagon_visual.gd"))
		wagon.set_meta("color", train_wagons[i])
		wagon.set_meta("color_value", COLOR_VALUES[train_wagons[i]])
		wagon.set_meta("index", i)
		add_child(wagon)
		wagon_nodes.append(wagon)

func _create_buttons() -> void:
	var viewport_size = get_viewport_rect().size
	var button_area_top = grid_origin.y + GRID_ROWS * CELL_SIZE + TRACK_WIDTH + 10
	var button_height = 40
	var button_width = 45
	var spacing = 8
	var row_spacing = 5
	
	for color_idx in range(COLORS.size()):
		var color = COLORS[color_idx]
		var row_y = button_area_top + color_idx * (button_height + row_spacing)
		
		# Color indicator circle
		var indicator = Node2D.new()
		indicator.set_script(preload("res://scripts/passenger_visual.gd"))
		indicator.position = Vector2(100, row_y + button_height/2)
		indicator.set_meta("color_value", COLOR_VALUES[color])
		indicator.set_meta("size", 30)
		add_child(indicator)
		
		# Number buttons 1-5
		for num in range(1, 6):
			var btn = Button.new()
			btn.text = str(num)
			btn.position = Vector2(140 + (num - 1) * (button_width + spacing), row_y)
			btn.custom_minimum_size = Vector2(button_width, button_height)
			btn.pressed.connect(_on_button_pressed.bind(color, num))
			add_child(btn)
			button_nodes["%s_%d" % [color, num]] = btn

func _on_button_pressed(color: String, count: int) -> void:
	print("Button pressed: %s x%d" % [color, count])
	_try_pickup(color, count)

func _try_pickup(color: String, count: int) -> void:
	# Find which edge the train is near
	var edge_cells = _get_train_adjacent_cells()
	
	# Count matching passengers in range
	var matching_cells = []
	for cell in edge_cells:
		var row = cell.y
		var col = cell.x
		if row >= 0 and row < GRID_ROWS and col >= 0 and col < GRID_COLS:
			if grid[row][col] == color:
				matching_cells.append(cell)
	
	if matching_cells.size() >= count:
		# Pick up passengers (take first 'count' matching)
		for i in range(count):
			var cell = matching_cells[i]
			_remove_passenger(cell.y, cell.x)
		
		wagon_passengers[color] += count
		print("Picked up %d %s passengers! Total: %d" % [count, color, wagon_passengers[color]])
		
		# Collapse grid
		_collapse_grid()
	else:
		print("Not enough %s passengers nearby! Found %d, need %d" % [color, matching_cells.size(), count])

func _get_train_adjacent_cells() -> Array:
	# Get train position on track and return adjacent grid cells
	var cells = []
	var train_world_pos = _get_train_world_position(train_position)
	
	# Determine which edge we're on and get adjacent cells
	var perimeter = _get_track_perimeter()
	var segment = int(train_position * 4) % 4  # 0=top, 1=right, 2=bottom, 3=left
	
	# Get cells within pickup range (3 cells radius)
	var pickup_range = 3
	
	match segment:
		0:  # Top edge - adjacent to row 0
			var col = int((train_world_pos.x - grid_origin.x) / CELL_SIZE)
			for c in range(col - pickup_range, col + pickup_range + 1):
				if c >= 0 and c < GRID_COLS:
					cells.append(Vector2i(c, 0))
		1:  # Right edge - adjacent to last column
			var row = int((train_world_pos.y - grid_origin.y) / CELL_SIZE)
			for r in range(row - pickup_range, row + pickup_range + 1):
				if r >= 0 and r < GRID_ROWS:
					cells.append(Vector2i(GRID_COLS - 1, r))
		2:  # Bottom edge - adjacent to last row
			var col = int((train_world_pos.x - grid_origin.x) / CELL_SIZE)
			for c in range(col - pickup_range, col + pickup_range + 1):
				if c >= 0 and c < GRID_COLS:
					cells.append(Vector2i(c, GRID_ROWS - 1))
		3:  # Left edge - adjacent to first column
			var row = int((train_world_pos.y - grid_origin.y) / CELL_SIZE)
			for r in range(row - pickup_range, row + pickup_range + 1):
				if r >= 0 and r < GRID_ROWS:
					cells.append(Vector2i(0, r))
	
	return cells

func _get_track_perimeter() -> float:
	# Total length of track (rectangle perimeter)
	var grid_width = GRID_COLS * CELL_SIZE
	var grid_height = GRID_ROWS * CELL_SIZE
	return 2 * (grid_width + TRACK_WIDTH * 2) + 2 * (grid_height + TRACK_WIDTH * 2)

func _get_train_world_position(t: float) -> Vector2:
	# t is 0.0 to 1.0 representing position around track
	# Track is a rectangle around the grid
	var grid_width = GRID_COLS * CELL_SIZE
	var grid_height = GRID_ROWS * CELL_SIZE
	
	var track_left = grid_origin.x - TRACK_WIDTH / 2
	var track_right = grid_origin.x + grid_width + TRACK_WIDTH / 2
	var track_top = grid_origin.y - TRACK_WIDTH / 2
	var track_bottom = grid_origin.y + grid_height + TRACK_WIDTH / 2
	
	var total_length = 2 * (track_right - track_left) + 2 * (track_bottom - track_top)
	var pos_along = t * total_length
	
	var top_length = track_right - track_left
	var right_length = track_bottom - track_top
	var bottom_length = top_length
	var left_length = right_length
	
	if pos_along < top_length:
		# Top edge, moving right
		return Vector2(track_left + pos_along, track_top)
	pos_along -= top_length
	
	if pos_along < right_length:
		# Right edge, moving down
		return Vector2(track_right, track_top + pos_along)
	pos_along -= right_length
	
	if pos_along < bottom_length:
		# Bottom edge, moving left
		return Vector2(track_right - pos_along, track_bottom)
	pos_along -= bottom_length
	
	# Left edge, moving up
	return Vector2(track_left, track_bottom - pos_along)

func _remove_passenger(row: int, col: int) -> void:
	grid[row][col] = null
	if passenger_sprites[row][col]:
		passenger_sprites[row][col].queue_free()
		passenger_sprites[row][col] = null

func _collapse_grid() -> void:
	# Passengers collapse toward the nearest edge that was cleared
	# For simplicity: collapse toward center from all edges
	var changed = true
	while changed:
		changed = false
		
		# Check each empty cell and pull from further out
		for row in range(GRID_ROWS):
			for col in range(GRID_COLS):
				if grid[row][col] == null:
					# Try to pull from the direction away from center
					var center_row = GRID_ROWS / 2.0
					var center_col = GRID_COLS / 2.0
					
					# Determine which direction to pull from
					var pull_row = row
					var pull_col = col
					
					if row < center_row and row > 0:
						pull_row = row - 1  # Pull from above
					elif row >= center_row and row < GRID_ROWS - 1:
						pull_row = row + 1  # Pull from below
					
					if col < center_col and col > 0:
						pull_col = col - 1  # Pull from left
					elif col >= center_col and col < GRID_COLS - 1:
						pull_col = col + 1  # Pull from right
					
					# Try pulling from calculated direction
					if pull_row != row and grid[pull_row][col] != null:
						_move_passenger(pull_row, col, row, col)
						changed = true
					elif pull_col != col and grid[row][pull_col] != null:
						_move_passenger(row, pull_col, row, col)
						changed = true

func _move_passenger(from_row: int, from_col: int, to_row: int, to_col: int) -> void:
	grid[to_row][to_col] = grid[from_row][from_col]
	grid[from_row][from_col] = null
	
	# Move sprite
	if passenger_sprites[from_row][from_col]:
		var sprite = passenger_sprites[from_row][from_col]
		passenger_sprites[to_row][to_col] = sprite
		passenger_sprites[from_row][from_col] = null
		
		# Animate movement
		var tween = create_tween()
		tween.tween_property(sprite, "position", _grid_to_world(to_row, to_col), 0.15)

func _process(delta: float) -> void:
	# Move train along track
	var perimeter = _get_track_perimeter()
	var move_amount = (TRAIN_SPEED * delta) / perimeter
	train_position = fmod(train_position + move_amount, 1.0)
	
	# Update wagon positions
	for i in range(wagon_nodes.size()):
		var wagon_offset = i * 0.03  # Space between wagons
		var wagon_t = fmod(train_position - wagon_offset + 1.0, 1.0)
		wagon_nodes[i].position = _get_train_world_position(wagon_t)
	
	queue_redraw()

func _draw() -> void:
	# Draw track (grey path around grid)
	var grid_width = GRID_COLS * CELL_SIZE
	var grid_height = GRID_ROWS * CELL_SIZE
	
	var track_color = Color(0.4, 0.4, 0.4)
	
	# Draw track as 4 rectangles around grid
	# Top
	draw_rect(Rect2(grid_origin.x - TRACK_WIDTH, grid_origin.y - TRACK_WIDTH, 
		grid_width + TRACK_WIDTH * 2, TRACK_WIDTH), track_color)
	# Bottom
	draw_rect(Rect2(grid_origin.x - TRACK_WIDTH, grid_origin.y + grid_height,
		grid_width + TRACK_WIDTH * 2, TRACK_WIDTH), track_color)
	# Left
	draw_rect(Rect2(grid_origin.x - TRACK_WIDTH, grid_origin.y,
		TRACK_WIDTH, grid_height), track_color)
	# Right
	draw_rect(Rect2(grid_origin.x + grid_width, grid_origin.y,
		TRACK_WIDTH, grid_height), track_color)
	
	# Draw grid background
	draw_rect(Rect2(grid_origin, Vector2(grid_width, grid_height)), Color(0.25, 0.28, 0.25))
	
	# Draw grid lines
	var line_color = Color(0.35, 0.38, 0.35)
	for row in range(GRID_ROWS + 1):
		var y = grid_origin.y + row * CELL_SIZE
		draw_line(Vector2(grid_origin.x, y), Vector2(grid_origin.x + grid_width, y), line_color, 1)
	for col in range(GRID_COLS + 1):
		var x = grid_origin.x + col * CELL_SIZE
		draw_line(Vector2(x, grid_origin.y), Vector2(x, grid_origin.y + grid_height), line_color, 1)
	
	# Draw train position indicator
	var train_pos = _get_train_world_position(train_position)
	draw_circle(train_pos, 8, Color.WHITE)

func _check_win() -> bool:
	for row in grid:
		for cell in row:
			if cell != null:
				return false
	return true
