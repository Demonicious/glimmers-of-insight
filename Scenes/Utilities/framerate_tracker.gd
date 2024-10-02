extends Node

@onready var timer := $Timer

func _ready() -> void:
	timer.connect("timeout", update_framerate)

func update_framerate() -> void:
	var title := "FPS: " + str(Engine.get_frames_per_second())
	DisplayServer.window_set_title(title)
