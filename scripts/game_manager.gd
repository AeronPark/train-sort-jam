extends Node2D

@export var board_distance: float = 100.0  # Max distance to board

var wagons: Array = []
var passengers: Array = []

func _ready() -> void:
	# Find all wagons
	var train = get_node_or_null("ConveyorPath/TrainFollow/Train")
	if train:
		for child in train.get_children():
			if child.has_method("can_board"):
				wagons.append(child)
	
	# Find all passengers and connect signals
	var grid = get_node_or_null("Grid")
	if grid:
		for child in grid.get_children():
			if child.has_signal("clicked"):
				passengers.append(child)
				child.clicked.connect(_on_passenger_clicked)
	
	print("Game ready: %d wagons, %d passengers" % [wagons.size(), passengers.size()])

func _on_passenger_clicked(passenger) -> void:
	var passenger_color: int = passenger.color_index
	
	# Find the matching wagon
	var target_wagon = null
	for w in wagons:
		if w.color_index == passenger_color:
			target_wagon = w
			break
	
	if not target_wagon:
		print("No wagon for color %d" % passenger_color)
		return
	
	# Check if wagon is close enough (use train follow position)
	var train_follow = get_node("ConveyorPath/TrainFollow")
	var wagon_global_pos: Vector2 = train_follow.global_position
	var passenger_global_pos: Vector2 = passenger.global_position
	var distance: float = wagon_global_pos.distance_to(passenger_global_pos)
	
	if distance > board_distance:
		print("Wagon too far: %.0f > %.0f" % [distance, board_distance])
		# Flash the passenger red
		flash_passenger(passenger, Color.RED)
		return
	
	# Try to board
	if target_wagon.board_passenger(passenger):
		passengers.erase(passenger)
		print("Boarded! Wagon %d now has %d/%d" % [target_wagon.color_index, target_wagon.get_passenger_count(), target_wagon.capacity])
	else:
		print("Wagon full!")
		flash_passenger(passenger, Color.RED)

func flash_passenger(passenger, flash_color: Color) -> void:
	var visual = passenger.get_node_or_null("Visual")
	if visual:
		var original_color: Color = visual.color
		visual.color = flash_color
		await get_tree().create_timer(0.15).timeout
		if is_instance_valid(visual):
			visual.color = original_color

func get_score() -> int:
	var total := 0
	for w in wagons:
		total += w.get_passenger_count()
	return total
