extends PhysicsBody

export var item_name = "statue_urania"
export var model_path = "res://scenes/statue_1.tscn"
export var level_path = "../../../.."
export var item_in_parent = true

func use(player_node):
	if item_name == "statue_apata":
		match game_params.story_vars.apata_trap_stage:
			game_params.ApataTrapStages.ARMED:
				var level = get_node(level_path)
				level.get_door("door_0").close()
				level.get_node("ceiling_moving_1").activate()
				conversation_manager.start_conversation(player_node, game_params.get_companion(), "ApataTrap")
				game_params.story_vars.apata_trap_stage = game_params.ApataTrapStages.GOING_DOWN
			game_params.ApataTrapStages.GOING_DOWN:
				pass
			_:
				return
	elif item_name == "statue_hermes":
		var level = get_node(level_path)
		level.get_door("door_5").activate()
		level.get_door("door_8").activate()
	
	player_node.take(item_name, item_name + ".png", model_path)
	
	if item_in_parent:
		get_parent().queue_free()
	else:
		queue_free()

func add_highlight(player_node):
	#door_mesh.mesh.surface_set_material(surface_idx_door, null)
#	door_mesh.set_surface_material(surface_idx_door, outlined_material)
	if item_name == "statue_apata":
		match game_params.story_vars.apata_trap_stage:
			game_params.ApataTrapStages.PAUSED:
				continue
			game_params.ApataTrapStages.DISABLED:
				return ""
	return "E: Взять"

func remove_highlight(player_node):
#	door_mesh.set_surface_material(surface_idx_door, null)
	#door_mesh.mesh.surface_set_material(surface_idx_door, material)
	pass