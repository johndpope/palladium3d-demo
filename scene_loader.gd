extends TextureRect

onready var progress = get_node("VBoxContainer/HBoxContainer/VBoxContainer/TextureProgress")
onready var label = get_node("VBoxContainer/HBoxContainer/VBoxContainer/ProgressLabel")
var loader = null

func _ready():
	game_params.change_music_to("loading.ogg")
	loader = ResourceLoader.load_interactive(game_params.scene_path)

func _process(delta):
	if not loader:
		return
	progress.max_value = loader.get_stage_count()
	var err = loader.poll()
	if err == ERR_FILE_EOF:
		var pscn = loader.get_resource()
		loader = null
		get_tree().change_scene_to(pscn)
	else:
		progress.value = loader.get_stage()
		label.text = "%d%%" % floor(progress.value * 100.0 / progress.max_value)