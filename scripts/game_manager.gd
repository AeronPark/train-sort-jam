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

# Train visual - multiple cars
const TRAIN_CAR_LENGTH := 24
const TRAIN_CAR_WIDTH := 14
const TRAIN_CAR_GAP := 4
const MAX_TRAIN_CARS := 6
var train_car_count := 3  # Engine + wagons

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
	_rebuild_track_path()
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
		btn.disabled = false  # Always enabled - can switch mid-run
		
		# Highlight active button
		if train_active and i == active_button_idx:
			var active_style = style.duplicate()
			active_style.border_width_left = 3
			active_style.border_width_right = 3
			active_style.border_width_top = 3
			active_style.border_width_bottom = 3
			active_style.border_color = Color.WHITE
			btn.add_theme_stylebox_override("normal", active_style)
		
		add_child(btn)
		button_nodes.append(btn)

func _on_button_pressed(idx: int) -> void:
	if buttons[idx] == null:
		return
	
	var btn = buttons[idx]
	
	# If train already active, switch color mid-run
	if train_active:
		# First, update the previous button with remaining capacity
		if active_button_idx >= 0 and active_button_idx != idx:
			var prev_btn = buttons[active_button_idx]
			if prev_btn:
				prev_btn.count -= train_collected
				if prev_btn.count <= 0:
					buttons[active_button_idx] = _make_random_button()
		
		# Switch to new color - keep train moving
		active_button_idx = idx
		train_color = btn.color
		train_remaining = btn.count
		train_collected = 0
		train_car_count = min(btn.count + 1, MAX_TRAIN_CARS)
		print("Switching to: %s x%d" % [train_color, train_remaining])
	else:
		# Start new train run
		active_button_idx = idx
		train_color = btn.color
		train_remaining = btn.count
		train_collected = 0
		train_position = 0.0
		train_active = true
		train_car_count = min(btn.count + 1, MAX_TRAIN_CARS)
		print("Train departing: %s x%d" % [train_color, train_remaining])
	
	_create_button_ui()  # Refresh button states

func _update_button_states() -> void:
	# Buttons always enabled - can switch mid-run
	for i in range(button_nodes.size()):
		if button_nodes[i]:
			button_nodes[i].disabled = false

# ============ TRACK & TRAIN ============

# Track path - array of world positions the train follows
var track_path: Array = []
var track_length := 0.0

func _rebuild_track_path() -> void:
	track_path.clear()
	track_length = 0.0
	
	# Build path clockwise from bottom-right, following edge contours
	# For each edge, check which cells have dots and route accordingly
	
	var offset = TRACK_WIDTH / 2 + CELL_SIZE / 2
	
	# Bottom edge (right to left)
	for col in range(bound_max_col, bound_min_col - 1, -1):
		var has_dot = grid[bound_max_row][col] != null
		var y = grid_origin.y + (bound_max_row + 1) * CELL_SIZE
		if has_dot:
			y += offset - CELL_SIZE / 2
		else:
			y -= CELL_SIZE / 2  # Indent for empty cells
		track_path.append(Vector2(grid_origin.x + col * CELL_SIZE + CELL_SIZE / 2, y))
	
	# Left edge (bottom to top)
	for row in range(bound_max_row, bound_min_row - 1, -1):
		var has_dot = grid[row][bound_min_col] != null
		var x = grid_origin.x + bound_min_col * CELL_SIZE
		if has_dot:
			x -= offset - CELL_SIZE / 2
		else:
			x += CELL_SIZE / 2  # Indent for empty cells
		track_path.append(Vector2(x, grid_origin.y + row * CELL_SIZE + CELL_SIZE / 2))
	
	# Top edge (left to right)
	for col in range(bound_min_col, bound_max_col + 1):
		var has_dot = grid[bound_min_row][col] != null
		var y = grid_origin.y + bound_min_row * CELL_SIZE
		if has_dot:
			y -= offset - CELL_SIZE / 2
		else:
			y += CELL_SIZE / 2  # Indent for empty cells
		track_path.append(Vector2(grid_origin.x + col * CELL_SIZE + CELL_SIZE / 2, y))
	
	# Right edge (top to bottom)
	for row in range(bound_min_row, bound_max_row + 1):
		var has_dot = grid[row][bound_max_col] != null
		var x = grid_origin.x + (bound_max_col + 1) * CELL_SIZE
		if has_dot:
			x += offset - CELL_SIZE / 2
		else:
			x -= CELL_SIZE / 2  # Indent for empty cells
		track_path.append(Vector2(x, grid_origin.y + row * CELL_SIZE + CELL_SIZE / 2))
	
	# Calculate total length
	for i in range(track_path.size()):
		var next_i = (i + 1) % track_path.size()
		track_length += track_path[i].distance_to(track_path[next_i])

func _get_track_perimeter() -> float:
	if track_length <= 0:
		_rebuild_track_path()
	return track_length

func _get_train_world_pos(t: float) -> Vector2:
	if track_path.is_empty():
		_rebuild_track_path()
	if track_path.is_empty():
		return Vector2.ZERO
	
	var target_dist = t * track_length
	var current_dist = 0.0
	
	for i in range(track_path.size()):
		var next_i = (i + 1) % track_path.size()
		var seg_len = track_path[i].distance_to(track_path[next_i])
		
		if current_dist + seg_len >= target_dist:
			var seg_t = (target_dist - current_dist) / seg_len if seg_len > 0 else 0
			return track_path[i].lerp(track_path[next_i], seg_t)
		
		current_dist += seg_len
	
	return track_path[0]

func _get_edge_cells_at_position(t: float) -> Array:
	var cells = []
	var pos = _get_train_world_pos(t)
	
	# Find nearest grid cell
	var col = int((pos.x - grid_origin.x) / CELL_SIZE)
	var row = int((pos.y - grid_origin.y) / CELL_SIZE)
	
	col = clamp(col, bound_min_col, bound_max_col)
	row = clamp(row, bound_min_row, bound_max_row)
	
	# Check if this cell is on the edge
	if row == bound_min_row or row == bound_max_row or col == bound_min_col or col == bound_max_col:
		cells.append(Vector2i(col, row))
	
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
	
	# Rebuild track to follow indented path
	_rebuild_track_path()

func _complete_run() -> void:
	# Update button for collected dots
	if active_button_idx >= 0:
		var btn = buttons[active_button_idx]
		if btn:
			btn.count -= train_collected
			if btn.count <= 0:
				buttons[active_button_idx] = _make_random_button()
	
	# Keep train running continuously - reset position for next loop
	train_position = 0.0
	train_collected = 0
	
	# Recalculate bounds
	_recalculate_bounds()
	
	# Update UI
	_create_button_ui()
	
	# Check win/lose
	if _check_win():
		train_active = false
		print("YOU WIN!")
	elif _check_lose():
		train_active = false
		print("GAME OVER!")
	else:
		# Update remaining from current button
		if active_button_idx >= 0 and buttons[active_button_idx]:
			train_remaining = buttons[active_button_idx].count

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
	
	# Rebuild track path for new bounds
	_rebuild_track_path()

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
	if track_path.is_empty():
		_rebuild_track_path()
	
	var track_color = Color(0.4, 0.4, 0.45)
	
	# Draw track path
	for i in range(track_path.size()):
		var next_i = (i + 1) % track_path.size()
		draw_line(track_path[i], track_path[next_i], track_color, 4.0)
	
	# Exit indicator at bottom-right
	if not track_path.is_empty():
		var exit_pos = track_path[0]
		draw_line(exit_pos, exit_pos + Vector2(30, 30), track_color, 4.0)

func _draw_train() -> void:
	if not train_active:
		return
	
	var perim = _get_track_perimeter()
	var car_spacing = (TRAIN_CAR_LENGTH + TRAIN_CAR_GAP) / perim
	
	# Draw each car from back to front
	for i in range(train_car_count - 1, -1, -1):
		var car_t = train_position - (i * car_spacing)
		if car_t < 0:
			car_t += 1.0  # Wrap around
		
		var pos = _get_train_world_pos(car_t)
		var next_t = car_t + 0.01
		if next_t > 1.0:
			next_t -= 1.0
		var next_pos = _get_train_world_pos(next_t)
		var direction = (next_pos - pos).normalized()
		var angle = direction.angle()
		
		_draw_train_car(pos, angle, i == 0)

func _draw_train_car(pos: Vector2, angle: float, is_engine: bool) -> void:
	var half_len = TRAIN_CAR_LENGTH / 2.0
	var half_wid = TRAIN_CAR_WIDTH / 2.0
	
	# Car body color
	var body_color = Color(0.85, 0.85, 0.85) if is_engine else Color(0.75, 0.75, 0.75)
	var outline_color = Color(0.4, 0.4, 0.4)
	
	# Calculate corners
	var dir = Vector2.from_angle(angle)
	var perp = Vector2.from_angle(angle + PI / 2)
	
	var corners = [
		pos + dir * half_len + perp * half_wid,
		pos + dir * half_len - perp * half_wid,
		pos - dir * half_len - perp * half_wid,
		pos - dir * half_len + perp * half_wid
	]
	
	# Draw car body
	draw_colored_polygon(corners, body_color)
	
	# Draw outline
	for j in range(4):
		draw_line(corners[j], corners[(j + 1) % 4], outline_color, 2.0)
	
	# Engine details
	if is_engine:
		# Cab window
		var window_color = Color(0.3, 0.5, 0.7)
		var win_offset = dir * (half_len * 0.3)
		draw_circle(pos + win_offset, 4, window_color)
		
		# Smokestack
		var stack_pos = pos + dir * (half_len * 0.7)
		draw_rect(Rect2(stack_pos - Vector2(3, 6), Vector2(6, 6)), Color(0.3, 0.3, 0.3))
	else:
		# Wagon - show collected dot color
		var wagon_color = COLOR_VALUES.get(train_color, Color.GRAY)
		draw_circle(pos, 5, wagon_color)
