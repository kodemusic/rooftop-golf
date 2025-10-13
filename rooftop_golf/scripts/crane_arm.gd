extends PinJoint2D

@export_group("Platform Movement")
@export var enable_impulse: bool = true
@export var impulse_interval: float = 3.0  # Time between impulses
@export var impulse_strength_range: Vector2 = Vector2(50.0, 150.0)  # Min and max impulse force
@export var impulse_position_offset: Vector2 = Vector2(300.0, 0.0)  # Where to apply impulse relative to center

@onready var rigid_body: RigidBody2D = $platform
var impulse_timer: float = 0.0

func _ready() -> void:
	if enable_impulse and rigid_body:
		# Start with random timer offset so multiple cranes don't sync
		impulse_timer = randf_range(0.0, impulse_interval)

func _physics_process(delta: float) -> void:
	if not enable_impulse or not rigid_body:
		return

	impulse_timer += delta

	if impulse_timer >= impulse_interval:
		apply_random_impulse()
		impulse_timer = 0.0

func apply_random_impulse() -> void:
	if not rigid_body:
		return

	# Random impulse strength within range
	var impulse_strength = randf_range(impulse_strength_range.x, impulse_strength_range.y)

	# Random direction (left or right)
	var direction = 1.0 if randf() > 0.5 else -1.0

	# Create impulse vector (mostly horizontal with slight vertical variation)
	var impulse = Vector2(
		impulse_strength * direction,
		randf_range(-impulse_strength * 0.2, impulse_strength * 0.2)
	)

	# Apply impulse at offset position to create rotational movement
	rigid_body.apply_impulse(impulse, impulse_position_offset)
