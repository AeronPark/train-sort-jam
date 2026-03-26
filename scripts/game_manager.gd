extends Node2D

# Grid settings - Portrait orientation like reference
const GRID_COLS := 16
const GRID_ROWS := 21
const CELL_SIZE := 22
const GRID_MARGIN := 10

# Colors - 6 colors visible in reference
const COLORS := ["red", "pink", "purple", "green", "cyan", "yellow"]
const COLOR_VALUES := {
	"red": Color(0.9, 0.25, 0.25),
	"pink": Color(0.95, 0.5, 0.7),
	"purple": Color(0.6, 0.3, 0.8),
	"green": Color(0.3, 0.75, 0.3),
	"cyan": Color(0.5, 0.85, 0.9),
	"yellow": Color(0.95, 0.9, 0.3)
}

# Track settings
const TRACK_WIDTH := 24
const TRAIN_SPEED := 100.0

# Game state
var grid: Array = []  # 2D array of passenger colors (or null)
var train_position := 0.0  # 0.0 to 1.0 around track
var pickup_range := 4  # How many cells the train can reach

# UI
var grid_origin: Vector2
var passenger_sprites: Array = []
var color_buttons: Dictionary = {}  # color -> Button
var color_counts: Dictionary = {}  # color -> current count in zone

func _ready() -> void:
	var viewport_size = get_viewport_rect().size
	
	# Grid position - centered, top area
	var grid_width = GRID_COLS * CELL_SIZE
	var grid_height = GRID_ROWS * CELL_SIZE
	grid_origin = Vector2(
		(viewport_size.x - grid_width) / 2,
		TRACK_WIDTH + GRID_MARGIN + 20
	)
	
	_init_grid()
	_create_passengers()
	_create_buttons()
	
	queue_redraw()

func _init_grid() -> void:
	grid.clear()
	
	# Create color bands like in reference image
	for row in range(GRID_ROWS):
		var grid_row = []
		var band_color: String
		
		# Assign colors by row bands
		if row < 4:
			band_color = "red"
		elif row < 7:
			band_color = "pink"  
		elif row < 11:
			band_color = "purple"
		elif row < 15:
			band_color = "green"
		elif row < 18:
			band_color = "cyan"
		else:
			band_color = "yellow"
		
		for col in range(GRID_COLS):
			# Some randomness within bands
			if randf() < 0.15:
				# Mix in adjacent colors occasionally
				var adjacent_colors = _get_adjacent_band_colors(band_color)
				grid_row.append(adjacent_colors[randi() % adjacent_colors.size()])
			else:
				grid_row.append(band_color)
		grid.append(grid_row)

func _get_adjacent_band_colors(color: String) -> Array:
	match color:
		"red": return ["pink", "red"]
		"pink": return ["red", "purple", "pink"]
		"purple": return ["pink", "green", "purple"]
		"green": return ["purple", "cyan", "green"]
		"cyan": return ["green", "yellow", "cyan"]
		"yellow": return ["cyan", "yellow"]
	return [color]

func _create_passengers() -> void:
	for row in passenger_sprites:
		for sprite in row:
			if sprite:
				sprite.queue_free()
	passenger_sprites.clear()
	
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
	sprite.set_meta("size", CELL_SIZE * 0.75)
	add_child(sprite)
	return sprite

func _grid_to_world(row: int, col: int) -> Vector2:
	return grid_origin + Vector2(col * CELL_SIZE + CELL_SIZE/2, row * CELL_SIZE + CELL_SIZE/2)

func _create_buttons() -> void:
	var viewport_size = get_viewport_rect().size
	var grid_height = GRID_ROWS * CELL_SIZE
	var button_area_top = grid_origin.y + grid_height + TRACK_WIDTH + 30
	
	var button_size = 65
	var spacing = 15
	var total_width = 3 * button_size + 2 * spacing
	var start_x = (viewport_size.x - total_width) / 2
	
	# 3x3 grid of buttons, but only 6 colors
	var button_positions = [
		[0, 0], [0, 1], [0, 2],  # Row 1: purple, red, green
		[1, 0], [1, 1], [1, 2],  # Row 2: purple, pink, pink
		[2, 0], [2, 1], [2, 2]   # Row 3: pink, cyan, yellow
	]
	
	# Assign colors to button positions (matching reference layout roughly)
	var button_colors = ["purple", "red", "green", "purple", "pink", "pink", "pink", "cyan", "yellow"]
	
	# Actually, let's use one button per color in a 2x3 grid
	var colors_for_buttons = ["red", "pink", "purple", "green", "cyan", "yellow"]
	
	for i in range(colors_for_buttons.size()):
		var color = colors_for_buttons[i]
		var row = i / 3
		var col = i % 3
		
		var btn = Button.new()
		btn.text = "0"
		btn.custom_minimum_size = Vector2(button_size, button_size)
		btn.position = Vector2(
			start_x + col * (button_size + spacing),
			button_area_top + row * (button_size + spacing)
		)
		
		# Style the button with color
		var style = StyleBoxFlat.new()
		style.bg_color = COLOR_VALUES[color]
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		
		# Dark text for light colors
		if color in ["yellow", "cyan", "pink"]:
			btn.add_theme_color_override("font_color", Color.BLACK)
		else:
			btn.add_theme_color_override("font_color", Color.WHITE)
		
		btn.add_theme_font_size_override("font_size", 28)
		btn.pressed.connect(_on_color_button_pressed.bind(color))
		
		add_child(btn)
		color_buttons[color] = btn
		color_counts[color] = 0

func _on_color_button_pressed(color: String) -> void:
	var count = color_counts[color]
	if count > 0:
		_pickup_color(color)

func _pickup_color(color: String) -> void:
	var cells = _get_train_adjacent_cells()
	var picked = 0
	
	for cell in cells:
		var row = cell.y
		var col = cell.x
		if row >= 0 and row < GRID_ROWS and col >= 0 and col < GRID_COLS:
			if grid[row][col] == color:
				_remove_passenger(row, col)
				picked += 1
	
	if picked > 0:
		print("Picked up %d %s passengers!" % [picked, color])
		_collapse_grid()
		_update_counts()

func _get_train_adjacent_cells() -> Array:
	var cells = []
	var train_world_pos = _get_train_world_position(train_position)
	
	# Determine which edge and get cells
	var grid_width = GRID_COLS * CELL_SIZE
	var grid_height = GRID_ROWS * CELL_SIZE
	
	var track_left = grid_origin.x - TRACK_WIDTH / 2
	var track_right = grid_origin.x + grid_width + TRACK_WIDTH / 2
	var track_top = grid_origin.y - TRACK_WIDTH / 2
	var track_bottom = grid_origin.y + grid_height + TRACK_WIDTH / 2
	
	var total_length = 2 * (track_right - track_left) + 2 * (track_bottom - track_top)
	var pos_along = train_position * total_length
	
	var top_length = track_right - track_left
	var right_length = track_bottom - track_top
	var bottom_length = top_length
	
	if pos_along < top_length:
		# Top edge - row 0
		var col = int((train_world_pos.x - grid_origin.x) / CELL_SIZE)
		for c in range(col - pickup_range, col + pickup_range + 1):
			if c >= 0 and c < GRID_COLS:
				cells.append(Vector2i(c, 0))
	elif pos_along < top_length + right_length:
		# Right edge - last column
		var row = int((train_world_pos.y - grid_origin.y) / CELL_SIZE)
		for r in range(row - pickup_range, row + pickup_range + 1):
			if r >= 0 and r < GRID_ROWS:
				cells.append(Vector2i(GRID_COLS - 1, r))
	elif pos_along < top_length + right_length + bottom_length:
		# Bottom edge - last row
		var col = int((train_world_pos.x - grid_origin.x) / CELL_SIZE)
		for c in range(col - pickup_range, col + pickup_range + 1):
			if c >= 0 and c < GRID_COLS:
				cells.append(Vector2i(c, GRID_ROWS - 1))
	else:
		# Left edge - column 0
		var row = int((train_world_pos.y - grid_origin.y) / CELL_SIZE)
		for r in range(row - pickup_range, row + pickup_range + 1):
			if r >= 0 and r < GRID_ROWS:
				cells.append(Vector2i(0, r))
	
	return cells

func _get_train_world_position(t: float) -> Vector2:
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
	
	if pos_along < top_length:
		return Vector2(track_left + pos_along, track_top)
	pos_along -= top_length
	
	if pos_along < right_length:
		return Vector2(track_right, track_top + pos_along)
	pos_along -= right_length
	
	if pos_along < bottom_length:
		return Vector2(track_right - pos_along, track_bottom)
	pos_along -= bottom_length
	
	return Vector2(track_left, track_bottom - pos_along)

func _remove_passenger(row: int, col: int) -> void:
	grid[row][col] = null
	if passenger_sprites[row][col]:
		passenger_sprites[row][col].queue_free()
		passenger_sprites[row][col] = null

func _collapse_grid() -> void:
	# Collapse toward edges (outward from center)
	var changed = true
	var iterations = 0
	while changed and iterations < 100:
		changed = false
		iterations += 1
		
		var center_row = GRID_ROWS / 2.0
		var center_col = GRID_COLS / 2.0
		
		for row in range(GRID_ROWS):
			for col in range(GRID_COLS):
				if grid[row][col] == null:
					# Find direction to pull from (toward center)
					var pull_from = _find_pull_source(row, col, center_row, center_col)
					if pull_from != Vector2i(-1, -1):
						_move_passenger(pull_from.y, pull_from.x, row, col)
						changed = true

func _find_pull_source(row: int, col: int, center_row: float, center_col: float) -> Vector2i:
	# Pull from the direction toward center
	var candidates = []
	
	# Check row direction
	if row < center_row and row + 1 < GRID_ROWS:
		if grid[row + 1][col] != null:
			candidates.append(Vector2i(col, row + 1))
	elif row >= center_row and row - 1 >= 0:
		if grid[row - 1][col] != null:
			candidates.append(Vector2i(col, row - 1))
	
	# Check column direction
	if col < center_col and col + 1 < GRID_COLS:
		if grid[row][col + 1] != null:
			candidates.append(Vector2i(col + 1, row))
	elif col >= center_col and col - 1 >= 0:
		if grid[row][col - 1] != null:
			candidates.append(Vector2i(col - 1, row))
	
	if candidates.size() > 0:
		return candidates[0]
	return Vector2i(-1, -1)

func _move_passenger(from_row: int, from_col: int, to_row: int, to_col: int) -> void:
	grid[to_row][to_col] = grid[from_row][from_col]
	grid[from_row][from_col] = null
	
	if passenger_sprites[from_row][from_col]:
		var sprite = passenger_sprites[from_row][from_col]
		passenger_sprites[to_row][to_col] = sprite
		passenger_sprites[from_row][from_col] = null
		
		var tween = create_tween()
		tween.tween_property(sprite, "position", _grid_to_world(to_row, to_col), 0.1)

func _update_counts() -> void:
	# Reset counts
	for color in COLORS:
		color_counts[color] = 0
	
	# Count passengers in pickup zone
	var cells = _get_train_adjacent_cells()
	for cell in cells:
		var row = cell.y
		var col = cell.x
		if row >= 0 and row < GRID_ROWS and col >= 0 and col < GRID_COLS:
			var color = grid[row][col]
			if color:
				color_counts[color] += 1
	
	# Update button labels
	for color in color_buttons:
		color_buttons[color].text = str(color_counts[color])

func _process(delta: float) -> void:
	# Move train
	var grid_width = GRID_COLS * CELL_SIZE
	var grid_height = GRID_ROWS * CELL_SIZE
	var perimeter = 2 * (grid_width + TRACK_WIDTH) + 2 * (grid_height + TRACK_WIDTH)
	var move_amount = (TRAIN_SPEED * delta) / perimeter
	train_position = fmod(train_position + move_amount, 1.0)
	
	_update_counts()
	queue_redraw()

func _draw() -> void:
	var grid_width = GRID_COLS * CELL_SIZE
	var grid_height = GRID_ROWS * CELL_SIZE
	
	# Draw outer frame (light gray like reference)
	var frame_padding = 30
	var frame_rect = Rect2(
		grid_origin.x - TRACK_WIDTH - frame_padding,
		grid_origin.y - TRACK_WIDTH - frame_padding,
		grid_width + TRACK_WIDTH * 2 + frame_padding * 2,
		grid_height + TRACK_WIDTH * 2 + frame_padding * 2
	)
	draw_rect(frame_rect, Color(0.7, 0.7, 0.7))
	
	# Draw track (darker gray)
	var track_color = Color(0.4, 0.4, 0.4)
	draw_rect(Rect2(grid_origin.x - TRACK_WIDTH, grid_origin.y - TRACK_WIDTH, 
		grid_width + TRACK_WIDTH * 2, TRACK_WIDTH), track_color)
	draw_rect(Rect2(grid_origin.x - TRACK_WIDTH, grid_origin.y + grid_height,
		grid_width + TRACK_WIDTH * 2, TRACK_WIDTH), track_color)
	draw_rect(Rect2(grid_origin.x - TRACK_WIDTH, grid_origin.y,
		TRACK_WIDTH, grid_height), track_color)
	draw_rect(Rect2(grid_origin.x + grid_width, grid_origin.y,
		TRACK_WIDTH, grid_height), track_color)
	
	# Draw grid background (dark blue-ish like reference)
	draw_rect(Rect2(grid_origin, Vector2(grid_width, grid_height)), Color(0.15, 0.15, 0.25))
	
	# Draw train position (white circle)
	var train_pos = _get_train_world_position(train_position)
	draw_circle(train_pos, 10, Color.WHITE)
	draw_circle(train_pos, 6, Color(0.3, 0.3, 0.8))
	
	# Highlight pickup zone
	var cells = _get_train_adjacent_cells()
	for cell in cells:
		var world_pos = _grid_to_world(cell.y, cell.x)
		draw_rect(Rect2(world_pos - Vector2(CELL_SIZE/2, CELL_SIZE/2), 
			Vector2(CELL_SIZE, CELL_SIZE)), Color(1, 1, 1, 0.15))
