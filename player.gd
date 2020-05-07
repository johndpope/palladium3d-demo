extends KinematicBody
class_name PalladiumPlayer

signal arrived_to(player_node, target_node)
signal arrived_to_boundary(player_node, target_node)

const PLAYER_NAME_HINT = "player"

export var initial_player = true
export var initial_companion = false
export var name_hint = PLAYER_NAME_HINT
export var model_path = "res://scenes/female.tscn"

const GRAVITY = -6.2
var vel = Vector3()
const MAX_SPEED = 5
const JUMP_SPEED = 4.5
const ACCEL= 1.5

const MAX_SPRINT_SPEED = 15
const SPRINT_ACCEL = 4.5

var dir = Vector3()

const DEACCEL= 16
const MAX_SLOPE_ANGLE = 60

onready var upper_body_shape = $UpperBody_CollisionShape
onready var body_shape = $Body_CollisionShape
onready var rotation_helper = $Rotation_Helper
onready var standing_area = $StandingArea
onready var detail_timer = $DetailTimer

var is_walking = false
var is_crouching = false
var is_sprinting = false
var is_in_jump = false

var angle_rad_x = 0
var angle_rad_y = 0

const AXIS_VALUE_THRESHOLD = 0.15
var MOUSE_SENSITIVITY = 0.1 #0.05
var KEY_LOOK_SPEED_FACTOR = 30

#####

export var floor_path = "../StaticBodyFloor"
export var rotation_speed = 0.03
export var linear_speed = 2.8

onready var pyramid = get_parent()
onready var floor_node = get_node(floor_path)
const ANGLE_TOLERANCE = 0.01
const MIN_MOVEMENT = 0.01

const CONVERSATION_RANGE = 7
const FOLLOW_RANGE = 3
const CLOSEUP_RANGE = 2
const ALIGNMENT_RANGE = 0.2

const CAMERA_ROT_MIN_DEG = -88
const CAMERA_ROT_MAX_DEG = 88
const MODEL_ROT_MIN_DEG = -88
const MODEL_ROT_MAX_DEG = 0
const SHAPE_ROT_MIN_DEG = -90-88
const SHAPE_ROT_MAX_DEG = -90+88
const NONCHAR_COLLISION_RANGE_MAX = 5.9

var cur_animation = null
var UP_DIR = Vector3(0, 1, 0)
var Z_DIR = Vector3(0, 0, 1)
var ZERO_DIR = Vector3(0, 0, 0)
var PUSH_STRENGTH = 10

var path = []
var exclusions = []

enum COMPANION_STATE {REST, WALK, RUN}
var companion_state = COMPANION_STATE.REST
var target_node = null
const DRAW_PATH = false
var pathfinding_enabled = true

enum SoundId {SOUND_WALK_NONE, SOUND_WALK_SAND, SOUND_WALK_GRASS, SOUND_WALK_CONCRETE}
const SOUND_PATH_TEMPLATE = "res://sound/environment/%s"
onready var sound = {
	SoundId.SOUND_WALK_NONE : null,
	SoundId.SOUND_WALK_SAND : load(SOUND_PATH_TEMPLATE % "161815__dasdeer__sand-walk.ogg"),
	SoundId.SOUND_WALK_GRASS : load(SOUND_PATH_TEMPLATE % "400123__harrietniamh__footsteps-on-grass.ogg"),
	SoundId.SOUND_WALK_CONCRETE : load(SOUND_PATH_TEMPLATE % "336598__inspectorj__footsteps-concrete-a.ogg")
}

func set_pathfinding_enabled(enabled):
	pathfinding_enabled = enabled

func get_rotation_angle(cur_dir, target_dir):
	var c = cur_dir.normalized()
	var t = target_dir.normalized()
	var cross = c.cross(t)
	var sgn = 1 if cross.y > 0 else -1
	var dot = c.dot(t)
	if dot > 1.0:
		return 0
	elif dot < -1.0:
		return PI
	else:
		return sgn * acos(dot)

func get_follow_parameters(node_to_follow_pos, current_transform, next_position):
	var was_moving = companion_state != COMPANION_STATE.REST
	var current_position = current_transform.origin
	var in_party = is_in_party()
	var cur_dir = current_transform.basis.xform(Z_DIR)
	cur_dir.y = 0
	var next_dir = next_position - current_position
	next_dir.y = 0
	
	var rotation_angle = 0
	var rotation_angle_to_target_deg = 0
	var preferred_target = get_preferred_target()
	if preferred_target:
		var t = preferred_target.get_global_transform()
		var target_position = t.origin
		var mov_vec = target_position - current_position if was_moving else node_to_follow_pos - current_position
		mov_vec.y = 0
		rotation_angle = get_rotation_angle(cur_dir, next_dir) \
							if in_party or next_dir.length() > ALIGNMENT_RANGE \
							else get_rotation_angle(cur_dir, t.basis.xform(Z_DIR))
		rotation_angle_to_target_deg = rad2deg(get_rotation_angle(cur_dir, mov_vec))
	
	return {
		"was_moving" : was_moving,
		"next_dir" : next_dir,
		"rotation_angle" : rotation_angle,
		"rotation_angle_to_target_deg" : rotation_angle_to_target_deg
	}

func follow(current_transform, next_position):
	var p = get_follow_parameters(game_params.get_player().get_global_transform().origin, current_transform, next_position)
	var was_moving = p.was_moving
	var next_dir = p.next_dir
	var distance = next_dir.length()
	var rotation_angle = p.rotation_angle
	var rotation_angle_to_target_deg = p.rotation_angle_to_target_deg
	
	var in_party = is_in_party()
	angle_rad_y = 0
	if not in_party or companion_state == COMPANION_STATE.WALK:
		if rotation_angle > 0.1:
			angle_rad_y = deg2rad(KEY_LOOK_SPEED_FACTOR * MOUSE_SENSITIVITY)
		elif rotation_angle < -0.1:
			angle_rad_y = deg2rad(KEY_LOOK_SPEED_FACTOR * MOUSE_SENSITIVITY * -1)
	
	var model = get_model()
	if not path.empty():
		companion_state = COMPANION_STATE.WALK
		model.walk(rotation_angle_to_target_deg, is_crouching, is_sprinting)
		if distance <= ALIGNMENT_RANGE:
			path.pop_front()
			dir = Vector3()
		else:
			dir = next_dir.normalized()
		if not $SoundWalking.is_playing():
			$SoundWalking.play()
	elif in_party and distance > FOLLOW_RANGE:
		companion_state = COMPANION_STATE.WALK
		model.walk(rotation_angle_to_target_deg, is_crouching, is_sprinting)
		dir = next_dir.normalized()
		if not $SoundWalking.is_playing():
			$SoundWalking.play()
	elif (in_party and distance > CLOSEUP_RANGE and companion_state == COMPANION_STATE.WALK) or (not in_party and distance > ALIGNMENT_RANGE):
		if was_moving and not in_party and target_node and angle_rad_y == 0 and get_slide_count() > 0:
			var collision = get_slide_collision(0)
			if collision.collider_id == target_node.get_instance_id():
				emit_signal("arrived_to_boundary", self, target_node)
				companion_state = COMPANION_STATE.REST
				model.look(rotation_angle_to_target_deg)
				dir = Vector3()
				return
		companion_state = COMPANION_STATE.WALK
		model.walk(rotation_angle_to_target_deg, is_crouching, is_sprinting)
		dir = next_dir.normalized()
		if not $SoundWalking.is_playing():
			$SoundWalking.play()
	else:
		model.look(rotation_angle_to_target_deg)
		dir = Vector3()
		if in_party:
			companion_state = COMPANION_STATE.REST
		else:
			if was_moving and target_node and angle_rad_y == 0 and distance <= ALIGNMENT_RANGE:
				emit_signal("arrived_to", self, target_node)
				companion_state = COMPANION_STATE.REST

func is_in_speak_mode():
	return get_model().is_in_speak_mode()

func set_speak_mode(enable):
	get_model().set_speak_mode(enable)

func sit_down(force = false):
	if $AnimationPlayer.is_playing():
		return
	get_model().sit_down(force)
	$AnimationPlayer.play("crouch")
	var is_player = is_player()
	if is_player:
		var companions = game_params.get_companions()
		for companion in companions:
			companion.sit_down(force)
	is_crouching = true
	if is_player:
		var hud = game_params.get_hud()
		if hud:
			hud.set_crouch_indicator(true)

func stand_up(force = false):
	if $AnimationPlayer.is_playing():
		return
	if is_low_ceiling():
		# I.e. if the player is crouching and something is above the head, do not allow to stand up.
		return
	get_model().stand_up(force)
	$AnimationPlayer.play_backwards("crouch")
	var is_player = is_player()
	if is_player:
		var companions = game_params.get_companions()
		for companion in companions:
			companion.stand_up(force)
	is_crouching = false
	if is_player:
		var hud = game_params.get_hud()
		if hud:
			hud.set_crouch_indicator(false)

func update_navpath(pstart, pend):
	path = get_navpath(pstart, pend)
	if DRAW_PATH:
		draw_path()

func get_navpath(pstart, pend):
	if not pathfinding_enabled:
		return []
	var p1 = pyramid.get_closest_point(pstart)
	var p2 = pyramid.get_closest_point(pend)
	var p = pyramid.get_simple_path(p1, p2, true)
	return Array(p) # Vector3array too complex to use, convert to regular array

func has_collisions():
	var sc = get_slide_count()
	for i in range(0, sc):
		var collision = get_slide_collision(i)
		if not collision.collider.get_collision_mask_bit(2):
			return true
	return false

func build_path(target_position, in_party):
	var current_position = get_global_transform().origin
	var mov_vec = target_position - current_position
	mov_vec.y = 0
	if in_party:
		if mov_vec.length() < CLOSEUP_RANGE - ALIGNMENT_RANGE:
			clear_path()
			return
		# filter out points of the path, distance to which is greater than distance to player
		while not path.empty():
			var pt = path.back()
			var mov_pt = target_position - pt
			if mov_pt.length() <= mov_vec.length():
				break
			path.pop_back()
	if has_collisions() and path.empty(): # should check possible stuck
		#clear_path()
		update_navpath(current_position, target_position)

func draw_path():
	for ch in pyramid.get_node("path_holder").get_children():
		pyramid.get_node("path_holder").remove_child(ch)
	var k = 1.0
	for p in path:
		var m = MeshInstance.new()
		m.mesh = SphereMesh.new()
		m.mesh.radius = 0.1 * k
		k = k + 0.1
		pyramid.get_node("path_holder").add_child(m)
		m.global_translate(p)

func clear_path():
	for ch in pyramid.get_node("path_holder").get_children():
		pyramid.get_node("path_holder").remove_child(ch)
	path.clear()

func get_cam_holder():
	return get_node("Rotation_Helper/Camera")

func get_cam():
	var cutscene_cam = cutscene_manager.get_cam()
	return cutscene_cam if cutscene_cam else get_cam_holder().get_node("camera")

func use(player_node):
	if not conversation_manager.conversation_active():
		game_params.handle_conversation(player_node, self, player_node)

func get_model_holder():
	return get_node("Model")

func get_model():
	return get_model_holder().get_child(0)

func _input(event):
	if not is_player():
		return
	var hud = game_params.get_hud()
	var conversation = hud.conversation
	if conversation.is_visible_in_tree():
		if event.is_action_pressed("dialogue_next"):
			conversation_manager.proceed_story_immediately(self)
		elif event.is_action_pressed("dialogue_option_1"):
			conversation_manager.story_choose(self, 0)
		elif event.is_action_pressed("dialogue_option_2"):
			conversation_manager.story_choose(self, 1)
		elif event.is_action_pressed("dialogue_option_3"):
			conversation_manager.story_choose(self, 2)
		elif event.is_action_pressed("dialogue_option_4"):
			conversation_manager.story_choose(self, 3)
	if is_in_party() and not cutscene_manager.is_cutscene():
		if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			angle_rad_x = deg2rad(event.relative.y * MOUSE_SENSITIVITY)
			angle_rad_y = deg2rad(event.relative.x * MOUSE_SENSITIVITY * -1)
			process_rotation()
			angle_rad_x = 0
			angle_rad_y = 0
		elif event is InputEventJoypadMotion:
			var v = event.get_axis_value()
			var nonzero = v > AXIS_VALUE_THRESHOLD or v < -AXIS_VALUE_THRESHOLD
			if event.get_axis() == JOY_AXIS_2:  # Joypad Right Stick Horizontal Axis
				angle_rad_y = deg2rad(KEY_LOOK_SPEED_FACTOR * MOUSE_SENSITIVITY * -v) if nonzero else 0
			if event.get_axis() == JOY_AXIS_3:  # Joypad Right Stick Vertical Axis
				angle_rad_x = deg2rad(KEY_LOOK_SPEED_FACTOR * MOUSE_SENSITIVITY * v) if nonzero else 0
		else:
			if event.is_action_pressed("cam_up"):
				angle_rad_x = deg2rad(KEY_LOOK_SPEED_FACTOR * MOUSE_SENSITIVITY * -1)
			elif event.is_action_pressed("cam_down"):
				angle_rad_x = deg2rad(KEY_LOOK_SPEED_FACTOR * MOUSE_SENSITIVITY)
			elif event.is_action_released("cam_up") or event.is_action_released("cam_down"):
				angle_rad_x = 0
			
			if event.is_action_pressed("cam_left"):
				angle_rad_y = deg2rad(KEY_LOOK_SPEED_FACTOR * MOUSE_SENSITIVITY)
			elif event.is_action_pressed("cam_right"):
				angle_rad_y = deg2rad(KEY_LOOK_SPEED_FACTOR * MOUSE_SENSITIVITY * -1)
			elif event.is_action_released("cam_left") or event.is_action_released("cam_right"):
				angle_rad_y = 0

func process_rotation():
	rotation_helper.rotate_x(angle_rad_x)
	get_model_holder().rotate_x(angle_rad_x)
	upper_body_shape.rotate_x(angle_rad_x)
	self.rotate_y(angle_rad_y)
	var camera_rot = rotation_helper.rotation_degrees
	var model_rot = Vector3(camera_rot.x, camera_rot.y, camera_rot.z)
	var shape_rot = upper_body_shape.rotation_degrees
	camera_rot.x = clamp(camera_rot.x, CAMERA_ROT_MIN_DEG, CAMERA_ROT_MAX_DEG)
	rotation_helper.rotation_degrees = camera_rot
	model_rot.x = clamp(model_rot.x, MODEL_ROT_MIN_DEG, MODEL_ROT_MAX_DEG)
	get_model_holder().rotation_degrees = model_rot
	shape_rot.x = clamp(shape_rot.x, SHAPE_ROT_MIN_DEG, SHAPE_ROT_MAX_DEG)
	upper_body_shape.rotation_degrees = shape_rot

func add_highlight(player_node):
	#door_mesh.mesh.surface_set_material(surface_idx_door, null)
#	door_mesh.set_surface_material(surface_idx_door, outlined_material)
	var hud = game_params.get_hud()
	var inventory = hud.inventory
	var conversation = hud.conversation
	if conversation.visible:
		return ""
	return game_params.handle_player_highlight(player_node, self)

func remove_highlight(player_node):
#	door_mesh.set_surface_material(surface_idx_door, null)
	#door_mesh.mesh.surface_set_material(surface_idx_door, material)
	pass

#####

func is_player():
	return game_params.get_player().get_instance_id() == self.get_instance_id()

func become_player():
	if is_player():
		get_cam().rebuild_exceptions(self)
		return
	var player = game_params.get_player()
	var rotation_helper = get_node("Rotation_Helper")
	var camera_container = rotation_helper.get_node("Camera")
	var player_rotation_helper = player.get_node("Rotation_Helper")
	var player_camera_container = player_rotation_helper.get_node("Camera")
	var camera = player_camera_container.get_child(0)
	player_camera_container.remove_child(camera)
	camera_container.add_child(camera)
	var player_model = player.get_model()
	player_model.set_simple_mode(false)
	var model = get_model()
	model.set_simple_mode(true)
	player.reset_rotation()
	game_params.set_player_name_hint(name_hint)
	camera.rebuild_exceptions(self)

func reset_rotation():
	rotation_helper.set_rotation_degrees(Vector3(0, 0, 0))
	get_model_holder().set_rotation_degrees(Vector3(0, 0, 0))
	upper_body_shape.set_rotation_degrees(Vector3(-90, 0, 0))

func _ready():
	exclusions.append(self)
	exclusions.append(floor_node)
	exclusions.append($UpperBody_CollisionShape)  # looks like it is not included, but to be sure...
	exclusions.append($Body_CollisionShape)
	exclusions.append($Feet_CollisionShape)
	if initial_player:
		var camera = load("res://camera.tscn").instance()
		get_cam_holder().add_child(camera)
		camera.rebuild_exceptions(self)
		game_params.set_player_name_hint(name_hint)
	var model_container = get_node("Model")
	var placeholder = get_node("placeholder")
	placeholder.visible = false  # placeholder.queue_free() breaks directional shadows for some weird reason :/
	var model = load(model_path).instance()
	model.set_simple_mode(initial_player)
	model_container.add_child(model)
	game_params.register_player(self)

func remove_item_from_hand():
	get_model().remove_item_from_hand()

func join_party():
	game_params.join_party(name_hint)
	dir = Vector3()
	angle_rad_x = 0
	angle_rad_y = 0

func set_simple_mode(enable):
	get_model().set_simple_mode(enable)

func rest():
	get_model().look(0)

func play_cutscene(cutscene_id):
	get_model().play_cutscene(cutscene_id)

func stop_cutscene():
	get_model().stop_cutscene()

func leave_party():
	game_params.leave_party(name_hint)

func is_in_party():
	return game_params.is_in_party(name_hint)

func is_cutscene():
	return get_model().is_cutscene()

func set_target_node(node):
	target_node = node

func get_preferred_target():
	return target_node if not is_in_party() else (game_params.get_companion() if is_player() else game_params.get_player())

func get_target_position():
	var t = get_preferred_target()
	return t.get_global_transform().origin if t else null

func teleport(node_to):
	if node_to:
		set_global_transform(node_to.get_global_transform())

func _physics_process(delta):
	var in_party = is_in_party()
	if is_low_ceiling() and not is_crouching and is_on_floor():
		toggle_crouch()
	if is_player() and in_party:
		if cutscene_manager.is_cutscene():
			dir = Vector3()
			$SoundWalking.stop()
			var target_position = get_target_position()
			if not target_position:
				return
			var p = get_follow_parameters(target_position, get_global_transform(), target_position)
			var rotation_angle = p.rotation_angle
			var rotation_angle_to_target_deg = p.rotation_angle_to_target_deg
			angle_rad_y = 0
			if rotation_angle > 0.1:
				angle_rad_y = deg2rad(KEY_LOOK_SPEED_FACTOR * MOUSE_SENSITIVITY)
			elif rotation_angle < -0.1:
				angle_rad_y = deg2rad(KEY_LOOK_SPEED_FACTOR * MOUSE_SENSITIVITY * -1)
			if angle_rad_y == 0:
				companion_state = COMPANION_STATE.REST
				get_model().look(rotation_angle_to_target_deg)
			else:
				companion_state = COMPANION_STATE.WALK
				get_model().walk(rotation_angle_to_target_deg, is_crouching, is_sprinting)
		else:
			process_input(delta)
	else:
		if is_cutscene() and in_party:
			return
		var target_position = get_target_position()
		if not target_position:
			return
		var current_transform = get_global_transform()
		var current_position = current_transform.origin
		build_path(target_position, in_party)
		follow(current_transform, path.front() if path.size() > 0 else target_position)
	
	process_movement(delta)
	process_rotation()

func process_input(delta):

	# ----------------------------------
	# Walking
	dir = Vector3()
	var camera = get_cam_holder().get_node("camera")
	var cam_xform = camera.get_global_transform()

	var input_movement_vector = Vector2()

	if Input.is_action_pressed("movement_forward"):
		input_movement_vector.y += 1
	if Input.is_action_pressed("movement_backward"):
		input_movement_vector.y -= 1
	if Input.is_action_pressed("movement_left"):
		input_movement_vector.x -= 1
	if Input.is_action_pressed("movement_right"):
		input_movement_vector.x += 1

	input_movement_vector = input_movement_vector.normalized()

	dir += -cam_xform.basis.z.normalized() * input_movement_vector.y
	dir += cam_xform.basis.x.normalized() * input_movement_vector.x
	# ----------------------------------

	# ----------------------------------
	# Jumping
	if is_on_floor():
		if Input.is_action_just_pressed("movement_jump"):
			vel.y = JUMP_SPEED
			is_in_jump = true
		else:
			if is_in_jump:
				$SoundFallingToFloor.play()
				is_in_jump = false
	# ----------------------------------
	
	# ----------------------------------
	# Sprinting
	if Input.is_action_pressed("movement_sprint"):
		set_sprinting(true)
	else:
		set_sprinting(false)
	# ----------------------------------
	
	# ----------------------------------
	# Crouching on/off
	if Input.is_action_just_pressed("crouch"):
		toggle_crouch()
	# ----------------------------------

func set_sprinting(enable):
	is_sprinting = enable
	var is_player = is_player()
	if is_player:
		var companions = game_params.get_companions()
		for companion in companions:
			companion.set_sprinting(enable)

func is_low_ceiling():
	# Make sure you've set proper collision layer bit for ceiling
	return standing_area.get_overlapping_bodies().size() > 0

func toggle_crouch():
	stand_up() if is_crouching else sit_down()

func process_movement(delta):
	dir.y = 0
	dir = dir.normalized()

	vel.y += delta*GRAVITY

	var hvel = vel
	hvel.y = 0

	var target = dir
	if is_sprinting:
		target *= MAX_SPRINT_SPEED
	else:
		target *= MAX_SPEED

	var accel
	if dir.dot(hvel) > 0:
		if is_sprinting:
			accel = SPRINT_ACCEL
		else:
			accel = ACCEL
	else:
		accel = DEACCEL

	hvel = hvel.linear_interpolate(target, accel*delta)
	vel.x = hvel.x
	vel.z = hvel.z
	var is_moving = is_in_jump or vel.x > MIN_MOVEMENT or vel.x < -MIN_MOVEMENT or vel.z > MIN_MOVEMENT or vel.z < -MIN_MOVEMENT
	if not is_moving:
		$SoundWalking.stop()
		is_walking = false
		if is_player_controlled():
			if detail_timer.is_stopped():
				detail_timer.start()
			get_model().look(0)
		return
	
	if not $SoundWalking.is_playing():
		$SoundWalking.play()
	$SoundWalking.pitch_scale = 2 if is_sprinting else 1

	vel = move_and_slide_with_snap(vel, ZERO_DIR if is_in_jump else UP_DIR, UP_DIR, true, 4, deg2rad(MAX_SLOPE_ANGLE), is_in_party())
	is_walking = vel.length() > MIN_MOVEMENT
	
	var sc = get_slide_count()
	var character_collisions = []
	var nonchar_collision = null
	var characters = [] if sc == 0 else game_params.get_characters()
	for i in range(0, sc):
		var collision = get_slide_collision(i)
		var has_char_collision = false
		for character in characters:
			if collision.collider_id == character.get_instance_id():
				has_char_collision = true
				character_collisions.append(collision)
				break
		if not has_char_collision and not collision.collider.get_collision_mask_bit(2):
			nonchar_collision = collision
	for collision in character_collisions:
		var character = collision.collider
		if not character.is_cutscene() and not character.is_player_controlled():
			character.vel = -collision.normal * PUSH_STRENGTH
			character.vel.y = 0

	if is_player_controlled():
		if is_walking:
			if character_collisions.empty() and not nonchar_collision:
				detail_timer.stop()
				get_cam().set_detailed_mode(false)
			get_model().walk(0, is_crouching, is_sprinting)
		else:
			if detail_timer.is_stopped():
				detail_timer.start()
			get_model().look(0)
	elif nonchar_collision and pathfinding_enabled:
		var n = nonchar_collision.normal
		n.y = 0
		var cross = UP_DIR.cross(n)
		var coeff = rand_range(-NONCHAR_COLLISION_RANGE_MAX, NONCHAR_COLLISION_RANGE_MAX)
		vel = (n + coeff * cross) * PUSH_STRENGTH
		clear_path()
		var current_position = get_global_transform().origin
		var target_position = get_target_position()
		update_navpath(current_position, target_position)

func _on_DetailTimer_timeout():
	if is_player_controlled():
		get_cam().set_detailed_mode(true)

func is_player_controlled():
	return is_in_party() and is_player()

func set_sound_walk(mode):
	var spl = $SoundWalking
	spl.stop()
	spl.stream = sound[mode] if sound.has(mode) else null
	spl.set_unit_db(0)

func shadow_casting_enable(enable):
	common_utils.shadow_casting_enable(self, enable)
