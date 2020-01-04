extends Spatial
class_name Door

enum DoorIds {
	NONE = 0,
	APATA_TRAP_INNER = 10,
	APATA_SAVE_INNER = 20,
	APATA_SAVE_OUTER = 30,
	ERIDA_TRAP_INNER = 40,
	DEMO_FINISH = 50
}
export(DoorIds) var door_id = DoorIds.NONE
export var initially_opened = false
export var door_collision_path = "StaticBody/CollisionShape"
export var anim_player_path = "door_4_armature001/AnimationPlayer"
export var anim_name_open = "door_4_armatureAction.001"

onready var anim_player = get_node(anim_player_path)
onready var door_collision = get_node(door_collision_path)

func _ready():
	restore_state()

func open():
	anim_player.play(anim_name_open)
	door_collision.disabled = true
	game_params.set_door_state(get_path(), true)

func close():
	anim_player.play_backwards(anim_name_open)
	door_collision.disabled = false
	game_params.set_door_state(get_path(), false)

func restore_state():
	var state = game_params.get_door_state(get_path())
	if state == game_params.DoorState.DEFAULT:
		if initially_opened:
			open()
		return
	if state == game_params.DoorState.OPENED:
		open()
	else:
		close()
