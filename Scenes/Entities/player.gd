extends CharacterBody3D
class_name Player

@export var SPEED := 8.0
@export var LERP_WEIGHT := 16.0
@export var JUMP_FORCE := 150.0

@export var ORBIT_SPEED := 0.125

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var model      = $Rig
@onready var anim_tree  = $AnimationTree
@onready var anim_state = $AnimationTree.get("parameters/playback")
@onready var cam_pivot  = $Pivot

var direction = Vector3.ZERO
var grounded := false

func _physics_process(delta: float) -> void:
	grounded = velocity.y == 0
	
	_movement(delta)
	_animations(delta)
	_camera_rotation(delta)

func _movement(delta: float) -> void:
	# Temporarily store Y Velocity and Zero it out so we can assign a vector to velocity directly.
	var vy = lerp(velocity.y, -gravity, LERP_WEIGHT * delta);
	velocity.y = 0
	
	# Get the Direction Vector from the Input which is also looking towards the camera.
	var input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	direction = Vector3(input.x, 0, input.y).rotated(Vector3.UP, cam_pivot.rotation.y)
	
	velocity = lerp(velocity, direction * SPEED, LERP_WEIGHT * delta)
	
	# Look towards the movement direction if moving
	if direction != Vector3.ZERO:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-direction.x, -direction.z), LERP_WEIGHT * delta)
	
	# Apply Gravity
	velocity.y = vy
	
	move_and_slide()

func _animations(delta: float) -> void:
	anim_tree.set("parameters/conditions/grounded", grounded)
	
	# Play Idle & Run Animation based on Direction
	anim_tree.set("parameters/IdleRun/blend_position", lerp(anim_tree.get("parameters/IdleRun/blend_position"), clamp(abs(direction.x) + abs(direction.z), 0, 1) * 1.0, LERP_WEIGHT * delta))
	
	if !grounded:
		anim_state.travel("Jump_Idle")


func _camera_rotation(delta: float) -> void:
	var rotate := false
	var angle  := 0.0 

	if Input.is_action_just_pressed("camera_rotate_right"):
		rotate = true
		angle = -90.0
	elif Input.is_action_just_pressed("camera_rotate_left"):
		rotate = true
		angle = 90.0
		
	if rotate:
		create_tween().tween_property(cam_pivot, "rotation", Vector3(0, cam_pivot.rotation.y + deg_to_rad(angle), 0), ORBIT_SPEED)
