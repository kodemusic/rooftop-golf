extends Node2D

@onready var particles = $GPUParticles2D

func _ready():
    particles.emitting = false

func play():
    particles.emitting = true
    particles.restart()
