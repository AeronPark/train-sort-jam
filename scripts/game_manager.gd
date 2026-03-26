extends Node2D

# Grid settings - Portrait orientation
const GRID_COLS := 16
const GRID_ROWS := 21
const CELL_SIZE := 22
const GRID_MARGIN := 10

# Colors
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
const TRAIN_SPEED := 200.0

# Game state
var grid: Array = []  # 2D array of passenger colors (or null)

# Dynamic conveyor bounds (in grid coordinates)
var conveyor_min_row := 0
var conveyor_max_row := GRID_ROWS - 1
var conveyor_min_col := 0
var conveyor_max_col := GRID_COLS - 1

# Train state
var train_active := false
var train_position := 0.0  # 0.0 to 1.0 around current conveyor
var train_color: String = ""
var train_capacity := 0  # How many left to pick up this run
var train_collected := 0  # How many picked up this run
var active_button: Dictionary = {}  # The button being used

# Button inventory system
var button_inventory: Array = []  # Array of {color, count}
const MAX_BUTTONS := 6
const BUTTON_SIZE := 65
const BUTTON_SPACING := 12

# UI references
var grid_origin: Vector2
var passenger_sprites: Array = []
var button_nodes: Array = []  # Button UI nodes

# Signals
signal level_complete
signal level_failed

func _ready() -> void:
	var viewport_size = get_viewport_rect().size
	
	# Grid position - centered, top area
	var grid_width = GRID_COLS * CELL_SIZE
	var grid_height = GRID_ROWS * CELL_SIZE
	grid_origin = Vector2(
		(viewport_size.x - grid_width) / 2,
		TRACK_WIDTH + GRID_MARGIN + 40
	)
	
	_init_grid()
	_create_passengers()
	_deal_initial_buttons()
	_update_button_ui()
	
	queue_redraw()

func _init_grid() -> void:
	grid.clear()
	
	# Create color bands
	for row in range(GRID_ROWS):
		var grid_row = []
		var band_color: String
		
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
			if randf() < 0.15:
				var adjacent = _get_adjacent_band_colors(band_color)
				grid_row.append(adjacent[randi() % adjacent.size()])
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

# ============ BUTTON INVENTORY SYSTEM ============

func _deal_initial_buttons() -> void:
	button_inventory.clear()
	for i in range(MAX_BUTTONS):
		_deal_one_button()

func _deal_one_button() -> void:
	if button_inventory.size() >= MAX_BUTTONS:
		return
	
	# Random color and number 1-5
	var color = COLORS[randi() % COLORS.size()]
	var count = (randi() % 5) + 1  # 1 to 5
	button_inventory.append({"color": color, "count": count})

func _update_button_ui() -> void:
	# Clear old buttons
	for btn in button_nodes:
		btn.queue_free()
	button_nodes.clear()
	
	var viewport_size = get_viewport_rect().size
	var total_width = button_inventory.size() * BUTTON_SIZE + (button_inventory.size() - 1) * BUTTON_SPACING
	var start_x = (viewport_size.x - total_width) / 2
	var button_y = viewport_size.y - BUTTON_SIZE - 30
	
	for i in range(button_inventory.size()):
		var btn_data = button_inventory[i]
		var btn = Button.new()
		btn.text = str(btn_data.count)
		btn.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
		btn.position = Vector2(start_x + i * (BUTTON_SIZE + BUTTON_SPACING), button_y)
		
		# Style with color
		var style = StyleBoxFlat.new()
		style.bg_color = COLOR_VALUES[btn_data.color]
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		
		var hover_style = style.duplicate()
		hover_style.bg_color = COLOR_VALUES[btn_data.color].lightened(0.2)
		
		var disabled_style = style.duplicate()
		disabled_style.bg_color = COLOR_VALUES[btn_data.color].darkened(0.4)
		
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_stylebox_override("disabled", disabled_style)
		
		# Text color
		if btn_data.color in ["yellow", "cyan", "pink"]:
			btn.add_theme_color_override("font_color", Color.BLACK)
		else:
			btn.add_theme_color_override("font_color", Color.WHITE)
		
		btn.add_theme_font_size_override("font_size", 32)
		btn.pressed.connect(_on_button_pressed.bind(i))
		
		# Disable if train is active
		btn.disabled = train_active
		
		add_child(btn)
		button_nodes.append(btn)

func _on_button_pressed(index: int) -> void:
	if train_active:
		return
	
	var btn_data = button_inventory[index]
	active_button = {"index": index, "color": btn_data.color, "count": btn_data.count}
	train_color = btn_data.color
	train_capacity = btn_data.count
	train_collected = 0
	train_position = 0.0
	train_active = true
	
	_update_button_ui()
	print("Train departing! Color: %s, Capacity: %d" % [train_color, train_capacity])

# ============ CONVEYOR PATH ============

func _recalculate_conveyor_bounds() -> void:
	# Find the bounding box of all remaining passengers
	var min_row = GRID_ROWS
	var max_row = -1
	var min_col = GRID_COLS
	var max_col = -1
	
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			if grid[row][col] != null:
				min_row = min(min_row, row)
				max_row = max(max_row, row)
				min_col = min(min_col, col)
				max_col = max(max_col, col)
	
	# Update conveyor bounds (keep valid if no passengers)
	if max_row >= 0:
		conveyor_min_row = min_row
		conveyor_max_row = max_row
		conveyor_min_col = min_col
		conveyor_max_col = max_col
		print("Conveyor reshaped: rows %d-%d, cols %d-%d" % [min_row, max_row, min_col, max_col])

func _get_conveyor_bounds() -> Dictionary:
	# Convert grid coordinates to world coordinates
	var left = grid_origin.x + conveyor_min_col * CELL_SIZE
	var right = grid_origin.x + (conveyor_max_col + 1) * CELL_SIZE
	var top = grid_origin.y + conveyor_min_row * CELL_SIZE
	var bottom = grid_origin.y + (conveyor_max_row + 1) * CELL_SIZE
	
	return {"left": left, "right": right, "top": top, "bottom": bottom}

func _get_conveyor_perimeter() -> float:
	var bounds = _get_conveyor_bounds()
	var width = bounds.right - bounds.left
	var height = bounds.bottom - bounds.top
	return 2 * width + 2 * height + 4 * TRACK_WIDTH

func _get_train_world_position(t: float) -> Vector2:
	var bounds = _get_conveyor_bounds()
	var track_offset = TRACK_WIDTH / 2
	
	var left = bounds.left - track_offset
	var right = bounds.right + track_offset
	var top = bounds.top - track_offset
	var bottom = bounds.bottom + track_offset
	
	var width = right - left
	var height = bottom - top
	var perimeter = 2 * width + 2 * height
	var pos_along = t * perimeter
	
	# Top edge (left to right)
	if pos_along < width:
		return Vector2(left + pos_along, top)
	pos_along -= width
	
	# Right edge (top to bottom)
	if pos_along < height:
		return Vector2(right, top + pos_along)
	pos_along -= height
	
	# Bottom edge (right to left)
	if pos_along < width:
		return Vector2(right - pos_along, bottom)
	pos_along -= width
	
	# Left edge (bottom to top)
	return Vector2(left, bottom - pos_along)

func _get_cells_at_train_position() -> Array:
	var cells = []
	var train_world = _get_train_world_position(train_position)
	var bounds = _get_conveyor_bounds()
	
	# Determine which edge we're on and get adjacent cells
	var edge_threshold = TRACK_WIDTH + 5
	
	# Check each edge - using conveyor grid bounds directly
	if abs(train_world.y - (bounds.top - TRACK_WIDTH/2)) < edge_threshold:
		# Top edge - row = conveyor_min_row
		var col = int((train_world.x - grid_origin.x) / CELL_SIZE)
		col = clamp(col, conveyor_min_col, conveyor_max_col)
		for c in range(max(conveyor_min_col, col - 1), min(conveyor_max_col + 1, col + 2)):
			cells.append(Vector2i(c, conveyor_min_row))
	
	elif abs(train_world.x - (bounds.right + TRACK_WIDTH/2)) < edge_threshold:
		# Right edge - col = conveyor_max_col
		var row = int((train_world.y - grid_origin.y) / CELL_SIZE)
		row = clamp(row, conveyor_min_row, conveyor_max_row)
		for r in range(max(conveyor_min_row, row - 1), min(conveyor_max_row + 1, row + 2)):
			cells.append(Vector2i(conveyor_max_col, r))
	
	elif abs(train_world.y - (bounds.bottom + TRACK_WIDTH/2)) < edge_threshold:
		# Bottom edge - row = conveyor_max_row
		var col = int((train_world.x - grid_origin.x) / CELL_SIZE)
		col = clamp(col, conveyor_min_col, conveyor_max_col)
		for c in range(max(conveyor_min_col, col - 1), min(conveyor_max_col + 1, col + 2)):
			cells.append(Vector2i(c, conveyor_max_row))
	
	elif abs(train_world.x - (bounds.left - TRACK_WIDTH/2)) < edge_threshold:
		# Left edge - col = conveyor_min_col
		var row = int((train_world.y - grid_origin.y) / CELL_SIZE)
		row = clamp(row, conveyor_min_row, conveyor_max_row)
		for r in range(max(conveyor_min_row, row - 1), min(conveyor_max_row + 1, row + 2)):
			cells.append(Vector2i(conveyor_min_col, r))
	
	return cells

# ============ TRAIN LOGIC ============

func _process(delta: float) -> void:
	if train_active:
		_update_train(delta)
	
	queue_redraw()

func _update_train(delta: float) -> void:
	var perimeter = _get_conveyor_perimeter()
	var move_amount = (TRAIN_SPEED * delta) / perimeter
	train_position += move_amount
	
	# Collect passengers as we pass
	if train_capacity > 0:
		_try_collect_passengers()
	
	# Check if train completed the loop
	if train_position >= 1.0:
		_complete_train_run()

func _try_collect_passengers() -> void:
	var cells = _get_cells_at_train_position()
	
	for cell in cells:
		if train_collected >= active_button.count:
			break
			
		var row = cell.y
		var col = cell.x
		
		if row >= 0 and row < GRID_ROWS and col >= 0 and col < GRID_COLS:
			if grid[row][col] == train_color:
				_collect_passenger(row, col)

func _collect_passenger(row: int, col: int) -> void:
	grid[row][col] = null
	train_collected += 1
	train_capacity -= 1
	
	# Animate passenger collection
	if passenger_sprites[row][col]:
		var sprite = passenger_sprites[row][col]
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2.ZERO, 0.2)
		tween.tween_callback(sprite.queue_free)
		passenger_sprites[row][col] = null
	
	print("Collected! Total: %d" % train_collected)

func _complete_train_run() -> void:
	train_active = false
	train_position = 0.0
	
	# Update button inventory
	var btn_index = active_button.index
	var remaining = active_button.count - train_collected
	
	if remaining <= 0:
		# Button fully used - discard it
		button_inventory.remove_at(btn_index)
		print("Button discarded!")
	else:
		# Update button with remaining count
		button_inventory[btn_index].count = remaining
		print("Button updated: %d remaining" % remaining)
	
	# Deal new button if we have room
	if button_inventory.size() < MAX_BUTTONS:
		_deal_one_button()
	
	# Shrink conveyor for next run
	_shrink_conveyor()
	
	# Check win/lose conditions
	if _check_win():
		print("LEVEL COMPLETE!")
		emit_signal("level_complete")
	elif _check_lose():
		print("LEVEL FAILED!")
		emit_signal("level_failed")
	
	_update_button_ui()
	active_button = {}

func _shrink_conveyor() -> void:
	# Recalculate bounds to fit exactly around remaining passengers
	_recalculate_conveyor_bounds()

func _check_win() -> bool:
	# Win if no passengers left
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			if grid[row][col] != null:
				return false
	return true

func _check_lose() -> bool:
	# Lose if no passengers are reachable by current conveyor
	var reachable = _get_reachable_colors()
	if reachable.is_empty():
		return true
	
	# Also lose if no buttons can pick up any reachable colors
	for btn in button_inventory:
		if btn.color in reachable:
			return false
	
	return true

func _get_reachable_colors() -> Dictionary:
	var colors = {}
	
	# Check all edge cells of current conveyor bounds
	# Top edge
	for col in range(conveyor_min_col, conveyor_max_col + 1):
		var c = grid[conveyor_min_row][col]
		if c: colors[c] = colors.get(c, 0) + 1
	
	# Bottom edge
	for col in range(conveyor_min_col, conveyor_max_col + 1):
		var c = grid[conveyor_max_row][col]
		if c: colors[c] = colors.get(c, 0) + 1
	
	# Left edge (excluding corners already counted)
	for row in range(conveyor_min_row + 1, conveyor_max_row):
		var c = grid[row][conveyor_min_col]
		if c: colors[c] = colors.get(c, 0) + 1
	
	# Right edge (excluding corners already counted)
	for row in range(conveyor_min_row + 1, conveyor_max_row):
		var c = grid[row][conveyor_max_col]
		if c: colors[c] = colors.get(c, 0) + 1
	
	return colors

# ============ DRAWING ============

func _draw() -> void:
	_draw_background()
	_draw_conveyor()
	_draw_train()
	_draw_ui()

func _draw_background() -> void:
	var viewport_size = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.1, 0.1, 0.15))

func _draw_conveyor() -> void:
	var bounds = _get_conveyor_bounds()
	var track_offset = TRACK_WIDTH / 2
	
	# Draw track
	var track_color = Color(0.35, 0.35, 0.4)
	var inner_color = Color(0.15, 0.15, 0.2)
	
	# Outer track rectangle
	var outer_rect = Rect2(
		bounds.left - TRACK_WIDTH,
		bounds.top - TRACK_WIDTH,
		(bounds.right - bounds.left) + TRACK_WIDTH * 2,
		(bounds.bottom - bounds.top) + TRACK_WIDTH * 2
	)
	draw_rect(outer_rect, track_color)
	
	# Inner area (grid background)
	var inner_rect = Rect2(
		bounds.left,
		bounds.top,
		bounds.right - bounds.left,
		bounds.bottom - bounds.top
	)
	draw_rect(inner_rect, inner_color)
	
	# Draw grid lines (subtle)
	var line_color = Color(0.2, 0.2, 0.25)
	for row in range(GRID_ROWS + 1):
		var y = grid_origin.y + row * CELL_SIZE
		draw_line(Vector2(grid_origin.x, y), Vector2(grid_origin.x + GRID_COLS * CELL_SIZE, y), line_color, 1)
	for col in range(GRID_COLS + 1):
		var x = grid_origin.x + col * CELL_SIZE
		draw_line(Vector2(x, grid_origin.y), Vector2(x, grid_origin.y + GRID_ROWS * CELL_SIZE), line_color, 1)

func _draw_train() -> void:
	if not train_active:
		return
	
	var pos = _get_train_world_position(train_position)
	
	# Train body
	draw_circle(pos, 14, Color.WHITE)
	draw_circle(pos, 10, COLOR_VALUES.get(train_color, Color.GRAY))
	
	# Capacity indicator
	var label = str(train_capacity)
	# Note: Can't easily draw text in _draw, would need Label node

func _draw_ui() -> void:
	var font = ThemeDB.fallback_font
	
	# Draw remaining passenger count
	var remaining = _count_remaining_passengers()
	var text = "Remaining: %d" % remaining
	draw_string(font, Vector2(20, 30), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	
	# Draw collected count if train active
	if train_active:
		var collected_text = "Collecting: %d/%d %s" % [train_collected, active_button.count, train_color]
		draw_string(font, Vector2(20, 55), collected_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, COLOR_VALUES.get(train_color, Color.WHITE))

func _count_remaining_passengers() -> int:
	var count = 0
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			if grid[row][col] != null:
				count += 1
	return count
