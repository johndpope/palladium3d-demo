extends PLDPathfinder
class_name PLDCharacter

const GRAVITY = -6.2
const MAX_SPEED = 3
const MAX_SPRINT_SPEED = 10
const JUMP_SPEED = 4.5
const ACCEL= 1.5
const DEACCEL= 16
const SPRINT_ACCEL = 4.5
const MIN_MOVEMENT = 0.01

const UP_DIR = Vector3(0, 1, 0)
const ZERO_DIR = Vector3(0, 0, 0)
const PUSH_STRENGTH = 10
const NONCHAR_PUSH_STRENGTH = 2
const NONCHAR_COLLISION_RANGE_MAX = 5.9

const MAX_SLOPE_ANGLE = 60
const AXIS_VALUE_THRESHOLD = 0.15

const SOUND_PATH_TEMPLATE = "res://sound/environment/%s"

enum SoundId {SOUND_WALK_NONE, SOUND_WALK_SAND, SOUND_WALK_GRASS, SOUND_WALK_CONCRETE}

export var model_path = "res://scenes/female.tscn"

onready var standing_area = $StandingArea
onready var sound = {
	SoundId.SOUND_WALK_NONE : null,
	SoundId.SOUND_WALK_SAND : load(SOUND_PATH_TEMPLATE % "161815__dasdeer__sand-walk.ogg"),
	SoundId.SOUND_WALK_GRASS : load(SOUND_PATH_TEMPLATE % "400123__harrietniamh__footsteps-on-grass.ogg"),
	SoundId.SOUND_WALK_CONCRETE : load(SOUND_PATH_TEMPLATE % "336598__inspectorj__footsteps-concrete-a.ogg")
}

var vel = Vector3()

var is_crouching = false
var is_sprinting = false

func _ready():
	var model_container = get_node("Model")
	var placeholder = get_node("placeholder")
	placeholder.visible = false  # placeholder.queue_free() breaks directional shadows for some weird reason :/
	var model = load(model_path).instance()
	model_container.add_child(model)
	game_params.register_player(self)

### Getting character's parts ###

func get_model_holder():
	return get_node("Model")

func get_model():
	return get_model_holder().get_child(0)

### Use target ###

func add_highlight(player_node):
	return ""

func remove_highlight(player_node):
	pass

func use(player_node):
	pass

### States ###

func rest():
	get_model().look(0)

func set_look_transition(force = false):
	if force \
		or conversation_manager.meeting_is_in_progress(name_hint, game_params.PLAYER_NAME_HINT) \
		or conversation_manager.meeting_is_finished(name_hint, game_params.PLAYER_NAME_HINT):
		get_model().set_look_transition(PLDCharacterModel.LOOK_TRANSITION_SQUATTING if is_crouching else PLDCharacterModel.LOOK_TRANSITION_STANDING)

func play_cutscene(cutscene_id):
	get_model().play_cutscene(cutscene_id)
	$CutsceneTimer.start()

func stop_cutscene():
	get_model().stop_cutscene()

func is_cutscene():
	return get_model().is_cutscene()

func is_player_controlled():
	return is_in_party() and is_player() and not cutscene_manager.is_cutscene()

func sit_down():
	if $AnimationPlayer.is_playing():
		return
	get_model().sit_down()
	$AnimationPlayer.play("crouch")
	var is_player = is_player()
	if is_player:
		var companions = game_params.get_companions()
		for companion in companions:
			companion.sit_down()
	is_sprinting = false
	is_crouching = true
	if is_player:
		var hud = game_params.get_hud()
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
		var companions = game_params.get_companions()
		for companion in companions:
			companion.stand_up()
	is_crouching = false
	if is_player:
		var hud = game_params.get_hud()
		if hud:
			hud.set_crouch_indicator(false)

func is_crouching():
	return is_crouching

func toggle_crouch():
	stand_up() if is_crouching else sit_down()

func set_sprinting(enable):
	is_sprinting = enable
	var is_player = is_player()
	if is_player:
		var companions = game_params.get_companions()
		for companion in companions:
			companion.set_sprinting(enable)

func set_sound_walk(mode):
	var spl = $SoundWalking
	spl.stop()
	spl.stream = sound[mode] if sound.has(mode) else null
	spl.set_unit_db(0)

### Player/target following ###

func reset_movement():
	.reset_movement()
	set_sprinting(false)

func reset_rotation():
	.reset_rotation()
	get_model_holder().set_rotation_degrees(Vector3(0, 0, 0))

func process_rotation(need_to_update_collisions):
	if need_to_update_collisions:
		move_and_slide(-UP_DIR, UP_DIR, true, 4, deg2rad(MAX_SLOPE_ANGLE), is_in_party())
	if angle_rad_y != 0:
		self.rotate_y(angle_rad_y)
		return true
	return false

func get_snap():
	return UP_DIR

func process_movement(delta):
	var target = dir
	target.y = 0
	target = target.normalized()

	vel.y += delta*GRAVITY

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
	
	vel = move_and_slide_with_snap(vel, get_snap(), UP_DIR, true, 4, deg2rad(MAX_SLOPE_ANGLE), is_in_party())
	var is_walking = vel.length() > MIN_MOVEMENT
	
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
	return is_walking

func get_out_vec(normal):
	var n = normal
	n.y = 0
	var cross = UP_DIR.cross(n)
	var coeff = rand_range(-NONCHAR_COLLISION_RANGE_MAX, NONCHAR_COLLISION_RANGE_MAX)
	return (n + coeff * cross).normalized()

func _physics_process(delta):
	if is_cutscene():
		return
	if is_low_ceiling() and not is_crouching and is_on_floor():
		sit_down()
	var is_moving = process_movement(delta)
	var is_rotating = process_rotation(not is_moving)
	if is_moving or is_rotating:
		if not $SoundWalking.is_playing():
			$SoundWalking.play()
		$SoundWalking.pitch_scale = 2 if is_sprinting else 1
		get_model().walk(get_rotation_angle_to_target_deg(), is_crouching, is_sprinting)
	else:
		$SoundWalking.stop()
		get_model().look(get_rotation_angle_to_target_deg())

func _on_HealTimer_timeout():
	if is_player():
		game_params.set_health(name_hint, game_params.player_health_current + game_params.HEALING_RATE, game_params.player_health_max)

func _on_CutsceneTimer_timeout():
	set_look_transition(true)