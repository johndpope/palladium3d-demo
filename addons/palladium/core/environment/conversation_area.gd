tool
extends Area
class_name PLDConversationArea

const CONVERSATIONS_DELIMITER = ";"

export(Dictionary) var conversations = {}
export(NodePath) var cutscene_node_path = null
export(bool) var repeatable = false

onready var cutscene_node = get_node(cutscene_node_path) if cutscene_node_path and has_node(cutscene_node_path) else null

func _ready():
	for name_hint in DB.PARTY_DEFAULT.keys():
		if not conversations.has(name_hint):
			conversations[name_hint] = ""

func is_conversation_enabled(name_hint, conversation_idx):
	return true

func _on_conversation_area_body_entered(body):
	if Engine.editor_hint:
		return
	if not body.is_in_group("party") or game_state.is_loading():
		return
	for name_hint in conversations.keys():
		if conversations[name_hint].empty() or not game_state.is_in_party(name_hint):
			continue
		var conversations_for_name = conversations[name_hint].split(CONVERSATIONS_DELIMITER)
		for i in range(conversations_for_name.size()):
			if not is_conversation_enabled(name_hint, i):
				continue
			var conversation = conversations_for_name[i]
			if cutscene_node:
				conversation_manager.start_area_cutscene(conversation, cutscene_node, repeatable)
			else:
				conversation_manager.start_area_conversation(conversation, repeatable)
			return
