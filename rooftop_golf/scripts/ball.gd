extends CharacterBody2D

@onready var trail_line = $Line2D
@onready var fire_trail = $fire_trail

# Line2D trail settings
@export_group("Trail")
@export var trail_enabled: bool = true
@export var trail_length: int = 50  # Maximum number of points in trail
@export var trail_width: float = 3.0  # Width of the trail line
@export var trail_color: Color = Color.WHITE  # Color of the trail
@export var trail_fade: bool = true  # Whether trail should fade out
@export var trail_min_distance: float = 5.0  # Minimum distance between trail points

var trail_points: PackedVector2Array = PackedVector2Array()

# Fire trail settings (NBA Jam style "on fire")
@export_group("Fire Trail")
@export var fire_trail_width: float = 8.0  # Width of the fire trail
@export var fire_trail_length: int = 60  # Length of fire trail

var fire_trail_points: PackedVector2Array = PackedVector2Array()
var is_on_fire: bool = false  # "On fire" state (3 stars earned)

# Dot trail pool (keeping for backwards compatibility if needed)
#var dot_texture = preload("res://assets/trail.png")
var dot_pool: Array = []
var pool_size: int = 140
var pool_index: int = 0

# Spacing in pixels between dots along the path
var dot_spacing: float = 24.0
var last_dot_pos = null

@export_group("Physics")
@export var max_speed = 800.0  # Maximum ball speed for arcade feel
@export var air_resistance = 0.98  # Slow down factor (0.98 = 2% slowdown per frame)
@export var min_velocity_threshold = 10.0  # Speed below which ball stops
@export var gravity_force := 900.0
@export var gravity_scale := 0.5
@export var bounce_factor := 0.6  # How much velocity to retain on bounce (0.6 = 60%)
@export var min_bounce_speed := 50.0  # Minimum speed required to bounce
var debug_traces: bool = false  # Set to true for debugging
var allow_impulse: bool = false
var allow_impulse_timer: float = 0.0
var allow_impulse_window: float = 0.2
var is_active: bool = false  # Prevent physics until first shot

# Idle detection for respawn
var idle_timer: float = 0.0
var idle_timeout: float = 2.0
signal idle_timeout_reached

# Audio players
@onready var ball_player_hit: AudioStreamPlayer2D = get_node_or_null("ball_player_hit")
@onready var ball_ground_hit: AudioStreamPlayer2D = get_node_or_null("ball_ground_hit")
@onready var aww_close: AudioStreamPlayer2D = get_node_or_null("aww_close")

# Audio settings
@export_group("Audio")
@export var ground_hit_pitch_range: Vector2 = Vector2(0.9, 1.3)  # Min/max pitch
@export var ground_hit_y_threshold: float = 400.0  # Y position below which pitch is normal
@export var miss_sound_chance: float = 0.7  # 70% chance to play miss sound

func _ready():
	add_to_group("ball")

	# Configure Line2D trail
	if trail_line:
		trail_line.visible = trail_enabled
		trail_line.width = trail_width
		trail_line.default_color = trail_color
		trail_line.antialiased = true
		trail_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		trail_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		trail_line.joint_mode = Line2D.LINE_JOINT_ROUND

		# Setup gradient for fade effect if enabled
		if trail_fade:
			var gradient = Gradient.new()
			gradient.add_point(0.0, Color(trail_color.r, trail_color.g, trail_color.b, 1.0))  # Full opacity at start (oldest)
			gradient.add_point(1.0, Color(trail_color.r, trail_color.g, trail_color.b, 0.0))  # Transparent at end (ball position)
			trail_line.gradient = gradient
		else:
			# No fade - solid color trail
			trail_line.gradient = null

	# Configure fire trail (NBA Jam style)
	if fire_trail:
		fire_trail.visible = false  # Hidden by default until "on fire"
		fire_trail.width = fire_trail_width
		fire_trail.antialiased = true
		fire_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
		fire_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
		fire_trail.joint_mode = Line2D.LINE_JOINT_ROUND
		# Gradient is already set in the scene with fire.tres resource

	# Debug: Check if audio nodes exist (uncomment for debugging)
	# print("[ball] ball_player_hit: ", ball_player_hit)
	# print("[ball] ball_ground_hit: ", ball_ground_hit)
	# print("[ball] aww_close: ", aww_close)

	# Arcade-style physics settings (CharacterBody2D-style)
	gravity_scale = gravity_scale

	# Create pooled sprites for dotted trail. Choose a robust parent so dots are in world space
	# If the ball is nested under a Character2D (or other), prefer the current scene root for stable world coords.
	var dots_parent = null
	var scene_root = get_tree().get_current_scene()
	if scene_root:
		dots_parent = scene_root
	elif get_parent():
		dots_parent = get_parent()
	else:
		dots_parent = get_tree().get_root()

	for i in range(pool_size):
		var s = Sprite2D.new()
		#s.texture = dot_texture
		s.visible = false
		s.centered = true
		s.z_index = 100
		# Use deferred add_child to avoid 'parent busy' errors in editor/runtime
		dots_parent.call_deferred("add_child", s)
		dot_pool.append(s)

func _physics_process(delta: float) -> void:
	# Don't apply physics until ball is shot
	if not is_active:
		return

	if debug_traces:
		print("[ball] START frame: velocity=", velocity, " pos=", global_position)

	# Apply gravity
	velocity.y += gravity_force * gravity_scale * delta

	# Clamp max speed
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed

	# Apply air resistance for arcade feel
	if velocity.length() > min_velocity_threshold:
		velocity *= pow(air_resistance, delta * 60.0)
	else:
		# Stop the ball if moving too slowly
		velocity = Vector2.ZERO

	if debug_traces:
		print("[ball] BEFORE move_and_slide: velocity=", velocity)

	# Store velocity before collision for bounce calculation
	var velocity_before_collision = velocity
	
	# Move the CharacterBody2D
	move_and_slide()
	
	# Apply bounce when hitting surfaces (world objects, not the ball itself)
	if get_slide_collision_count() > 0:
		for i in range(get_slide_collision_count()):
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			
			# Only bounce off world surfaces (buildings, walls, hazards)
			# Don't bounce off other balls or goal
			if collider and collider != self:
				var collision_normal = collision.get_normal()
				var speed_before = velocity_before_collision.length()
				
				if speed_before > min_bounce_speed:
					# Calculate bounce velocity using the velocity before collision
					var bounce_velocity = velocity_before_collision.bounce(collision_normal)
					
					# Apply bounce factor to reduce energy
					velocity = bounce_velocity * bounce_factor
					
					# Play ground hit sound with dynamic pitch based on Y position
					if ball_ground_hit and not ball_ground_hit.playing:
						# Calculate pitch based on Y position
						# Higher on screen (lower Y value) = higher pitch
						var pitch = 1.0  # Default pitch
						if global_position.y < ground_hit_y_threshold:
							# Map Y position to pitch range
							# Normalize Y to 0-1 range (0 at top, 1 at threshold)
							var y_normalized = clamp(global_position.y / ground_hit_y_threshold, 0.0, 1.0)
							# Invert so higher position = higher pitch
							y_normalized = 1.0 - y_normalized
							# Map to pitch range
							pitch = lerp(ground_hit_pitch_range.x, ground_hit_pitch_range.y, y_normalized)

						ball_ground_hit.pitch_scale = pitch
						ball_ground_hit.play()
					
					if debug_traces:
						print("[ball] BOUNCE! collider=", collider.name, " normal=", collision_normal, " speed=", speed_before, " new_velocity=", velocity)
					
					# Only process first collision
					break

	if debug_traces:
		print("[ball] AFTER move_and_slide: velocity=", velocity, " pos=", global_position, " is_on_floor=", is_on_floor(), " is_on_wall=", is_on_wall())

	# Update allow_impulse timer
	if allow_impulse:
		allow_impulse_timer += delta
		if allow_impulse_timer > allow_impulse_window:
			allow_impulse = false
			allow_impulse_timer = 0.0

	# Update Line2D trail - only show when ball is in the air or bouncing
	# Hide when rolling on ground (is_on_floor and low vertical velocity)
	var is_airborne = not is_on_floor() or abs(velocity.y) > 50.0  # In air or bouncing

	# Update fire trail if "on fire" (3 stars)
	if is_on_fire and fire_trail:
		if is_airborne and velocity.length() > 5:
			# Show fire trail when on fire and in air
			fire_trail.visible = true

			# Debug first time showing trail
			if fire_trail_points.size() == 0:
				print("[ball] Starting fire trail! is_airborne=", is_airborne, " velocity=", velocity.length())

			# Add current position to fire trail
			var should_add_point = false

			if fire_trail_points.size() == 0:
				should_add_point = true
			else:
				# Only add point if far enough from last point
				var last_point = fire_trail_points[fire_trail_points.size() - 1]
				if global_position.distance_to(last_point) >= trail_min_distance:
					should_add_point = true

			if should_add_point:
				fire_trail_points.append(global_position)

				# Limit fire trail length
				if fire_trail_points.size() > fire_trail_length:
					fire_trail_points.remove_at(0)

				# Convert global positions to local positions for Line2D
				var local_points = PackedVector2Array()
				for point in fire_trail_points:
					local_points.append(fire_trail.to_local(point))

				fire_trail.points = local_points

				# Debug periodically
				if fire_trail_points.size() % 10 == 0:
					print("[ball] Fire trail points: ", fire_trail_points.size(), " visible: ", fire_trail.visible)
		else:
			# Hide fire trail when rolling
			fire_trail.visible = false
			# Clear fire trail points when it becomes hidden
			if fire_trail_points.size() > 0:
				fire_trail_points.clear()
				fire_trail.points = PackedVector2Array()
	else:
		# Not on fire - hide fire trail
		if fire_trail:
			fire_trail.visible = false

	# Update normal trail (only when NOT on fire)
	if not is_on_fire and trail_enabled and trail_line:
		if is_airborne and velocity.length() > 5:
			# Show trail and add points when in air
			trail_line.visible = true

			# Add current position to trail
			var should_add_point = false

			if trail_points.size() == 0:
				should_add_point = true
			else:
				# Only add point if far enough from last point
				var last_point = trail_points[trail_points.size() - 1]
				if global_position.distance_to(last_point) >= trail_min_distance:
					should_add_point = true

			if should_add_point:
				trail_points.append(global_position)

				# Limit trail length
				if trail_points.size() > trail_length:
					trail_points.remove_at(0)

				# Convert global positions to local positions for Line2D
				var local_points = PackedVector2Array()
				for point in trail_points:
					local_points.append(trail_line.to_local(point))

				trail_line.points = local_points
		else:
			# Hide trail when rolling on ground
			trail_line.visible = false
			# Clear trail points when it becomes hidden
			if trail_points.size() > 0:
				trail_points.clear()
				trail_line.points = PackedVector2Array()
	else:
		# On fire - hide normal trail
		if trail_line:
			trail_line.visible = false

	# Place dots along the path at fixed spacing (legacy system)
	if velocity.length() > 5:  # if moving
		var pos = global_position
		if last_dot_pos == null:
			_place_dot(pos)
		elif pos.distance_to(last_dot_pos) >= dot_spacing:
			_place_dot(pos)
		# Reset idle timer when moving
		idle_timer = 0.0
	else:
		# Ball is stopped, increment idle timer
		if is_active:
			idle_timer += delta
			if idle_timer >= idle_timeout:
				idle_timeout_reached.emit()
				idle_timer = 0.0  # Reset to prevent repeated signals
	# Debugging velocity
	#print("[ball] velocity=", velocity)

func _place_dot(pos: Vector2) -> void:
	# Place next dot from the pool at world position 'pos'
	if dot_pool.size() == 0:
		return
	var s: Sprite2D = dot_pool[pool_index]
	pool_index = (pool_index + 1) % pool_size
	s.global_position = pos
	s.visible = true
	last_dot_pos = pos

func apply_impulse(impulse: Vector2) -> void:
	# Compatibility helper for game_mode which previously called apply_impulse on a RigidBody2D
	if not allow_impulse:
		if debug_traces:
			print("[ball] apply_impulse ignored (allow_impulse=false) impulse=", impulse)
		return
	# consume the guard
	allow_impulse = false
	allow_impulse_timer = 0.0
	# Activate the ball physics when first shot
	is_active = true
	velocity += impulse
	
	# Play hit sound when ball is struck
	if ball_player_hit:
		ball_player_hit.play()
	
	print("[ball] apply_impulse: impulse=", impulse, " new_velocity=", velocity)
	
func clear_trail():
	# Clear Line2D trail
	trail_points.clear()
	if trail_line:
		trail_line.points = PackedVector2Array()

	# Clear fire trail
	fire_trail_points.clear()
	if fire_trail:
		fire_trail.points = PackedVector2Array()

	# Hide all pooled dots and reset state (legacy system)
	for s in dot_pool:
		s.visible = false
	last_dot_pos = null
	pool_index = 0

func set_on_fire(fire: bool) -> void:
	# Activate/deactivate "on fire" mode (NBA Jam style)
	is_on_fire = fire

	if fire:
		print("[ball] 🔥 BALL IS ON FIRE! 🔥")
		print("[ball] fire_trail node exists: ", fire_trail != null)
		if fire_trail:
			print("[ball] fire_trail width: ", fire_trail.width)
			print("[ball] fire_trail has gradient: ", fire_trail.gradient != null)
	else:
		print("[ball] Fire trail deactivated")
		# Clear fire trail when deactivated
		fire_trail_points.clear()
		if fire_trail:
			fire_trail.visible = false
			fire_trail.points = PackedVector2Array()

func extinguish_fire() -> void:
	# Helper function to turn off fire trail (called on miss)
	set_on_fire(false)

func play_miss_sound() -> void:
	# Play the miss sound with random chance to avoid repetitiveness
	if not aww_close:
		push_warning("[ball] aww_close AudioStreamPlayer2D not found! Add it as a child of the ball.")
		return

	var random_roll = randf()

	if random_roll < miss_sound_chance:
		# Randomize pitch slightly for variety
		aww_close.pitch_scale = randf_range(0.95, 1.05)
		aww_close.play()
		print("[ball] Playing miss sound (pitch: ", aww_close.pitch_scale, ")")
