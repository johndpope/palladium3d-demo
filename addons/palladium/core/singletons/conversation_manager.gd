extends Node
class_name PLDConversationManager

const MEETING_CONVERSATION_PREFIX = "Meeting_"
const MEETING_CONVERSATION_TEMPLATE = "%s%%s" % MEETING_CONVERSATION_PREFIX

signal meeting_started(player, target, initiator)
signal conversation_started(player, conversation_name, target, initiator)
signal meeting_finished(player, target, initiator)
signal conversation_finished(player, conversation_name, target, initiator)

var conversation_name
var target
var initiator
var is_finalizing
var max_choice = 0

var story_state_cache = {}

func _ready():
	conversation_name = null
	target = null
	initiator = null
	is_finalizing = false
	story_state_cache.clear()

func change_stretch_ratio(conversation):
	var conversation_text_prev = conversation.get_node("VBox/VBoxText/HBoxTextPrev/ConversationText")
	var conversation_text = conversation.get_node("VBox/VBoxText/HBoxText/ConversationText")
	var stretch_ratio = 10
	conversation_text_prev.set("size_flags_stretch_ratio", stretch_ratio)
	conversation_text.set("size_flags_stretch_ratio", stretch_ratio)

func start_area_cutscene(conversation_name, cutscene_node = null, repeatable = false):
	var player = game_state.get_player()
	if conversation_is_in_progress():
		return
	if repeatable or conversation_is_not_finished(conversation_name):
		player.rest()
		start_conversation(player, conversation_name, null, null, true, cutscene_node, repeatable)

func start_area_conversation(conversation_name, repeatable = false):
	var player = game_state.get_player()
	if conversation_is_in_progress():
		return
	if repeatable or conversation_is_not_finished(conversation_name):
		start_conversation(player, conversation_name, null, null, false, null, repeatable)

func stop_conversation(player):
	if not conversation_is_in_progress():
		# Already stopped
		return
	if not $AutocloseTimer.is_stopped():
		$AutocloseTimer.stop()
	var conversation_name_prev = conversation_name
	var target_prev = target
	var initiator_prev = initiator
	conversation_name = null
	target = null
	initiator = null
	#is_finalizing = false -- this had some troubles with the lipsync_manager, it is better to not touch it now
	var hud = game_state.get_hud()
	hud.conversation.visible = false
	hud.show_game_ui(true)
	if conversation_name_prev.find(MEETING_CONVERSATION_PREFIX) == 0:
		emit_signal("meeting_finished", player, target_prev, initiator_prev)
	player.get_cam().enable_use(true)
	emit_signal("conversation_finished", player, conversation_name_prev, target_prev, initiator_prev)

func conversation_is_in_progress(conversation_name = null, target_name_hint = null):
	if not conversation_name:
		# Will return true if ANY conversation is in progress
		return self.conversation_name != null and self.conversation_name.length() > 0
	if not target_name_hint or not target:
		return self.conversation_name == conversation_name
	return self.conversation_name == conversation_name and self.target.name_hint == target_name_hint

func meeting_is_in_progress(character1_name_hint, character2_name_hint):
	var conversation_name_1 = MEETING_CONVERSATION_TEMPLATE % character1_name_hint
	var conversation_name_2 = MEETING_CONVERSATION_TEMPLATE % character2_name_hint
	return conversation_is_in_progress(conversation_name_1, character2_name_hint) or conversation_is_in_progress(conversation_name_2, character1_name_hint)

func meeting_is_finished_exact(initiator_name_hint, target_name_hint):
	return conversation_is_finished(MEETING_CONVERSATION_TEMPLATE % initiator_name_hint, target_name_hint)

func meeting_is_finished(character1_name_hint, character2_name_hint):
	var conversation_name_1 = MEETING_CONVERSATION_TEMPLATE % character1_name_hint
	var conversation_name_2 = MEETING_CONVERSATION_TEMPLATE % character2_name_hint
	return conversation_is_finished(conversation_name_1, character2_name_hint) or conversation_is_finished(conversation_name_2, character1_name_hint)

func meeting_is_not_finished(character1_name_hint, character2_name_hint):
	return not meeting_is_finished(character1_name_hint, character2_name_hint)

func conversation_is_finished(conversation_name, target_name_hint = null):
	return not conversation_is_not_finished(conversation_name, target_name_hint)

func conversation_is_not_finished(conversation_name, target_name_hint = null):
	return check_story_not_finished(conversation_name, target_name_hint)

func check_story_not_finished(conversation_name, target_name_hint = null):
	var cp = ("%s/" % target_name_hint if target_name_hint else "") + "%s.ink.json" % conversation_name
	var cp_story
	if story_state_cache.has(cp):
		cp_story = story_state_cache.get(cp)
	else:
		var locale = TranslationServer.get_locale()
		var f = File.new()
		var exists_cp = f.file_exists("res://ink-scripts/%s/%s" % [locale, cp])
		cp_story = cp if exists_cp else "Default.ink.json"
		story_state_cache[cp] = cp_story
	return story_node.check_story_not_finished("res://ink-scripts", cp_story)

func init_story(conversation_name, target_name_hint = null, repeatable = false):
	var locale = TranslationServer.get_locale()
	var f = File.new()
	var cp = ("%s/" % target_name_hint if target_name_hint else "") + "%s.ink.json" % conversation_name
	var exists_cp = f.file_exists("res://ink-scripts/%s/%s" % [locale, cp])
	story_node.load_story("res://ink-scripts", cp if exists_cp else "Default.ink.json", false, repeatable)
	story_node.init_variables()
	return story_node

func arrange_meeting(player, target, initiator, is_cutscene = false, cutscene_node = null):
	if meeting_is_in_progress(target.name_hint, initiator.name_hint):
		return false
	if meeting_is_not_finished(target.name_hint, initiator.name_hint):
		if not initiator.is_in_party():
			initiator.join_party()
		if not target.is_in_party():
			target.join_party()
		var conversation_name = MEETING_CONVERSATION_TEMPLATE % initiator.name_hint
		emit_signal("meeting_started", player, target, initiator)
		start_conversation(player, conversation_name, target, initiator, is_cutscene, cutscene_node)
		return true
	return false

func start_conversation(player, conversation_name, target = null, initiator = null, is_cutscene = false, cutscene_node = null, repeatable = false):
	if self.conversation_name == conversation_name:
		return
	if is_cutscene:
		cutscene_manager.start_cutscene(player, cutscene_node, conversation_name, target)
	else:
		player.get_cam().enable_use(false)
	emit_signal("conversation_started", player, conversation_name, target, initiator)
	self.target = target
	self.initiator = initiator
	self.is_finalizing = false
	self.conversation_name = conversation_name
	var hud = game_state.get_hud()
	hud.show_game_ui(false)
	var conversation = hud.conversation
	conversation.visible = true
	max_choice = 0
	var story = init_story(conversation_name, target.name_hint if target else null, repeatable)
	clear_actors_and_texts(player, conversation)
	story_proceed(player)

func clear_actors_and_texts(player, conversation):
	var conversation_text = conversation.get_node("VBox/VBoxText/HBoxText/ConversationText")
	var conversation_text_prev = conversation.get_node("VBox/VBoxText/HBoxTextPrev/ConversationText")
	conversation_text_prev.text = ""
	var conversation_actor = conversation.get_node("VBox/VBoxText/HBoxText/ActorName")
	var conversation_actor_prev = conversation.get_node("VBox/VBoxText/HBoxTextPrev/ActorName")
	conversation_actor_prev.text = ""
	var tags = story_node.get_current_tags_for_locale(TranslationServer.get_locale())
	var cur_text = story_node.current_text(TranslationServer.get_locale())
	if tags.has("finalizer") or cur_text.empty():
		conversation_text.text = ""
		conversation_actor.text = ""
	else:
		conversation_text.text = cur_text
		var actor_name = tags["actor"] if tags and tags.has("actor") else player.name_hint
		conversation_actor.text = tr(actor_name) + ": "

func move_current_text_to_prev(conversation):
	var conversation_text = conversation.get_node("VBox/VBoxText/HBoxText/ConversationText")
	var conversation_text_prev = conversation.get_node("VBox/VBoxText/HBoxTextPrev/ConversationText")
	conversation_text_prev.text = conversation_text.text
	conversation_text.text = ""
	var conversation_actor = conversation.get_node("VBox/VBoxText/HBoxText/ActorName")
	var conversation_actor_prev = conversation.get_node("VBox/VBoxText/HBoxTextPrev/ActorName")
	conversation_actor_prev.text = conversation_actor.text
	conversation_actor.text = ""

func get_vvalue(dict):
	return dict["ru"] if settings.vlanguage == settings.VLANGUAGE_RU else (dict["en"] if settings.vlanguage == settings.VLANGUAGE_EN else null)

func story_choose(player, idx):
	var has_sound = false
	var conversation = game_state.get_hud().conversation
	var conversation_text = conversation.get_node("VBox/VBoxText/HBoxText/ConversationText")
	var conversation_actor = conversation.get_node("VBox/VBoxText/HBoxText/ActorName")
	lipsync_manager.stop_sound_and_lipsync()  # If the character has not finished speaking, but the player already decided to continue dialogue
	if is_finalizing or (not story_node.can_choose() and not story_node.can_continue() and idx == 0):
		stop_conversation(player)
	elif story_node.can_choose() and max_choice > 0 and idx < max_choice:
		move_current_text_to_prev(conversation)
		clear_choices(conversation)
		story_node.choose(idx)
		if story_node.can_continue():
			var texts = story_node.continue(true)
			conversation_text.text = texts[TranslationServer.get_locale()].strip_edges()
			var tags_dict = story_node.get_current_tags()
			var tags = tags_dict[TranslationServer.get_locale()]
			is_finalizing = tags and tags.has("finalizer")
			if is_finalizing:
				stop_conversation(player)
				return
			var actor_name = tags["actor"] if tags and tags.has("actor") else player.name_hint
			conversation_actor.text = tr(actor_name) + ": " if actor_name else ""
			var vtags = get_vvalue(tags_dict)
			if vtags and vtags.has("voiceover"):
				var character = game_state.get_character(actor_name)
				has_sound = lipsync_manager.play_sound_and_start_lipsync(character, conversation_name, target.name_hint if target else null, vtags["voiceover"]) # no lipsync for choices
			change_stretch_ratio(conversation)
		conversation.visible = settings.need_subtitles() or not has_sound
		if not has_sound:
			story_proceed(player)
	elif story_node.can_continue():
		story_proceed(player)

func proceed_story_immediately(player):
	if $AudioStreamPlayer.is_playing():
		$AudioStreamPlayer.stop()
		story_proceed(player)

func story_proceed(player):
	var conversation = game_state.get_hud().conversation
	var has_voiceover = false
	if story_node.can_continue():
		var conversation_text = conversation.get_node("VBox/VBoxText/HBoxText/ConversationText")
		move_current_text_to_prev(conversation)
		var texts = story_node.continue(false)
		conversation_text.text = texts[TranslationServer.get_locale()].strip_edges()
		var conversation_actor = conversation.get_node("VBox/VBoxText/HBoxText/ActorName")
		var tags_dict = story_node.get_current_tags()
		var tags = tags_dict[TranslationServer.get_locale()]
		is_finalizing = tags and tags.has("finalizer")
		var actor_name = tags["actor"] if tags and tags.has("actor") else player.name_hint
		conversation_actor.text = tr(actor_name) + ": " if actor_name and not conversation_text.text.empty() else ""
		var vtags = get_vvalue(tags_dict)
		has_voiceover = vtags and vtags.has("voiceover")
		if has_voiceover:
			# For simplicity, we are always using Russian text to autocreate lipsync
			# To get more correct representation of English phonemes, you can use 'transcription' tag in the Ink file
			# TODO: Alternatively, code for lipsync autocreation from English text should be written
			var text = texts["ru"] #get_vvalue(texts)
			var character = game_state.get_companion(actor_name)
			lipsync_manager.play_sound_and_start_lipsync(character, conversation_name, target.name_hint if target else null, vtags["voiceover"], text, vtags["transcription"] if vtags.has("transcription") else null)
		change_stretch_ratio(conversation)
	var can_continue = not is_finalizing and story_node.can_continue()
	var can_choose = not is_finalizing and story_node.can_choose()
	var choices = story_node.get_choices(TranslationServer.get_locale()) if can_choose else ([tr("CONVERSATION_CONTINUE")] if can_continue else [tr("CONVERSATION_END")])
	if not can_continue and not can_choose and not has_voiceover:
		$AutocloseTimer.start()
	conversation.visible = settings.need_subtitles() or can_choose or not has_voiceover
	display_choices(conversation, choices)

func is_finalizing():
	return is_finalizing

func clear_choices(conversation):
	var ch = story_node.get_choices(TranslationServer.get_locale())
	var choices = conversation.get_node("VBox/VBoxChoices").get_children()
	var i = 1
	for c in choices:
		c.text = ""
		i += 1

func display_choices(conversation, choices):
	var choice_nodes = conversation.get_node("VBox/VBoxChoices").get_children()
	var i = 1
	for c in choice_nodes:
		c.text = str(i) + ". " + choices[i - 1] if i <= choices.size() else ""
		i += 1
	max_choice = choices.size()

func _on_AutocloseTimer_timeout():
	var player = game_state.get_player()
	stop_conversation(player)
