extends PLDPathfinder
class_name PLDCharacter

signal visibility_to_player_changed(player_node, previous_state, new_state)
signal patrolling_changed(player_node, previous_state, new_state)
signal aggressive_changed(player_node, previous_state, new_state)

const OXYGEN_DECREASE_RATE = 5
const POISON_LETHALITY_RATE = 1
const GRAVITY_DEFAULT = -6.2
const GRAVITY_UNDERWATER = -0.2
const MAX_SPEED = 3
const MAX_SPRINT_SPEED = 10
const JUMP_SPEED = 4.5
const DIVE_SPEED = 0.2
const BOB_UP_SPEED = 1.5
const ACCEL= 1.5
const DEACCEL= 16
const SPRINT_ACCEL = 4.5
const MIN_MOVEMENT = 0.01

const UP_DIR = Vector3(0, 1, 0)
const ZERO_DIR = Vector3(0, 0, 0)
const PUSH_STRENGTH = 10
const PUSH_BACK_STRENGTH = 30
const NONCHAR_PUSH_STRENGTH = 2
const NONCHAR_COLLISION_RANGE_MAX = 5.9

const MAX_SLOPE_ANGLE_RAD = deg2rad(60)
const AXIS_VALUE_THRESHOLD = 0.15

const SOUND_PATH_TEMPLATE = "res://sound/environment/%s"

enum SoundId {SOUND_WALK_NONE, SOUND_WALK_SAND, SOUND_WALK_GRASS, SOUND_WALK_CONCRETE, SOUND_WALK_MINOTAUR}

export var model_path = ""

onready var oxygen_timer = $OxygenTimer
onready var poison_timer = $PoisonTimer
onready var standing_area = $StandingArea
onready var visibility_notifier = $VisibilityNotifier
onready var sound_player_walking = $SoundWalking
onready var sound = {
	SoundId.SOUND_WALK_NONE : null,
	SoundId.SOUND_WALK_SAND : load(SOUND_PATH_TEMPLATE % "161815__dasdeer__sand-walk.ogg"),
	SoundId.SOUND_WALK_GRASS : load(SOUND_PATH_TEMPLATE % "400123__harrietniamh__footsteps-on-grass.ogg"),
	SoundId.SOUND_WALK_CONCRETE : load(SOUND_PATH_TEMPLATE % "336598__inspectorj__footsteps-concrete-a.ogg"),
	SoundId.SOUND_WALK_MINOTAUR : load(SOUND_PATH_TEMPLATE % "minotaur_walk_reverb_short.ogg")
}

var vel = Vector3()
var gravity = GRAVITY_DEFAULT

var is_hidden = false
var is_patrolling = false
var is_aggressive = false
var is_crouching = false
var is_sprinting = false
var has_floor_collision = true

func _ready():
	var model_container = get_node("Model")
	var placeholder = get_node("placeholder")
	placeholder.visible = false  # placeholder.queue_free() breaks directional shadows for some weird reason :/
	var model = load(model_path).instance()
	game_state.connect("player_underwater", self, "set_underwater")
	model.connect("character_dead", self, "_on_character_dead")
	model_container.add_child(model)
	game_state.register_player(self)

### Getting character's parts ###

func get_model_holder():
	return get_node("Model")

func get_model():
	return get_model_holder().get_child(0)

### States ###

func set_underwater(player, enable):
	if player and (player.get_instance_id() != get_instance_id()):
		return
	gravity = GRAVITY_UNDERWATER if enable else GRAVITY_DEFAULT
	vel.y = -DIVE_SPEED if enable or vel.y <= 0.0 else BOB_UP_SPEED

func activate():
	.activate()
	get_model().activate()

func is_visible_to_player():
	return visibility_notifier.is_on_screen()

func is_hidden():
	return is_hidden

func set_hidden(enable):
	is_hidden = enable
	visible = not enable
	if has_node("UpperBody_CollisionShape"):
		$UpperBody_CollisionShape.disabled = enable
	$Body_CollisionShape.disabled = enable
	$StandingArea/CollisionShape.disabled = enable
	var is_player = is_player()
	if is_player:
		var companions = game_state.get_companions()
		for companion in companions:
			companion.set_hidden(enable)

func is_patrolling():
	return is_patrolling

func set_patrolling(enable):
	var is_patrolling_prev = is_patrolling
	is_patrolling = enable
	if is_patrolling_prev != is_patrolling:
		emit_signal("patrolling_changed", self, is_patrolling_prev, is_patrolling)
	if enable:
		set_aggressive(false)

func is_aggressive():
	return is_aggressive

func set_aggressive(enable):
	var is_aggressive_prev = is_aggressive
	is_aggressive = enable
	if is_aggressive_prev != is_aggressive:
		emit_signal("aggressive_changed", self, is_aggressive_prev, is_aggressive)
	if enable:
		set_patrolling(false)

func rest():
	get_model().look(0)

func set_look_transition(force = false):
	if force \
		or conversation_manager.meeting_is_in_progress(name_hint, DB.PLAYER_NAME_HINT) \
		or conversation_manager.meeting_is_finished(name_hint, DB.PLAYER_NAME_HINT):
		get_model().set_look_transition(PLDCharacterModel.LOOK_TRANSITION_SQUATTING if is_crouching else PLDCharacterModel.LOOK_TRANSITION_STANDING)

func play_cutscene(cutscene_id):
	get_model().play_cutscene(cutscene_id)
	$CutsceneTimer.start()

func stop_cutscene():
	get_model().stop_cutscene()

func is_cutscene():
	return get_model().is_cutscene()

func is_dying():
	return get_model().is_dying()

func is_dead():
	return get_model().is_dead()

func is_taking_damage():
	return get_model().is_taking_damage()

func is_movement_disabled():
	return get_model().is_movement_disabled()

func is_player_controlled():
	return is_in_party() and is_player() and not cutscene_manager.is_cutscene()

func sit_down():
	if $AnimationPlayer.is_playing():
		return
	get_model().sit_down()
	$AnimationPlayer.play("crouch")
	var is_player = is_player()
	if is_player:
		var companions = game_state.get_companions()
		for companion in companions:
			companion.sit_down()
	is_sprinting = false
	is_crouching = true
	if is_player:
		var hud = game_state.get_hud()
		if hud:
			hud.set_crouch_indicator(true)

func is_low_ceiling():
	# Make sure you've set proper collision layer bit for ceiling
	return standing_area.get_overlapping_bodies().size() > 0

func stand_up():
	if $AnimationPlayer.is_playing():
		return
	if is_low_ceiling():
		# I.e. if the player is crouching and something is above the head, do not allow to stand up.
		return
	get_model().stand_up()
	$AnimationPlayer.play_backwards("crouch")
	var is_player = is_player()
	if is_player:
		var companions = game_state.get_companions()
		for companion in companions:
			companion.stand_up()
	is_crouching = false
	if is_player:
		var hud = game_state.get_hud()
		if hud:
			hud.set_crouch_indicator(false)

func is_crouching():
	return is_crouching

func toggle_crouch():
	stand_up() if is_crouching else sit_down()

func can_be_attacked():
	return false

func can_run():
	return true

func is_sprinting():
	return is_sprinting

func set_sprinting(enable):
	if enable and not can_run():
		return
	is_sprinting = enable
	var is_player = is_player()
	if is_player:
		var companions = game_state.get_companions()
		for companion in companions:
			companion.set_sprinting(enable)

func set_sound_walk(mode):
	sound_player_walking.stop()
	sound_player_walking.stream = sound[mode] if sound.has(mode) else null
	sound_player_walking.set_unit_db(0)

### Player/target following ###

func reset_movement():
	.reset_movement()
	set_sprinting(false)

func reset_rotation():
	.reset_rotation()
	get_model_holder().set_rotation_degrees(Vector3(0, 0, 0))

func process_rotation(need_to_update_collisions):
	if need_to_update_collisions:
		move_and_collide(ZERO_DIR)
	if angle_rad_y == 0 or is_dying():
		return false
	self.rotate_y(angle_rad_y)
	angle_rad_y = 0
	return true

func get_snap():
	return UP_DIR

func is_need_to_use_physics():
	if has_path() or is_patrolling():
		return false
	return vel.y > 0 \
		or is_player() \
		or not has_floor_collision() \
		or is_visible_to_player() \
		or is_aggressive()

func move_without_physics(vel, delta):
	var v = Vector3()
	v.x = vel.x
	v.y = 0
	v.z = vel.z
	global_translate(v * delta)
	return v

func process_movement(delta):
	var target = ZERO_DIR if is_movement_disabled() else dir
	target.y = 0
	target = target.normalized()

	vel.y += delta * gravity

	var hvel = vel
	hvel.y = 0

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
	
	if vel.y <= 0.0 and hvel.length() < MIN_MOVEMENT and has_floor_collision():
		return { "is_walking" : false, "collides_floor" : true }
	
	if is_need_to_use_physics():
		vel = move_and_slide_with_snap(
			vel,
			get_snap(),
			UP_DIR,
			true,
			4,
			MAX_SLOPE_ANGLE_RAD,
			is_in_party()
		)
	else:
		vel = move_without_physics(vel, delta)
		return { "is_walking" : true, "collides_floor" : true }
	
	var is_walking = vel.length() > MIN_MOVEMENT
	
	var sc = get_slide_count()
	var character_collisions = []
	var nonchar_collision = null
	var characters = [] if sc == 0 else game_state.get_characters()
	var collides_floor = false
	for i in range(0, sc):
		var collision = get_slide_collision(i)
		var has_char_collision = false
		for character in characters:
			if collision.collider_id == character.get_instance_id():
				has_char_collision = true
				character_collisions.append(collision)
				break
		var is_floor_collision = collision.collider.get_collision_mask_bit(2) and collision.normal and collision.normal.y > 0
		collides_floor = collides_floor or is_floor_collision
		if not has_char_collision and not is_floor_collision:
			nonchar_collision = collision
	for collision in character_collisions:
		var character = collision.collider
		if not character.is_movement_disabled() and not character.is_player_controlled():
			character.vel = get_out_vec(-collision.normal) * PUSH_STRENGTH
			character.vel.y = 0

	if nonchar_collision and pathfinding_enabled and not is_player_controlled():
		var v = get_out_vec(nonchar_collision.normal) * NONCHAR_PUSH_STRENGTH
		clear_path()
		var current_position = get_global_transform().origin
		var start_position = current_position + v
		var target_position = get_target_position()
		if target_position:
			update_navpath(start_position, target_position)
		path.push_front(start_position)
		if DRAW_PATH:
			draw_path()
	return { "is_walking" : is_walking, "collides_floor" : collides_floor }

func get_out_vec(normal):
	var n = normal
	n.y = 0
	var cross = UP_DIR.cross(n)
	var coeff = rand_range(-NONCHAR_COLLISION_RANGE_MAX, NONCHAR_COLLISION_RANGE_MAX)
	return (n + coeff * cross).normalized()

func get_push_vec(direction_node):
	if not direction_node:
		return ZERO_DIR
	var dir_z = direction_node.get_global_transform().basis.z.normalized()
	dir_z.y = 0
	return -dir_z * PUSH_BACK_STRENGTH

func push_back(push_vec):
	vel = push_vec

func has_floor_collision():
	return has_floor_collision or is_on_floor()

func can_jump():
	return has_floor_collision() or game_state.is_underwater(get_name_hint())

func do_process(delta, in_party, is_player):
	if not is_activated():
		.do_process(delta, in_party, is_player)
		return
	if is_cutscene() or is_dying() or is_dead():
		has_floor_collision = true
		.do_process(delta, in_party, is_player)
		return
	if is_low_ceiling() and not is_crouching and has_floor_collision():
		sit_down()
	var is_underwater = game_state.is_underwater(get_name_hint())
	if is_underwater and oxygen_timer.is_stopped():
		oxygen_timer.start()
	elif not is_underwater and not oxygen_timer.is_stopped():
		oxygen_timer.stop()
		game_state.set_oxygen(get_name_hint(), game_state.player_oxygen_max, game_state.player_oxygen_max)
	var is_poisoned = game_state.is_poisoned(get_name_hint())
	if is_poisoned and poison_timer.is_stopped():
		poison_timer.start()
	elif not is_poisoned and not poison_timer.is_stopped():
		poison_timer.stop()
	var movement_data = process_movement(delta)
	has_floor_collision = movement_data.collides_floor
	var is_moving = movement_data.is_walking
	var is_rotating = process_rotation(not is_moving and is_player)
	if is_moving or is_rotating:
		if not sound_player_walking.is_playing():
			sound_player_walking.play()
		sound_player_walking.pitch_scale = 2 if is_sprinting else 1
		get_model().walk(get_rotation_angle_to_target_deg(), is_crouching, is_sprinting)
	else:
		sound_player_walking.stop()
		get_model().look(get_rotation_angle_to_target_deg())
	.do_process(delta, in_party, is_player)

func _on_HealTimer_timeout():
	if is_player():
		game_state.set_health(get_name_hint(), game_state.player_health_current + DB.HEALING_RATE, game_state.player_health_max)

func _on_CutsceneTimer_timeout():
	set_look_transition(true)

func _on_OxygenTimer_timeout():
	if oxygen_timer.is_stopped():
		return
	game_state.set_oxygen(get_name_hint(), game_state.player_oxygen_current - OXYGEN_DECREASE_RATE, game_state.player_oxygen_max)

func _on_PoisonTimer_timeout():
	if poison_timer.is_stopped():
		return
	game_state.set_health(get_name_hint(), game_state.player_health_current - POISON_LETHALITY_RATE, game_state.player_health_max)

func _on_VisibilityNotifier_screen_entered():
	emit_signal("visibility_to_player_changed", self, false, true)

func _on_VisibilityNotifier_screen_exited():
	emit_signal("visibility_to_player_changed", self, true, false)
