extends Node2D

@export_group("Building Spawning")
@export var building_scenes: Array[PackedScene] = []

@export_group("Spawning Area")
@export var start_x: float = 0.0
@export var end_x: float = 2000.0
@export var min_y: float = 300.0
@export var max_y: float = 600.0
@export var building_spacing: float = 400.0

var spawned_buildings: Array = []

func _ready() -> void:
	generate_buildings()

func generate_buildings() -> void:
	# Clear previously spawned buildings
	for building in spawned_buildings:
		building.queue_free()
	spawned_buildings.clear()

	# Spawn new buildings
	var current_x = start_x
	while current_x < end_x:
		# Choose a random building scene
		if building_scenes.size() == 0:
			push_warning("No building scenes defined in the building manager.")
			return
		var random_building_scene = building_scenes.pick_random()
		
		# Instantiate the building
		var building = random_building_scene.instantiate()
		
		# Set its position
		var random_y = randf_range(min_y, max_y)
		building.position = Vector2(current_x, random_y)
		
		# Add it to the scene
		add_child(building)
		spawned_buildings.append(building)
		
		# Move to the next position
		current_x += building_spacing