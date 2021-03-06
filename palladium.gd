extends PLDLevel

var player_toggle_enable = true

func do_init(is_loaded):
	game_state.stop_music()
	player.set_sound_walk(PLDCharacterNodes.SoundId.SOUND_WALK_CONCRETE)
	player_female.set_sound_walk(PLDCharacterNodes.SoundId.SOUND_WALK_CONCRETE)
	player_bandit.set_sound_walk(PLDCharacterNodes.SoundId.SOUND_WALK_CONCRETE)
	if has_node("greek_skeleton"):
		get_node("greek_skeleton").set_sound_walk(PLDCharacterNodes.SoundId.SOUND_WALK_CONCRETE)
	if has_node("minotaur"):
		get_node("minotaur").set_sound_walk(PLDCharacterNodes.SoundId.SOUND_WALK_MINOTAUR)
	if not conversation_manager.conversation_is_in_progress("004_TorchesIgnition") and conversation_manager.conversation_is_not_finished("004_TorchesIgnition"):
		get_tree().call_group("torches", "enable", false, false)
	game_state.connect("shader_cache_processed", self, "_on_shader_cache_processed")

func _on_shader_cache_processed():
	game_state.get_hud().queue_popup_message("MESSAGE_CONTROLS_FLASHLIGHT", ["F"])

func _unhandled_input(event):
	if not player_toggle_enable:
		return
	if event is InputEventKey:
		match event.scancode:
			KEY_9:
				player.become_player()
			KEY_0:
				player_female.become_player()
