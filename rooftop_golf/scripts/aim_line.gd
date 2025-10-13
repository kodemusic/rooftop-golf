extends Line2D

@export_group("Power Indicator")
@export var power_color_enabled: bool = true  # Show power with color gradient
@export var low_power_color: Color = Color(0.2, 1.0, 0.2)  # Green for low power
@export var mid_power_color: Color = Color(1.0, 1.0, 0.2)  # Yellow for medium power
@export var high_power_color: Color = Color(1.0, 0.2, 0.2)  # Red for high power

@export_group("Trajectory Fade")
@export var trajectory_fade_enabled: bool = true
@export var trajectory_fade_start: float = 0.5  # Start fading at 50% of trajectory
@export var trajectory_fade_end_alpha: float = 0.1  # End transparency

@export_group("Texture Settings")
@export var line_texture: Texture2D = null  # Optional texture for the line
@export var texture_tile: bool = true  # Whether to tile the texture

func _ready() -> void:
	print("[aim_line] _ready() called")
	print("[aim_line] Script is attached and running!")
	print("[aim_line] power_color_enabled: ", power_color_enabled)
	print("[aim_line] trajectory_fade_enabled: ", trajectory_fade_enabled)

	# Set up texture if provided
	if line_texture:
		print("[aim_line] Setting up texture: ", line_texture)
		texture = line_texture
		texture_mode = Line2D.LINE_TEXTURE_TILE if texture_tile else Line2D.LINE_TEXTURE_STRETCH
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	else:
		print("[aim_line] No texture assigned")

## Updates the line appearance based on power percentage (0.0 to 1.0)
func update_power_indicator(power_percent: float) -> void:
	# Clamp power percentage to valid range
	power_percent = clamp(power_percent, 0.0, 1.0)

	print("[aim_line] update_power_indicator called with power_percent: ", power_percent)

	# Determine color based on power
	var line_color = Color.WHITE
	if power_color_enabled:
		if power_percent < 0.5:
			# Interpolate between low and mid power colors
			line_color = low_power_color.lerp(mid_power_color, power_percent * 2.0)
		else:
			# Interpolate between mid and high power colors
			line_color = mid_power_color.lerp(high_power_color, (power_percent - 0.5) * 2.0)

	print("[aim_line] line_color: ", line_color, " power_color_enabled: ", power_color_enabled)

	# Apply fade gradient if enabled
	if trajectory_fade_enabled:
		var gradient_obj = Gradient.new()
		gradient_obj.add_point(0.0, Color(line_color.r, line_color.g, line_color.b, 1.0))
		gradient_obj.add_point(trajectory_fade_start, Color(line_color.r, line_color.g, line_color.b, 1.0))
		gradient_obj.add_point(1.0, Color(line_color.r, line_color.g, line_color.b, trajectory_fade_end_alpha))
		gradient = gradient_obj
		self_modulate = Color.WHITE  # Reset modulate when using gradient
		print("[aim_line] Applied gradient fade")
	else:
		# Use self_modulate for solid color (tints the texture if present)
		gradient = null
		self_modulate = line_color
		print("[aim_line] Applied self_modulate color")
