extends CharacterBody3D
class_name Player

signal glimmer_learnt

@export var MAX_HEALTH := 8
@export var HEALTH := 8

@export var SPEED := 8.0
@export var FOOTSTEPS_SPEED_MIN := 5.0
@export var ORBIT_SPEED := 0.225
@export var LERP_WEIGHT := 16.0

@export var HP_ICON_FULL : Texture
@export var HP_ICON_EMPTY : Texture
@export var SELECTION_ICON : Texture

@onready var model      = $Rig
@onready var anim_tree  = $AnimationTree
@onready var anim_state = $AnimationTree.get("parameters/playback")
@onready var cam_pivot  = $Pivot

@onready var footsteps_audio = $Audio/Footsteps
@onready var switch_audio = $Audio/SwitchGlimmer

@onready var interaction_trigger = $InteractionTrigger

@onready var healthbar_control = $Interface/Healthbar
@onready var glimmers_control  = $Interface/Glimmers
@onready var interact_tooltip  = $InteractTooltip

@onready var ground_raycast = $Rig/GroundRaycast

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var can_move := true
var direction := Vector3.ZERO
var grounded := false
var is_rotating := false

@export var learnt_glimmers: Dictionary = {}
var selected_glimmer: int = 0
var targeted_glimmer: GlimmerData = null
var targeted_node: Node3D = null
var select_rect: TextureRect

func _ready() -> void:
	interaction_trigger.connect("area_entered", _glimmer_detected)
	interaction_trigger.connect("area_exited", _glimmer_left)
	
	_render_health()
	_render_glimmer_cursor()
	
	connect("glimmer_learnt", _render_glimmer)

func _physics_process(delta: float) -> void:
	if targeted_glimmer:
		if !learnt_glimmers.has(targeted_glimmer.id):
			create_tween().tween_property(interact_tooltip, "modulate:a", 1, 0.15)
			
			if Input.is_action_just_pressed("glimmer_interact"):
				create_tween().tween_property(interact_tooltip, "modulate:a", 0, 0.15)
				learnt_glimmers[targeted_glimmer.id] = targeted_glimmer
				selected_glimmer = learnt_glimmers.size() - 1
				glimmer_learnt.emit(targeted_glimmer)
				anim_state.travel("Glimmer_Interact")
		elif Input.is_action_just_pressed("glimmer_interact"):
			anim_state.travel("Glimmer_Interact")
			targeted_node.free()
	else:
		create_tween().tween_property(interact_tooltip, "modulate:a", 0, 0.15)
	
	grounded = velocity.y == 0
	
	_glimmer_selection()
	
	if can_move:
		_movement(delta)
		
	_default_animations(delta)
	_camera_rotation()
	_glimmer_usage()

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

func _default_animations(delta: float) -> void:
	anim_tree.set("parameters/conditions/grounded", grounded)
	
	# Play Idle & Run Animation based on Direction
	anim_tree.set("parameters/IdleRun/blend_position", lerp(anim_tree.get("parameters/IdleRun/blend_position"), clamp(abs(direction.x) + abs(direction.z), 0, 1) * 1.0, LERP_WEIGHT * delta))
	
	if !grounded:
		anim_state.travel("Jump_Idle")

func _camera_rotation() -> void:
	# Rotate the Camera when Left or Right triggers are pressed.
	
	var will_rotate := false
	var angle  := 0.0 

	if Input.is_action_just_pressed("camera_rotate_right"):
		will_rotate = true
		angle = -90.0
	elif Input.is_action_just_pressed("camera_rotate_left"):
		will_rotate = true
		angle = 90.0
		
	if will_rotate && !is_rotating:
		is_rotating = true
		await create_tween().tween_property(cam_pivot, "rotation", Vector3(0, cam_pivot.rotation.y + deg_to_rad(angle), 0), ORBIT_SPEED).finished
		is_rotating = false

func sound_footsteps() -> void:
	# Only sound footsteps when speed is above a threshold.
	if max(abs(velocity.x), abs(velocity.z)) >= FOOTSTEPS_SPEED_MIN:
		footsteps_audio.pitch_scale = randf_range(0.89, 1.21)
		footsteps_audio.play()

func _render_health() -> void:
	var children = healthbar_control.get_children()
	for child in children:
		child.free()
	
	for i in range(0, HEALTH):
		var tex_rect = TextureRect.new()
		tex_rect.texture = HP_ICON_FULL
		tex_rect.position = Vector2(36 + (i * 36), 32)
		healthbar_control.add_child(tex_rect)
	
	for i in range(HEALTH, MAX_HEALTH - 1):
		var tex_rect = TextureRect.new()
		tex_rect.texture = HP_ICON_EMPTY
		tex_rect.position = Vector2(36 + (i * 36), 32)
		healthbar_control.add_child(tex_rect)

func _render_glimmer(glimmer: GlimmerData) -> void:
	var keys = learnt_glimmers.keys()
	
	var tex_rect = TextureRect.new()
	tex_rect.modulate.a = 0
	tex_rect.texture = glimmer.icon
	tex_rect.position = Vector2(36 + (learnt_glimmers.size() * (128)), 96)
	glimmers_control.add_child(tex_rect)
	tex_rect.z_index = 0
	create_tween().tween_property(tex_rect, "modulate:a", 1, 0.75)
	
	_move_glimmer_cursor()

func _glimmer_selection() -> void:
	var last_selection := selected_glimmer
	
	if Input.is_action_just_pressed("glimmer_next"):
		selected_glimmer += 1
	
	if Input.is_action_just_pressed("glimmer_previous"):
		selected_glimmer -= 1
	
	if learnt_glimmers.size():
		selected_glimmer = clamp(selected_glimmer, 0, learnt_glimmers.size() - 1)
	else:
		selected_glimmer = 0
	
	if selected_glimmer != last_selection:
		_move_glimmer_cursor()
	
	if learnt_glimmers.size():
		create_tween().tween_property(select_rect, "modulate:a", 1, 0.75)

func _render_glimmer_cursor() -> void:
	select_rect = TextureRect.new()
	select_rect.modulate.a = 0
	select_rect.texture = SELECTION_ICON
	select_rect.position = Vector2(36 + ((learnt_glimmers.size() + 1) * 128), 96)
	glimmers_control.add_child(select_rect)
	select_rect.z_index = -5

func _move_glimmer_cursor() -> void:
	create_tween().tween_property(select_rect, "position", Vector2(36 + (selected_glimmer + 1) * 128, 96), 0.1)
	switch_audio.pitch_scale = randf_range(0.89, 1.21)
	switch_audio.play()

func _glimmer_detected(area3d: Area3D) -> void:
	var glimmer: Glimmer = area3d.get_parent()
	
	if glimmer:
		targeted_glimmer = glimmer.get_node("GlimmerData")
		targeted_node    = glimmer

func _glimmer_left(_area3d: Area3D) -> void:
	targeted_glimmer = null
	targeted_node = null

func _glimmer_usage() -> void:
	if Input.is_action_just_pressed("glimmer_use") and velocity.y == 0:
		anim_state.travel("Glimmer_Use")

func spawn_glimmer() -> void:
	var keys = learnt_glimmers.keys()
	var glimmer: GlimmerData = learnt_glimmers.get(keys[selected_glimmer])
	
	var scene = load(glimmer.scene_path)
	var instance = scene.instantiate()
	
	instance.position = position
	instance.position.x += 2
	
	get_parent().add_child(instance)
	
	pass

func lock_movement() -> void:
	velocity = Vector3.ZERO
	direction = Vector3.ZERO
	
	can_move = false
	
func unlock_movement() -> void:
	can_move = true
