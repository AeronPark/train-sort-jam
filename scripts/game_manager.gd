extends Node2D

# Grid settings
const GRID_COLS := 12
const GRID_ROWS := 16
const CELL_SIZE := 28
const DOT_RADIUS := 10

# Colors - matching reference
const COLORS := ["magenta", "red", "purple", "green", "yellow"]
const COLOR_VALUES := {
	"magenta": Color(0.95, 0.4, 0.7),
	"red": Color(0.9, 0.25, 0.25),
	"purple": Color(0.6, 0.35, 0.75),
	"green": Color(0.35, 0.75, 0.35),
	"yellow": Color(0.95, 0.85, 0.3)
}

# Track settings
const TRACK_WIDTH := 20
const TRAIN_SPEED := 300.0

# Game state
var grid: Array = []  # 2D array of dot colors (or null)
var dots: Array = []  # 2D array of dot sprites

# Dynamic bounds (grid coordinates of remaining dots)
var bound_min_row := 0
var bound_max_row := GRID_ROWS - 1
var bound_min_col := 0
var bound_max_col := GRID_COLS - 1

# Train state
var train_active := false
var train_position := 0.0  # 0.0 to 1.0 around track
var train_color: String = ""
var train_remaining := 0  # How many more to pick up
var train_collected := 0
var active_button_idx := -1

# Button inventory - 3x3 grid
var buttons: Array = []  # Array of {color, count} or null
const BUTTON_ROWS := 3
const BUTTON_COLS := 3
const BUTTON_SIZE := 55
const BUTTON_SPACING := 8

# UI
var grid_origin: Vector2
var button_nodes: Array = []

func _ready() -> void:
	randomize()
	var viewport_size = get_viewport_rect().size
	
	# Center the grid
	var grid_width = GRID_COLS * CELL_SIZE
	var grid_height = GRID_ROWS * CELL_SIZE
	grid_origin = Vector2(
		(viewport_size.x - grid_width) / 2,
		60
	)
	
	_init_grid()
	_create_dots()
	_deal_buttons()
	_create_button_ui()
	
	queue_redraw()

func _init_grid() -> void:
	grid.clear()
	
	# Create color bands like reference
	for row in range(GRID_ROWS):
		var grid_row = []
		var band_color: String
		
		# Assign colors by row bands
		if row < 3:
			band_color = "magenta"
		elif row < 6:
			band_color = "red"
		elif row < 9:
			band_color = "purple"
		elif row < 12:
			band_color = "green"
		else:
			band_color = "yellow"
		
		for col in range(GRID_COLS):
			# Some mixing within bands
			if randf() < 0.1:
				band_color = COLORS[randi() % COLORS.size()]
			grid_row.append(band_color)
		grid.append(grid_row)

func _create_dots() -> void:
	# Clear old dots
	for row in dots:
		for dot in row:
			if dot:
				dot.queue_free()
	dots.clear()
	
	for row in range(GRID_ROWS):
		var dot_row = []
		for col in range(GRID_COLS):
			var color = grid[row][col]
			if color:
				var dot = _create_dot(row, col, color)
				dot_row.append(dot)
			else:
				dot_row.append(null)
		dots.append(dot_row)

func _create_dot(row: int, col: int, color: String) -> Node2D:
	var dot = Node2D.new()
	dot.set_script(preload("res://scripts/dot_visual.gd"))
	dot.position = _grid_to_world(row, col)
	dot.set_meta("color", color)
	dot.set_meta("color_value", COLOR_VALUES[color])
	dot.set_meta("radius", DOT_RADIUS)
	add_child(dot)
	return dot

func _grid_to_world(row: int, col: int) -> Vector2:
	return grid_origin + Vector2(col * CELL_SIZE + CELL_SIZE / 2, row * CELL_SIZE + CELL_SIZE / 2)

# ============ BUTTON SYSTEM ============

func _deal_buttons() -> void:
	buttons.clear()
	for i in range(BUTTON_ROWS * BUTTON_COLS):
		buttons.append(_make_random_button())

func _make_random_button() -> Dictionary:
	var color = COLORS[randi() % COLORS.size()]
	var count = (randi() % 5) + 2  # 2 to 6
	return {"color": color, "count": count}

func _create_button_ui() -> void:
	# Clear old buttons
	for btn in button_nodes:
		if btn:
			btn.queue_free()
	button_nodes.clear()
	
	var viewport_size = get_viewport_rect().size
	var grid_height = GRID_ROWS * CELL_SIZE
	var button_area_top = grid_origin.y + grid_height + TRACK_WIDTH + 40
	
	var total_width = BUTTON_COLS * BUTTON_SIZE + (BUTTON_COLS - 1) * BUTTON_SPACING
	var start_x = (viewport_size.x - total_width) / 2
	
	for i in range(buttons.size()):
		var btn_data = buttons[i]
		if btn_data == null:
			button_nodes.append(null)
			continue
		
		var row = i / BUTTON_COLS
		var col = i % BUTTON_COLS
		
		var btn = Button.new()
		btn.text = str(btn_data.count)
		btn.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
		btn.position = Vector2(
			start_x + col * (BUTTON_SIZE + BUTTON_SPACING),
			button_area_top + row * (BUTTON_SIZE + BUTTON_SPACING)
		)
		
		# Style
		var style = StyleBoxFlat.new()
		style.bg_color = COLOR_VALUES[btn_data.color]
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		
		var hover = style.duplicate()
		hover.bg_color = COLOR_VALUES[btn_data.color].lightened(0.15)
		
		var disabled = style.duplicate()
		disabled.bg_color = COLOR_VALUES[btn_data.color].darkened(0.3)
		
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_stylebox_override("disabled", disabled)
		
		# Text color
		if btn_data.color in ["yellow", "green"]:
			btn.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
		else:
			btn.add_theme_color_override("font_color", Color.WHITE)
		
		btn.add_theme_font_size_override("font_size", 28)
		btn.pressed.connect(_on_button_pressed.bind(i))
		btn.disabled = train_active
		
		add_child(btn)
		button_nodes.append(btn)

func _on_button_pressed(idx: int) -> void:
	if train_active or buttons[idx] == null:
		return
	
	var btn = buttons[idx]
	active_button_idx = idx
	train_color = btn.color
	train_remaining = btn.count
	train_collected = 0
	train_position = 0.0
	train_active = true
	
	_update_button_states()
	print("Train departing: %s x%d" % [train_color, train_remaining])

func _update_button_states() -> void:
	for i in range(button_nodes.size()):
		if button_nodes[i]:
			button_nodes[i].disabled = train_active

# ============ TRACK & TRAIN ============

func _get_track_rect() -> Rect2:
	# Track hugs the current dot bounds
	var left = grid_origin.x + bound_min_col * CELL_SIZE - TRACK_WIDTH / 2
	var top = grid_origin.y + bound_min_row * CELL_SIZE - TRACK_WIDTH / 2
	var right = grid_origin.x + (bound_max_col + 1) * CELL_SIZE + TRACK_WIDTH / 2
	var bottom = grid_origin.y + (bound_max_row + 1) * CELL_SIZE + TRACK_WIDTH / 2
	return Rect2(left, top, right - left, bottom - top)

func _get_track_perimeter() -> float:
	var rect = _get_track_rect()
	return 2 * rect.size.x + 2 * rect.size.y

func _get_train_world_pos(t: float) -> Vector2:
	var rect = _get_track_rect()
	var perim = _get_track_perimeter()
	var dist = t * perim
	
	# Start at bottom-right, go clockwise
	# Bottom edge (right to left)
	var bottom_len = rect.size.x
	if dist < bottom_len:
		return Vector2(rect.position.x + rect.size.x - dist, rect.position.y + rect.size.y)
	dist -= bottom_len
	
	# Left edge (bottom to top)
	var left_len = rect.size.y
	if dist < left_len:
		return Vector2(rect.position.x, rect.position.y + rect.size.y - dist)
	dist -= left_len
	
	# Top edge (left to right)
	var top_len = rect.size.x
	if dist < top_len:
		return Vector2(rect.position.x + dist, rect.position.y)
	dist -= top_len
	
	# Right edge (top to bottom) - back to start
	return Vector2(rect.position.x + rect.size.x, rect.position.y + dist)

func _get_edge_cells_at_position(t: float) -> Array:
	var cells = []
	var pos = _get_train_world_pos(t)
	var rect = _get_track_rect()
	var perim = _get_track_perimeter()
	var dist = t * perim
	
	var bottom_len = rect.size.x
	var left_len = rect.size.y
	var top_len = rect.size.x
	
	# Determine which edge and get cells
	if dist < bottom_len:
		# Bottom edge - row = bound_max_row
		var col = int((pos.x - grid_origin.x) / CELL_SIZE)
		col = clamp(col, bound_min_col, bound_max_col)
		cells.append(Vector2i(col, bound_max_row))
	elif dist < bottom_len + left_len:
		# Left edge - col = bound_min_col
		var row = int((pos.y - grid_origin.y) / CELL_SIZE)
		row = clamp(row, bound_min_row, bound_max_row)
		cells.append(Vector2i(bound_min_col, row))
	elif dist < bottom_len + left_len + top_len:
		# Top edge - row = bound_min_row
		var col = int((pos.x - grid_origin.x) / CELL_SIZE)
		col = clamp(col, bound_min_col, bound_max_col)
		cells.append(Vector2i(col, bound_min_row))
	else:
		# Right edge - col = bound_max_col
		var row = int((pos.y - grid_origin.y) / CELL_SIZE)
		row = clamp(row, bound_min_row, bound_max_row)
		cells.append(Vector2i(bound_max_col, row))
	
	return cells

# ============ GAME LOOP ============

func _process(delta: float) -> void:
	if train_active:
		_update_train(delta)
	queue_redraw()

func _update_train(delta: float) -> void:
	var perim = _get_track_perimeter()
	var move = (TRAIN_SPEED * delta) / perim
	train_position += move
	
	# Try to collect dots
	if train_remaining > 0:
		var cells = _get_edge_cells_at_position(train_position)
		for cell in cells:
			if train_remaining <= 0:
				break
			var col = cell.x
			var row = cell.y
			if row >= 0 and row < GRID_ROWS and col >= 0 and col < GRID_COLS:
				if grid[row][col] == train_color:
					_collect_dot(row, col)
	
	# Check if train completed loop
	if train_position >= 1.0:
		_complete_run()

func _collect_dot(row: int, col: int) -> void:
	grid[row][col] = null
	train_collected += 1
	train_remaining -= 1
	
	# Animate dot
	if dots[row][col]:
		var dot = dots[row][col]
		var tween = create_tween()
		tween.tween_property(dot, "scale", Vector2.ZERO, 0.15)
		tween.tween_callback(dot.queue_free)
		dots[row][col] = null

func _complete_run() -> void:
	train_active = false
	train_position = 0.0
	
	# Update button
	var picked = train_collected
	var btn = buttons[active_button_idx]
	btn.count -= picked
	
	if btn.count <= 0:
		# Discard and deal new
		buttons[active_button_idx] = _make_random_button()
	
	# Recalculate bounds
	_recalculate_bounds()
	
	# Update UI
	_create_button_ui()
	
	# Check win/lose
	if _check_win():
		print("YOU WIN!")
	elif _check_lose():
		print("GAME OVER!")

func _recalculate_bounds() -> void:
	var min_r = GRID_ROWS
	var max_r = -1
	var min_c = GRID_COLS
	var max_c = -1
	
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			if grid[row][col] != null:
				min_r = min(min_r, row)
				max_r = max(max_r, row)
				min_c = min(min_c, col)
				max_c = max(max_c, col)
	
	if max_r >= 0:
		bound_min_row = min_r
		bound_max_row = max_r
		bound_min_col = min_c
		bound_max_col = max_c

func _check_win() -> bool:
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			if grid[row][col] != null:
				return false
	return true

func _check_lose() -> bool:
	# Get colors on current edge
	var edge_colors = {}
	
	# Top edge
	for col in range(bound_min_col, bound_max_col + 1):
		var c = grid[bound_min_row][col]
		if c:
			edge_colors[c] = true
	# Bottom edge
	for col in range(bound_min_col, bound_max_col + 1):
		var c = grid[bound_max_row][col]
		if c:
			edge_colors[c] = true
	# Left edge
	for row in range(bound_min_row + 1, bound_max_row):
		var c = grid[row][bound_min_col]
		if c:
			edge_colors[c] = true
	# Right edge
	for row in range(bound_min_row + 1, bound_max_row):
		var c = grid[row][bound_max_col]
		if c:
			edge_colors[c] = true
	
	if edge_colors.is_empty():
		return false  # No dots = win, not lose
	
	# Check if any button can pick up edge colors
	for btn in buttons:
		if btn and btn.color in edge_colors:
			return false
	
	return true

# ============ DRAWING ============

func _draw() -> void:
	_draw_background()
	_draw_track()
	_draw_train()

func _draw_background() -> void:
	var viewport = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, viewport), Color(0.15, 0.15, 0.18))
	
	# Grid background
	var grid_rect = Rect2(
		grid_origin - Vector2(5, 5),
		Vector2(GRID_COLS * CELL_SIZE + 10, GRID_ROWS * CELL_SIZE + 10)
	)
	draw_rect(grid_rect, Color(0.2, 0.2, 0.25))

func _draw_track() -> void:
	var rect = _get_track_rect()
	
	# Track outline
	var track_color = Color(0.4, 0.4, 0.45)
	draw_rect(rect, track_color, false, 4.0)
	
	# Exit indicator at bottom-right
	var exit_pos = Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y)
	draw_line(exit_pos, exit_pos + Vector2(30, 30), track_color, 4.0)

func _draw_train() -> void:
	if not train_active:
		return
	
	var pos = _get_train_world_pos(train_position)
	
	# Train body
	draw_circle(pos, 12, Color.WHITE)
	draw_circle(pos, 8, COLOR_VALUES.get(train_color, Color.GRAY))
	
	# Remaining count
	var font = ThemeDB.fallback_font
	var text = str(train_remaining)
	draw_string(font, pos + Vector2(-5, 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
