extends Spatial

func look(look_angle_deg):
	var angle = look_angle_deg if abs(look_angle_deg) < 90.0 else (90.0 if look_angle_deg > 0 else -90.0)
	$AnimationTree.set("parameters/Transition/current", 0)
	$AnimationTree.set("parameters/Blend2_Head/blend_amount", 0.5 + 0.5 * (look_angle_deg / 90.0))

func walk(look_angle_deg):
	var angle = look_angle_deg if abs(look_angle_deg) < 90.0 else (90.0 if look_angle_deg > 0 else -90.0)
	$AnimationTree.set("parameters/Transition/current", 1)
	$AnimationTree.set("parameters/Blend2_Head/blend_amount", 0.5 + 0.5 * (look_angle_deg / 90.0))