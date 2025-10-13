extends Control

var score_label: Label
var star_container: Control

var score: int = 0

func _ready() -> void:
	# Safely get the score label node
	score_label = get_node_or_null("score_label")
	if not score_label:
		push_warning("UserUI: score_label not found in scene tree")
	update_score_label()

	# Create star container if it doesn't exist
	star_container = get_node_or_null("star_container")

func increment_score() -> void:
	score += 1
	update_score_label()

func update_score_label() -> void:
	if score_label:
		score_label.text = "Score: " + str(score)

func reset_score() -> void:
	score = 0
	update_score_label()

func show_star_rating(stars: int, shot_count: int, camera_zoom: float = 1.0) -> void:
	# Hide the score label during celebration to avoid overlap
	if score_label:
		score_label.visible = false

	# Create or get star container
	if not star_container:
		star_container = Control.new()
		star_container.name = "star_container"
		star_container.z_index = 100  # Ensure it's on top
		add_child(star_container)

		# Center the container in viewport
		star_container.set_anchors_preset(Control.PRESET_CENTER)
		star_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
		star_container.grow_vertical = Control.GROW_DIRECTION_BOTH

	# Counter-scale to compensate for camera zoom
	# This keeps UI elements the same visual size regardless of camera zoom
	var inverse_zoom = 1.0 / camera_zoom
	star_container.scale = Vector2.ONE * inverse_zoom

	# Clear previous stars
	for child in star_container.get_children():
		child.queue_free()

	# Create a VBoxContainer for better layout
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(-150, -50)  # Adjusted to prevent top cutoff
	vbox.add_theme_constant_override("separation", 20)
	star_container.add_child(vbox)

	# Create title label
	var title_label = Label.new()
	title_label.text = "Level Complete!"
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	# Create shots label
	var shots_label = Label.new()
	shots_label.text = "Shots: " + str(shot_count)
	shots_label.add_theme_font_size_override("font_size", 32)
	shots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(shots_label)

	# Create stars display container
	var star_hbox = HBoxContainer.new()
	star_hbox.add_theme_constant_override("separation", 10)
	star_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(star_hbox)

	for i in range(3):
		var star_label = Label.new()
		if i < stars:
			star_label.text = "★"  # Filled star
			star_label.modulate = Color(1.0, 0.85, 0.0)  # Gold color
		else:
			star_label.text = "☆"  # Empty star
			star_label.modulate = Color(0.5, 0.5, 0.5)  # Gray
		star_label.add_theme_font_size_override("font_size", 64)
		star_hbox.add_child(star_label)

		# Animate star appearance
		star_label.modulate.a = 0
		var tween = create_tween()
		tween.tween_property(star_label, "modulate:a", 1.0, 0.3).set_delay(i * 0.2)
		tween.tween_property(star_label, "scale", Vector2(1.2, 1.2), 0.1)
		tween.tween_property(star_label, "scale", Vector2.ONE, 0.1)

	star_container.visible = true

func hide_star_rating() -> void:
	if star_container:
		star_container.visible = false

	# Show the score label again
	if score_label:
		score_label.visible = true
