extends Node

signal conversation_started(player, conversation_name, is_cutscene)
signal conversation_finished(player, conversation_name, is_cutscene)

const VOWELS = ["А", "Е", "Ё", "И", "О", "У", "Ы", "Э", "Ю", "Я"]
const CONSONANTS =           ["Б", "В", "Г", "Д", "Ж", "З", "К", "Л", "М", "Н", "П", "Р", "С", "Т", "Ф", "Х", "Ц", "Ч", "Ш", "Щ"]
const CONSONANTS_EXCLUSIONS =[          "Г", "Д",           "К",           "Н",      "Р",      "Т",      "Х"]
const SPECIALS = ["Ь", "Ъ", "Й"]
const STOPS = [".", "!", "?", ";", ":"]
const MINIMUM_AUTO_ADVANCE_TIME_SEC = 1.8

var conversation_name
var is_cutscene
var cutscene_node
var in_choice
var max_choice = 0

var story_state_cache = {}

func _ready():
	conversation_name = null
	is_cutscene = false
	in_choice = false
	story_state_cache.clear()

func change_stretch_ratio(conversation):
	var conversation_text_prev = conversation.get_node("VBox/VBoxText/HBoxTextPrev/ConversationText")
	var conversation_text = conversation.get_node("VBox/VBoxText/HBoxText/ConversationText")
	var stretch_ratio = 7
	conversation_text_prev.set("size_flags_stretch_ratio", stretch_ratio)
	conversation_text.set("size_flags_stretch_ratio", stretch_ratio)

func borrow_camera(player, cutscene_node):
	var player_camera_holder = player.get_cam_holder()
	if player_camera_holder.get_child_count() == 0:
		# Do nothing if player has no camera. It looks like we are in cutscene already.
		return
	var camera = player_camera_holder.get_child(0)
	camera.enable_use(false)
	self.cutscene_node = cutscene_node
	if not cutscene_node:
		return
	player.reset_rotation()
	player.set_simple_mode(false)
	player_camera_holder.remove_child(camera)
	cutscene_node.add_child(camera)

func restore_camera(player):
	var player_camera_holder = player.get_cam_holder()
	if not cutscene_node:
		var camera = player_camera_holder.get_child(0)
		camera.enable_use(true)
		return
	player.set_simple_mode(true)
	var camera = cutscene_node.get_child(0)
	cutscene_node.remove_child(camera)
	player_camera_holder.add_child(camera)
	camera.enable_use(true)
	cutscene_node = null

func get_cam():
	return cutscene_node.get_child(0) if cutscene_node and cutscene_node.get_child_count() > 0 else null

func start_area_cutscene(conversation_name, cutscene_node = null):
	var player = game_params.get_player()
	if not conversation_manager.conversation_is_in_progress() and conversation_manager.conversation_is_not_finished(player, conversation_name):
		player.rest()
		conversation_manager.start_conversation(player, conversation_name, true, cutscene_node)

func start_area_conversation(conversation_name):
	var player = game_params.get_player()
	if not conversation_manager.conversation_is_in_progress() and conversation_manager.conversation_is_not_finished(player, conversation_name):
		conversation_manager.start_conversation(player, conversation_name)

func stop_conversation(player):
	for companion in game_params.get_companions():
		companion.set_speak_mode(false)
	var conversation_name_prev = conversation_name
	var is_cutscene_prev = is_cutscene
	conversation_name = null
	is_cutscene = false
	restore_camera(player)
	var hud = game_params.get_hud()
	hud.conversation.visible = false
	hud.quick_items_panel.visible = true
	emit_signal("conversation_finished", player, conversation_name_prev, is_cutscene_prev)

func conversation_is_in_progress(conversation_name = null):
	if not conversation_name:
		# Will return true if ANY conversation is in progress
		return self.conversation_name != null
	return self.conversation_name == conversation_name

func conversation_is_cutscene():
	return conversation_is_in_progress() and is_cutscene

func conversation_is_finished(player, conversation_name):
	return not conversation_is_not_finished(player, conversation_name)

func conversation_is_not_finished(player, conversation_name):
	return check_story_not_finished(player, conversation_name)

func check_story_not_finished(player, conversation_name):
	var story = StoryNode
	var cp_player = "%s/%s.ink.json" % [player.name_hint, conversation_name]
	var cp_story
	if story_state_cache.has(cp_player):
		cp_story = story_state_cache.get(cp_player)
	else:
		var locale = TranslationServer.get_locale()
		var f = File.new()
		var exists_cp_player = f.file_exists("ink-scripts/%s/%s" % [locale, cp_player])
		var cp = "%s.ink.json" % conversation_name
		var exists_cp = f.file_exists("ink-scripts/%s/%s" % [locale, cp])
		cp_story = cp_player if exists_cp_player else (cp if exists_cp else "Default.ink.json")
		story_state_cache[cp_player] = cp_story
	return story.CheckStoryNotFinished("ink-scripts", cp_story)

func init_story(player, conversation, conversation_name):
	var locale = TranslationServer.get_locale()
	var story = StoryNode
	var f = File.new()
	var cp_player = "%s/%s.ink.json" % [player.name_hint, conversation_name]
	var exists_cp_player = f.file_exists("ink-scripts/%s/%s" % [locale, cp_player])
	var cp = "%s.ink.json" % conversation_name
	var exists_cp = f.file_exists("ink-scripts/%s/%s" % [locale, cp])
	story.LoadStory("ink-scripts", cp_player if exists_cp_player else (cp if exists_cp else "Default.ink.json"), false)
	story.InitVariables(game_params, game_params.story_vars, game_params.party)
	return story

func get_conversation_sound_path(player, conversation_name):
	var locale = "ru" if settings.vlanguage == settings.VLANGUAGE_RU else ("en" if settings.vlanguage == settings.VLANGUAGE_EN else null)
	if not locale:
		return null
	var csp_player = "sound/dialogues/%s/%s/%s/" % [locale, player.name_hint, conversation_name]
	var dir = Directory.new()
	if dir.dir_exists(csp_player):
		return csp_player
	var csp = "sound/dialogues/%s/root/%s/" % [locale, conversation_name]
	if dir.dir_exists(csp):
		return csp
	return null

func conversation_active():
	return conversation_name and conversation_name.length() > 0

func start_conversation(player, conversation_name, is_cutscene = false, cutscene_node = null):
	if self.conversation_name == conversation_name:
		return
	emit_signal("conversation_started", player, conversation_name, is_cutscene)
	self.conversation_name = conversation_name
	self.is_cutscene = is_cutscene
	borrow_camera(player, cutscene_node)
	var hud = game_params.get_hud()
	hud.quick_items_panel.visible = false
	hud.inventory.visible = false
	var conversation = hud.conversation
	conversation.visible = true
	max_choice = 0
	var story = init_story(player, conversation, conversation_name)
	clear_actors_and_texts(player, story, conversation)
	story_proceed(player)

func clear_actors_and_texts(player, story, conversation):
	var conversation_text = conversation.get_node("VBox/VBoxText/HBoxText/ConversationText")
	var conversation_text_prev = conversation.get_node("VBox/VBoxText/HBoxTextPrev/ConversationText")
	conversation_text_prev.text = ""
	var conversation_actor = conversation.get_node("VBox/VBoxText/HBoxText/ActorName")
	var conversation_actor_prev = conversation.get_node("VBox/VBoxText/HBoxTextPrev/ActorName")
	conversation_actor_prev.text = ""
	var tags = story.GetCurrentTags(TranslationServer.get_locale())
	var cur_text = story.CurrentText(TranslationServer.get_locale())
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
	var conversation = game_params.get_hud().conversation
	var conversation_text = conversation.get_node("VBox/VBoxText/HBoxText/ConversationText")
	var conversation_actor = conversation.get_node("VBox/VBoxText/HBoxText/ActorName")
	var story = StoryNode
	if not story.CanChoose() and not story.CanContinue() and idx == 0:
		stop_conversation(player)
	elif story.CanChoose() and max_choice > 0 and idx < max_choice:
		move_current_text_to_prev(conversation)
		clear_choices(story, conversation)
		story.Choose(idx)
		if story.CanContinue():
			var texts = story.Continue(true)
			conversation_text.text = texts[TranslationServer.get_locale()].strip_edges()
			var tags_dict = story.GetCurrentTags()
			var tags = tags_dict[TranslationServer.get_locale()]
			var finalizer = tags and tags.has("finalizer")
			if finalizer:
				stop_conversation(player)
				return
			var actor_name = tags["actor"] if not finalizer and tags and tags.has("actor") else player.name_hint
			conversation_actor.text = tr(actor_name) + ": "
			var vtags = get_vvalue(tags_dict)
			if vtags and vtags.has("voiceover"):
				var conversation_target = game_params.get_companion(actor_name)
				conversation_target.set_speak_mode(true)
				has_sound = play_sound_and_start_lipsync(player, conversation_target, vtags["voiceover"], null) # no lipsync for choices
				in_choice = true
			change_stretch_ratio(conversation)
		if not has_sound:
			story_proceed(player)
	elif story.CanContinue():
		story_proceed(player)

func proceed_story_immediately(player):
	if $AudioStreamPlayer.is_playing():
		$AudioStreamPlayer.stop()
		story_proceed(player)

func play_sound_and_start_lipsync(player, conversation_target, file_name, phonetic):
	var conversation_sound_path = get_conversation_sound_path(player, conversation_name)
	if not conversation_sound_path:
		return false
	var ogg_file = File.new()
	ogg_file.open(conversation_sound_path + file_name, File.READ)
	var bytes = ogg_file.get_buffer(ogg_file.get_len())
	var stream = AudioStreamOGGVorbis.new()
	stream.data = bytes
	var length = stream.get_length()
	$ShortPhraseTimer.wait_time = 0.01 if length >= MINIMUM_AUTO_ADVANCE_TIME_SEC else MINIMUM_AUTO_ADVANCE_TIME_SEC - length
	$AudioStreamPlayer.stream = stream
	$AudioStreamPlayer.play()
	if phonetic:
		#print(phonetic)
		conversation_target.get_model().speak_text(phonetic, length)
	return true

func letter_vowel(letter):
	return VOWELS.has(letter.to_upper())

func letter_consonant(letter):
	return CONSONANTS.has(letter.to_upper())

func letter_stop(letter):
	return STOPS.has(letter)

func letter_skip(letter, use_exclusions):
	var l = letter.to_upper()
	return SPECIALS.has(l) or (use_exclusions and CONSONANTS_EXCLUSIONS.has(l)) or not (VOWELS.has(l) or CONSONANTS.has(l))

func letter_to_phonetic(letter, use_exclusions):
	var l = letter.to_upper()
	if letter_stop(l):
		return "..."
	if letter_skip(l, use_exclusions):
		return ""
	match l:
		"Е":
			return "Э"
		"Ё":
			return "О"
		"Ю":
			return "У"
		"Я":
			return "А"
		_:
			return letter

func text_to_phonetic(text):
	var result = ""
	var words = text.split(" ", false)
	for word in words:
		var i = 0
		var wl = word.length()
		var use_exclusions = false
		while i < wl:
			var letter = word[i]
			result = result + letter_to_phonetic(letter, use_exclusions)
			use_exclusions = true
			i = i + 1
		result = result + " "
	return result

func story_proceed(player):
	in_choice = false
	var conversation = game_params.get_hud().conversation
	var story = StoryNode
	if story.CanContinue():
		var conversation_text = conversation.get_node("VBox/VBoxText/HBoxText/ConversationText")
		move_current_text_to_prev(conversation)
		var texts = story.Continue(false)
		conversation_text.text = texts[TranslationServer.get_locale()].strip_edges()
		var conversation_actor = conversation.get_node("VBox/VBoxText/HBoxText/ActorName")
		var tags_dict = story.GetCurrentTags()
		var tags = tags_dict[TranslationServer.get_locale()]
		var actor_name = tags["actor"] if tags and tags.has("actor") else null
		conversation_actor.text = tr(actor_name) + ": " if actor_name and not conversation_text.text.empty() else ""
		var vtags = get_vvalue(tags_dict)
		if vtags and vtags.has("voiceover"):
			var text = get_vvalue(texts)
			var conversation_target = game_params.get_companion(actor_name)
			conversation_target.set_speak_mode(true)
			play_sound_and_start_lipsync(player, conversation_target, vtags["voiceover"], vtags["transcription"] if vtags.has("transcription") else (text_to_phonetic(text.strip_edges()) if text else null))
		change_stretch_ratio(conversation)
	var choices = story.GetChoices(TranslationServer.get_locale()) if story.CanChoose() else ([tr("continue_conversation")] if story.CanContinue() else [tr("end_conversation")])
	display_choices(story, conversation, choices)

func clear_choices(story, conversation):
	var ch = story.GetChoices(TranslationServer.get_locale())
	var choices = conversation.get_node("VBox/VBoxChoices").get_children()
	var i = 1
	for c in choices:
		c.text = ""
		i += 1

func display_choices(story, conversation, choices):
	var choice_nodes = conversation.get_node("VBox/VBoxChoices").get_children()
	var i = 1
	for c in choice_nodes:
		c.text = str(i) + ". " + choices[i - 1] if i <= choices.size() else ""
		i += 1
	max_choice = choices.size()

func _on_AudioStreamPlayer_finished():
	var player = game_params.get_player()
	if in_choice:
		story_proceed(player)
	elif StoryNode.CanChoose():
		var ch = StoryNode.GetChoices(TranslationServer.get_locale())
		if ch.size() == 1:
			$ShortPhraseTimer.start()

func _on_ShortPhraseTimer_timeout():
	var player = game_params.get_player()
	story_choose(player, 0)
