extends Node2D

signal goal_scored

# Audio player
@onready var crowd_cheer: AudioStreamPlayer2D = get_node_or_null("crowd_cheer")
@onready var fireworks: Node2D = get_node_or_null("FireworksTest")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Fireworks start disabled by default now


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_goal_cup_body_entered(body: Node2D) -> void:
	if body.is_in_group("ball"):
		print("Goal! Ball entered the cup!")

		# Play crowd cheer sound
		if crowd_cheer:
			crowd_cheer.play()

		# Play fireworks particle effect
		if fireworks:
			fireworks.play()

		# Deactivate and hide the ball after scoring
		if body.has_method("set"):
			body.is_active = false
			body.velocity = Vector2.ZERO
			body.visible = false

		goal_scored.emit()
