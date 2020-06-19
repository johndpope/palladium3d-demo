extends PLDPlayerModel
class_name PLDFemaleModel

const FEMALE_CUTSCENE_STAND_UP_STUMP = 1
const FEMALE_TAKES_APATA = 2

func _ready():
	game_params.connect("item_taken", self, "_on_item_taken")

func _on_item_taken(nam, count):
	if main_skeleton == "Female_palladium_armature" and game_params.story_vars.apata_trap_stage == game_params.ApataTrapStages.ARMED: # Apply only to female model and only when the trap is still armed
		if nam == "statue_apata":
			var att = get_node("Female_palladium_armature/RightHandAttachment/Position3D")
			var item = load("res://assets/statue_4.escn").instance() #load(game_params.ITEMS[nam].model_path).instance()
			item.set_scale(Vector3(8, 8, 8))
			att.add_child(item)

func remove_item_from_hand():
	var att = get_node("Female_palladium_armature/RightHandAttachment/Position3D")
	for ch in att.get_children():
		att.remove_child(ch)
		ch.queue_free()