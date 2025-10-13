extends Node2D

var ball: CharacterBody2D
var user_ui: Control  # Changed from CanvasLayer to Control
var aim_line: Line2D
var level_manager: Node2D
var goal: Node2D
var camera: Camera2D
var wind_flag: Sprite2D

var aiming = false
var current_power = 0.0
var shot_count = 0  # Track shots for star rating
var is_celebrating = false  # Prevent input during celebration

@export_group("Aiming")
@export var max_power = 1000  # 500.0
@export var max_dist = 300   # 500.0
@export var trajectory_power_scale = .8 # 4.0
@export var trajectory_length_factor = 0.06 # 0.5

var dash_length = 10.0
var gap_length = 5.0

# Trajectory prediction settings
var max_trajectory_points = 500
var trajectory_step = 0.05
var trajectory_cache = []
var min_trajectory_steps = 10

@export_group("Respawn Settings")
@export var max_distance_from_start: float = 2000.0  # Max distance ball can travel before respawn
var ball_start_position: Vector2

@export_group("Star Rating")
@export var three_star_shots: int = 1  # Par or better
@export var two_star_shots: int = 2
@export var one_star_shots: int = 3

@export_group("Celebration")
@export var celebration_duration: float = 2.5  # Time to wait before next level
@export var camera_zoom_amount: float = 1.20  # 1.5 How much to zoom in (higher = more zoomed)

@export_group("Wind")
@export var wind_enabled: bool = true
@export var wind_force: float = 50.0  # Base wind force
@export var wind_variance: float = 30.0  # Random variance in wind strength
@export var wind_change_interval: float = 5.0  # How often wind changes direction (seconds)

var current_wind_force: float = 0.0  # Current wind force (positive = east, negative = west)
var wind_timer: float = 0.0

func _ready() -> void:
	# Ensure input is not blocked
	set_process_input(true)
	
	# Find nodes dynamically in current level
	ball = find_child("ball", true, false)
	user_ui = find_child("user_ui", true, false)  # Find user_ui by name
	aim_line = find_child("aim_line", true, false)
	level_manager = find_child("level_manager", true, false)
	goal = find_child("goal", true, false)
	camera = get_viewport().get_camera_2d()
	wind_flag = find_child("wind_flag", true, false)
	
	print("game_mode._ready() called - Input enabled")
	
	if not ball:
		push_error("Ball not found in level!")
	else:
		# Store initial ball position for boundary checks
		ball_start_position = ball.global_position
		print("Ball found at: ", ball_start_position)
	
	if not user_ui:
		push_warning("UserUI not found in scene")
	
	# Use level manager for spawn position if available
	if level_manager:
		# Level manager will handle spawn position
		if ball:
			# Connect idle timeout signal
			ball.idle_timeout_reached.connect(respawn_ball)
	else:
		# Fallback to old method if no level manager
		push_warning("No level_manager found, using ball's initial position")
	
	if aim_line:
		aim_line.visible = false
	
	# Connect to goal if it exists
	if goal:
		goal.goal_scored.connect(_on_goal_scored)
	else:
		push_warning("No goal found in level!")
	
	# Connect kill zone if it exists
	var kill_zone = find_child("kill_zone", true, false)
	if kill_zone:
		kill_zone.body_entered.connect(_on_kill_zone_entered)

	# Initialize wind
	if wind_enabled:
		randomize_wind()

func _process(_delta: float) -> void:
	# Update wind
	if wind_enabled:
		wind_timer += _delta
		if wind_timer >= wind_change_interval:
			randomize_wind()
			wind_timer = 0.0

		# Apply wind to ball if it's moving
		if ball and ball.is_active and ball.velocity.length() > ball.min_velocity_threshold:
			ball.velocity.x += current_wind_force * _delta

	# Check if ball is too far from starting position
	if ball and ball.is_active:
		var distance_from_start = ball.global_position.distance_to(ball_start_position)
		if distance_from_start > max_distance_from_start:
			print("Ball went too far! Distance: ", distance_from_start)
			respawn_ball()

	if aiming:
		# Check if mouse is still behind the ball while aiming
		if ball:
			var mouse_pos = get_global_mouse_position()
			var to_mouse = mouse_pos - ball.global_position
			
			# If mouse moves in front of ball, cancel aiming
			if to_mouse.x > 0:
				aiming = false
				if aim_line:
					aim_line.visible = false
				print("Aiming canceled - mouse moved in front of ball")
				return
		
		update_aim_line()
		if aim_line:
			aim_line.visible = true
	else:
		if aim_line:
			aim_line.visible = false

func _input(event):
	# Prevent input during celebration
	if is_celebrating:
		return

	# Debug: Log input events
	if event is InputEventMouseButton:
		print("Mouse button event detected in game_mode: ", event.button_index, " pressed: ", event.pressed)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Only allow aiming if the ball is stopped and mouse is behind the ball
			if ball and ball.velocity.length() < ball.min_velocity_threshold:
				var mouse_pos = get_global_mouse_position()
				var to_mouse = mouse_pos - ball.global_position
				
				# Check if mouse is to the left of the ball (behind it)
				if to_mouse.x < 0:
					aiming = true
					print("Started aiming")
				else:
					print("Can't aim - mouse must be behind (left of) the ball")
		else:
			if aiming:
				shoot()
				print("Shot fired")
			aiming = false

func shoot():
	if not ball:
		return
	ball.clear_trail()
	# Invert direction for Angry Birds style - pull left to shoot right
	var direction = (ball.global_position - get_global_mouse_position()).normalized()
	ball.allow_impulse = true
	ball.allow_impulse_timer = 0.0
	ball.apply_impulse(direction * current_power)

	# Track shot count for star rating
	shot_count += 1
	print("Shot #", shot_count)

func update_aim_line():
	if not aim_line or not ball:
		return

	var mouse_pos = get_global_mouse_position()
	var ball_pos = ball.global_position

	# Invert direction for Angry Birds style - pull left to shoot right
	var direction = (ball_pos - mouse_pos).normalized()
	
	# Power is based on distance from mouse to ball
	var distance = mouse_pos.distance_to(ball_pos)
	current_power = (distance / max_dist) * max_power
	current_power = clamp(current_power, 0, max_power)

	trajectory_cache.clear()
	
	var start_pos = ball_pos
	var cs = ball.get_node_or_null("CollisionShape2D")
	if cs and cs.shape:
		if cs.shape is CircleShape2D:
			var radius_world = cs.shape.radius * cs.global_transform.get_scale().y
			start_pos += Vector2(0, -radius_world)

	# Simulate trajectory to match ball's physics
	var sim_pos = start_pos
	# Scale up the trajectory velocity to show a better preview arc
	var sim_vel = direction * current_power * trajectory_power_scale

	var trajectory_time_step = 0.016 # Smaller time step for more accurate arc visualization

	# Calculate more points to show the full arc
	var num_points = int(floor(current_power * trajectory_length_factor))
	if num_points < min_trajectory_steps:
		num_points = min_trajectory_steps
	if num_points > max_trajectory_points:
		num_points = max_trajectory_points

	for i in range(num_points):
		trajectory_cache.append(sim_pos)

		# Check if ball properties exist before using them
		if not ball or ball.gravity_force == null or ball.gravity_scale == null:
			break

		# Apply gravity (more frequently with smaller timestep)
		sim_vel.y += ball.gravity_force * ball.gravity_scale * trajectory_time_step

		# Apply wind to trajectory simulation
		if wind_enabled:
			sim_vel.x += current_wind_force * trajectory_time_step

		# Check ball properties for max speed
		if ball.max_speed == null:
			break

		# Clamp max speed
		if sim_vel.length() > ball.max_speed:
			sim_vel = sim_vel.normalized() * ball.max_speed

		# Check ball properties for air resistance
		if ball.min_velocity_threshold == null or ball.air_resistance == null:
			break

		# Apply air resistance
		if sim_vel.length() > ball.min_velocity_threshold:
			sim_vel *= pow(ball.air_resistance, trajectory_time_step * 60.0)
		else:
			sim_vel = Vector2.ZERO

		# Update position
		sim_pos += sim_vel * trajectory_time_step

		if sim_vel.length() < 1:
			break

	var dotted_points = PackedVector2Array()
	var i = 0
	while i < trajectory_cache.size():
		dotted_points.append(aim_line.to_local(trajectory_cache[i]))
		var step = 1 + int(i / 15)
		i += step
	aim_line.points = dotted_points

	# Update power indicator using the aim_line script
	if aim_line:
		print("[game_mode] aim_line found, has_method check: ", aim_line.has_method("update_power_indicator"))
		print("[game_mode] current_power: ", current_power, " max_power: ", max_power)
		var power_percent = current_power / max_power
		print("[game_mode] power_percent: ", power_percent)

		if aim_line.has_method("update_power_indicator"):
			aim_line.update_power_indicator(power_percent)
		else:
			print("[game_mode] ERROR: aim_line doesn't have update_power_indicator method!")
	else:
		print("[game_mode] ERROR: aim_line is null!")


func _on_goal_scored():
	print("Goal scored! Starting celebration sequence.")
	is_celebrating = true

	# Calculate star rating
	var stars = calculate_star_rating()
	print("Level complete! Stars: ", stars, " (Shots: ", shot_count, ")")

	# Activate fire trail if 3 stars earned (NBA Jam style)
	if stars == 3 and ball and ball.has_method("set_on_fire"):
		ball.set_on_fire(true)

	# Start celebration sequence
	call_deferred("_celebrate_goal", stars)

func calculate_star_rating() -> int:
	if shot_count <= three_star_shots:
		return 3
	elif shot_count <= two_star_shots:
		return 2
	elif shot_count <= one_star_shots:
		return 1
	else:
		return 1  # Always give at least 1 star for completing

func _celebrate_goal(stars: int):
	# Store original camera state
	var original_zoom = camera.zoom if camera else Vector2.ONE
	var original_pos = camera.position if camera else Vector2.ZERO

	# Zoom camera to goal with ease-in effect
	if camera and goal:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)

		# Zoom in
		tween.tween_property(camera, "zoom", Vector2.ONE * camera_zoom_amount, 0.8)
		# Move to goal
		tween.tween_property(camera, "position", goal.global_position, 0.8)

	# Wait for zoom animation
	await get_tree().create_timer(0.8).timeout

	# Show star rating UI with camera zoom amount for counter-scaling
	if user_ui:
		user_ui.show_star_rating(stars, shot_count, camera_zoom_amount)
		user_ui.increment_score()

	# Wait for the rest of celebration duration
	await get_tree().create_timer(celebration_duration - 0.8).timeout

	# Hide star UI
	if user_ui:
		user_ui.hide_star_rating()

	# Load next level
	_load_next_level()

func _load_next_level():
	# Reset celebration state
	is_celebrating = false
	shot_count = 0

	# Use GameManager singleton to progress levels
	GameManager.next_level()
	GameManager.load_current_level()

func respawn_ball():
	if not ball:
		return
	
	# Use level manager to respawn if available
	if level_manager:
		level_manager.spawn_ball_at_spawn_point()
		# Update the start position after respawn
		ball_start_position = ball.global_position
	else:
		# Fallback: just reset velocity and clear trail
		push_warning("No level_manager, ball position not reset")
		ball.velocity = Vector2.ZERO
		ball.is_active = false
		ball.clear_trail()
		ball.idle_timer = 0.0

func _on_kill_zone_entered(body):
	# Check if the ball entered the kill zone
	if body == ball:
		print("Ball entered kill zone!")

		# Extinguish fire trail on miss (NBA Jam style)
		if ball and ball.has_method("extinguish_fire"):
			ball.extinguish_fire()

		# Play miss sound before respawning
		if ball and ball.has_method("play_miss_sound"):
			ball.play_miss_sound()

		respawn_ball()

func randomize_wind():
	# Randomize wind direction (east or west) and strength
	var direction = 1 if randf() > 0.5 else -1
	var strength = wind_force + randf_range(-wind_variance, wind_variance)
	current_wind_force = direction * strength

	# Update flag visual indicator
	if wind_flag:
		# Scale.x = 1 for east (right), -1 for west (left)
		wind_flag.scale.x = abs(wind_flag.scale.x) * direction

	print("Wind updated: ", "East" if direction > 0 else "West", " at ", abs(current_wind_force), " force")
