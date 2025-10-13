extends Node2D

# Preload building scenes
var building_1_scene = preload("res://scenes/building_1.tscn")  # Player's building
var building_scenes = [
	preload("res://scenes/building_2.tscn"),  # Goal building options
	preload("res://scenes/building_3.tscn"),
	preload("res://scenes/building_4.tscn")
]

@export_group("Level Generation")
@export var min_player_height: float = -300.0  # How high player building can go
@export var max_player_height: float = -100.0  # How low player building can go
@export var min_target_x: float = 500.0  # Minimum horizontal distance for target building
@export var max_target_x: float = 900.0  # Maximum horizontal distance for target building
@export var target_height_min: float = -300.0  # Target building height range
@export var target_height_max: float = -50.0

var player_building: Node2D
var target_building: Node2D
var ball_spawn_marker: Marker2D

func _ready() -> void:
	# Generate level on ready
	generate_level()

func generate_level():
	# Clear existing buildings if any
	clear_buildings()
	
	# Create player's building (building_1) - only varies in height
	player_building = building_1_scene.instantiate()
	add_child(player_building)
	
	# Randomize player building height (Y position only)
	var player_y = randf_range(min_player_height, max_player_height)
	player_building.position = Vector2(0, player_y)  # X stays at 0
	
	# Find the spawn marker in the player building
	ball_spawn_marker = player_building.get_node_or_null("spawn_marker")
	if not ball_spawn_marker:
		push_warning("No spawn_marker found in building_1! Add a Marker2D named 'spawn_marker'")
	
	print("Player building spawned at: ", player_building.position)
	
	# Create target building (random from building_2, 3, or 4)
	var random_building_scene = building_scenes[randi() % building_scenes.size()]
	target_building = random_building_scene.instantiate()
	add_child(target_building)
	
	# Randomize target building position (both X and Y)
	var target_x = randf_range(min_target_x, max_target_x)
	var target_y = randf_range(target_height_min, target_height_max)
	target_building.position = Vector2(target_x, target_y)
	
	print("Target building spawned at: ", target_building.position)

func clear_buildings():
	# Remove existing buildings
	if player_building:
		player_building.queue_free()
		player_building = null
	
	if target_building:
		target_building.queue_free()
		target_building = null

func regenerate_level():
	# Public function to regenerate the level
	generate_level()

func get_player_building_position() -> Vector2:
	if player_building:
		return player_building.position
	return Vector2.ZERO

func get_target_building_position() -> Vector2:
	if target_building:
		return target_building.position
	return Vector2.ZERO

func get_ball_spawn_position() -> Vector2:
	# Returns the global position of the spawn marker
	if ball_spawn_marker:
		return ball_spawn_marker.global_position
	elif player_building:
		# Fallback to player building position if no marker
		return player_building.global_position
	return Vector2.ZERO

func get_spawn_marker() -> Marker2D:
	# Returns the spawn marker node for level_manager to use
	return ball_spawn_marker

func get_goal_node() -> Node2D:
	# Find and return the goal node from the target building
	if target_building:
		var goal = target_building.get_node_or_null("goal")
		if not goal:
			push_warning("No goal node found in target building!")
		return goal
	return null