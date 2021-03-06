extends Spatial
class_name PLDRiddle

signal riddle_error(riddle)
signal riddle_success(riddle)

export(DB.RiddleIds) var riddle_id = DB.RiddleIds.NONE

func connect_signals(target):
	connect("riddle_success", target, "_on_riddle_success")
