extends Area2D

# This kill zone simply needs to detect when the ball enters.
# The actual respawn logic is handled by game_mode.gd

# Note: The body_entered signal should be connected to game_mode._on_kill_zone_entered()
# This is done automatically by game_mode in its _ready() function
