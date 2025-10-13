extends Node2D

# Level manager handles spawn points and ball positioning
@export var spawn_point: Marker2D
@export var ball: CharacterBody2D

var spawn_position: Vector2

func _ready() -> void:
	# Find spawn point if not manually assigned
	if not spawn_point:
		# Try to find a spawn_marker in the player building
		var player = get_parent().find_child("player", true, false)
		if player:
			spawn_point = player.get_node_or_null("spawn_marker")
			if spawn_point:
				print("Found spawn_marker in player building")
	
	# Try to get spawn point from marker or use ball's initial position
	if spawn_point:
		spawn_position = spawn_point.global_position
		print("Spawn position set from marker: ", spawn_position)
	elif ball:
		spawn_position = ball.global_position
		print("Spawn position set from ball's initial position: ", spawn_position)
	else:
		push_error("Level manager: No spawn point or ball found!")

func get_spawn_position() -> Vector2:
	return spawn_position

func spawn_ball_at_spawn_point():
	if not ball:
		push_error("Level manager: No ball reference!")
		return
	
	ball.global_position = spawn_position
	ball.velocity = Vector2.ZERO
	ball.is_active = false
	ball.clear_trail()
	ball.idle_timer = 0.0
	
	print("Ball spawned at: ", spawn_position)

func set_spawn_position(pos: Vector2):
	spawn_position = pos
	print("Spawn position updated to: ", spawn_position)
