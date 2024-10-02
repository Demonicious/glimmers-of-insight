extends CharacterBody3D
class_name Player

@export var SPEED := 8.0
@export var ACCEL := 14.0
@export var JUMP_SPEED := 8.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var jumping = false

@onready var model      = $Rig
@onready var anim_tree  = $AnimationTree
@onready var anim_state = $AnimationTree.get("parameters/playback")

func _physics_process(delta: float) -> void:
	_movement(delta)

func _movement(delta: float) -> void:
	var vy = velocity.y + (-gravity * delta);
	velocity.y = 0
	
	var input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction = Vector3(input.x, 0, input.y).rotated(Vector3.UP, 0)
	
	velocity = lerp(velocity, direction * SPEED, ACCEL * delta)
	
	model.look_at(direction, Vector3.UP)
	
	print(direction.normalized())
	# velocity.y = vy
	
	move_and_slide()
