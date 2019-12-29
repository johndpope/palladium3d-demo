extends Spatial

export var doors_path = "../../doors/floor_demo_full"
onready var doors = get_node(doors_path)

func get_door(door_path):
	return doors.get_node(door_path)

func use_takable(player_node, takable, parent):
	var takable_id = takable.takable_id
	match takable_id:
		Takable.TakableIds.APATA:
			match game_params.story_vars.apata_trap_stage:
				game_params.ApataTrapStages.ARMED:
					get_door("door_0").close()
					get_node("ceiling_moving_1").activate()
					conversation_manager.start_conversation(player_node, game_params.get_companion(), "ApataTrap")
					game_params.story_vars.apata_trap_stage = game_params.ApataTrapStages.GOING_DOWN
				game_params.ApataTrapStages.GOING_DOWN:
					pass
				_:
					return
		Takable.TakableIds.HERMES:
			var pedestal_id = parent.pedestal_id if parent is Pedestal else Pedestal.PedestalIds.NONE
			match pedestal_id:
				Pedestal.PedestalIds.ERIDA_LOCK:
					get_door("door_8").close()
				_:
					get_door("door_5").open()

func use_pedestal(player_node, pedestal, item_nam):
	var pedestal_id = pedestal.pedestal_id
	match pedestal_id:
		Pedestal.PedestalIds.APATA:
			var hope = hope_on_apata_pedestal(pedestal)
			if item_nam == "statue_apata" and hope:
				get_node("door_3").open()
				get_node("ceiling_moving_1").pause()
				game_params.story_vars.apata_trap_stage = game_params.ApataTrapStages.PAUSED
		Pedestal.PedestalIds.MUSES:
			if not check_muses_correct(pedestal.get_parent()):
				return
			get_door("door_4").open()
			game_params.story_vars.apata_trap_stage = game_params.ApataTrapStages.DISABLED
			get_node("ceiling_moving_1").deactivate()
			get_node("door_3").close()
		Pedestal.PedestalIds.ERIDA_LOCK:
			get_door("door_8").open()

func hope_on_apata_pedestal(pedestal):
	for ch in pedestal.get_children():
		if (ch is Takable) and ch.is_present() and ch.takable_id == Takable.TakableIds.SPHERE_FOR_POSTAMENT:
			return true
	return false

func check_pedestal(pedestal, takable_id):
	var correct = false
	if not pedestal:
		return false
	for ch in pedestal.get_children():
		if (ch is Takable) and ch.is_present():
			if ch.has_id(takable_id):
				correct = true
			else:
				return false
	return correct

func check_muses_correct(base):
	var pedestal_theatre = base.get_node("pedestal_theatre")
	if not check_pedestal(pedestal_theatre, Takable.TakableIds.MELPOMENE):
		return false
	var pedestal_astronomy = base.get_node("pedestal_astronomy")
	if not check_pedestal(pedestal_astronomy, Takable.TakableIds.URANIA):
		return false
	var pedestal_history = base.get_node("pedestal_history")
	return check_pedestal(pedestal_history, Takable.TakableIds.CLIO)

func _on_AreaDeadEnd_body_entered(body):
	var player = game_params.get_player()
	var target = game_params.get_companion()
	if body.is_in_group("party") and conversation_manager.conversation_is_not_finished(player, target, "DeadEnd"):
		conversation_manager.start_conversation(player, target, "DeadEnd")

func _on_AreaApata_body_entered(body):
	var player = game_params.get_player()
	var target = game_params.get_companion()
	if game_params.story_vars.apata_trap_stage == game_params.ApataTrapStages.ARMED and body.is_in_group("party") and conversation_manager.conversation_is_not_finished(player, target, "ApataStatue"):
		conversation_manager.start_conversation(player, target, "ApataStatue")

func _on_AreaMuses_body_entered(body):
	var player = game_params.get_player()
	var target = game_params.get_companion()
	if game_params.story_vars.apata_trap_stage == game_params.ApataTrapStages.PAUSED and body.is_in_group("party") and body.is_player() and conversation_manager.conversation_is_not_finished(player, target, "Muses"):
		conversation_manager.start_conversation(player, target, "Muses")

func _on_AreaApataDone_body_entered(body):
	var player = game_params.get_player()
	var target = game_params.get_companion()
	if conversation_manager.conversation_is_finished(player, target, "ApataStatue") and body.is_in_group("party") and body.is_player() and conversation_manager.conversation_is_not_finished(player, target, "ApataDone"):
		conversation_manager.start_conversation(player, target, "ApataDone")
