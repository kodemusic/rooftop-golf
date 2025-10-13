extends Node

# Autoload singleton to manage game state across scenes

var current_world: int = 1
var current_level: int = 1
var total_score: int = 0
var levels_per_world: int = 5

func reset_progress():
	current_world = 1
	current_level = 1
	total_score = 0
	print("Game progress reset")

func next_level():
	current_level += 1
	
	# Check if we've completed all levels in this world
	if current_level > levels_per_world:
		current_level = 1
		current_world += 1
		print("Advanced to World ", current_world)
	
	print("Current progress: World ", current_world, " - Level ", current_level)

func get_current_level_path() -> String:
	return "res://scenes/level_%d-%d.tscn" % [current_world, current_level]

func load_current_level():
	var level_path = get_current_level_path()
	print("Loading level: ", level_path)
	
	if ResourceLoader.exists(level_path):
		get_tree().change_scene_to_file(level_path)
	else:
		push_error("Level not found: " + level_path)
		# Try to go back to 1-1
		current_world = 1
		current_level = 1
		level_path = get_current_level_path()
		if ResourceLoader.exists(level_path):
			get_tree().change_scene_to_file(level_path)
		else:
			push_error("Could not find level_1-1.tscn!")

func add_score(points: int):
	total_score += points
	print("Score: ", total_score)
