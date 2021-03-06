extends PLDUsable
class_name PLDUseTarget

export var remove_on_use = true
export var matched_item_names : PoolStringArray = PoolStringArray()

func use(player_node, camera_node):
	var hud = game_state.get_hud()
	if hud and hud.get_active_item():
		var item = hud.get_active_item()
		if not item_match(item):
			return
		hud.inventory.visible = false
		item.used(player_node, self)
		if use_action(player_node, item) and remove_on_use:
			item.remove()

func use_action(player_node, item):
	return true

func item_match(item):
	if not item:
		return false
	for item_name in matched_item_names:
		if item_name == DB.get_item_name(item.item_id):
			return true
	return false

func add_highlight(player_node):
	var hud = game_state.get_hud()
	if hud and hud.get_active_item():
		var item = hud.get_active_item()
		if item_match(item):
			return "E: " + get_use_action_text(player_node)
	return ""

func get_use_action_text(player_node):
	return tr("ACTION_USE")
