extends Spatial

export var look_anim_name = "female_rest_99"
export var walk_anim_name = "female_walk_2"

export var b0_anim_name = "b0"
export var b1_anim_name = "b1"
export var b2_anim_name = "b2"
export var b3_anim_name = "b3"
export var b4_anim_name = "b4"
export var b5_anim_name = "b5"
export var b6_anim_name = "b6"
export var b7_anim_name = "b7"
export var b8_anim_name = "b8"
export var b9_anim_name = "b9"
export var b10_anim_name = "b10"
export var b11_anim_name = "b11"
export var b12_anim_name = "b12"
export var b13_anim_name = "b13"
export var b14_anim_name = "b14"
export var b15_anim_name = "b15"
export var b16_anim_name = "b16"

var simple_mode = true

onready var speech_timer = get_node("SpeechTimer")

var speech_states = []
var speech_idx = 0

func set_simple_mode(sm):
	simple_mode = sm
	$AnimationTree.active = not simple_mode
	if simple_mode:
		look(0)

func normalize_angle(look_angle_deg):
	return look_angle_deg if abs(look_angle_deg) < 45.0 else (45.0 if look_angle_deg > 0 else -45.0)

func rotate_head(look_angle_deg):
	$AnimationTree.set("parameters/Blend2_Head/blend_amount", 0.5 + 0.5 * (normalize_angle(look_angle_deg) / 45.0))

func set_transition(t):
	var transition = $AnimationTree.get("parameters/Transition/current")
	if transition != t:
		$AnimationTree.set("parameters/Transition/current", t)
		get_anim_player().play(get_anim_name_by_transition(t))

func set_transition_lips(t):
	var transition = $AnimationTree.get("parameters/Transition_Lips/current")
	if transition != t:
		$AnimationTree.set("parameters/Transition_Lips/current", t)
		get_anim_player().play(get_anim_name_by_transition_lips(t))

func get_anim_player():
	return $AnimationTree.get_node($AnimationTree.get_animation_player())

func get_anim_name_by_transition(t):
	match t:
		0:
			return look_anim_name
		1:
			return walk_anim_name
		_:
			return look_anim_name

func get_anim_name_by_transition_lips(t):
	match t:
		0:
			return b0_anim_name
		1:
			return b1_anim_name
		2:
			return b2_anim_name
		3:
			return b3_anim_name
		4:
			return b4_anim_name
		5:
			return b5_anim_name
		6:
			return b6_anim_name
		7:
			return b7_anim_name
		8:
			return b8_anim_name
		9:
			return b9_anim_name
		10:
			return b10_anim_name
		11:
			return b11_anim_name
		12:
			return b12_anim_name
		13:
			return b13_anim_name
		14:
			return b14_anim_name
		15:
			return b15_anim_name
		16:
			return b16_anim_name
		_:
			return b0_anim_name

func look(look_angle_deg):
	if not simple_mode:
		rotate_head(look_angle_deg)
	set_transition(0)

func walk(look_angle_deg):
	if not simple_mode:
		rotate_head(look_angle_deg)
	set_transition(1)

func speak(states):
	speech_states = states
	speech_idx = 0
	set_transition_lips(0)
	speech_timer.start()

func speech_test(audio_length):
	# text = Oblako kak oblako, a balka kak lak okolo oblaka
	# phonetic = ob kak ob a bal kak lak ok ob
	var states = [
	0,
	4, 9,
	0,
	15, 3, 15,
	0,
	4, 9,
	0,
	3,
	0,
	9, 3, 7,
	0,
	15, 3, 15,
	0,
	7, 3, 15,
	0,
	4, 15,
	0,
	4, 9, 
	0
	]
	var phoneme_time = audio_length / float(states.size())
	phoneme_time = floor(phoneme_time * 100) / 100.0
	speech_timer.wait_time = phoneme_time
	speak(states)

func _process(delta):
	if not simple_mode:
		return
	var player = get_node("../../..")
	if player.is_walking:
		walk(0)
	else:
		look(0)

func _on_SpeechTimer_timeout():
	if speech_idx < speech_states.size():
		set_transition_lips(speech_states[speech_idx])
		speech_idx = speech_idx + 1
		$SpeechTimer.start()
	else:
		speech_states.clear()
		speech_idx = 0
		set_transition_lips(0)
