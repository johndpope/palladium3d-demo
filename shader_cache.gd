extends Spatial
class_name ShaderCache

const SHADER_CACHE_ENABLED = true
const SHADER_CACHE_HIDING_ENABLED = true
const SHADER_CACHE_IGNORE_SKELETONS = false
const STEP = 0.02
const HALFROW = 10

onready var holder1 = get_node("shader_cache_holder1")
onready var holder2 = get_node("shader_cache_holder2")
onready var label_container = get_node("HBoxContainer")

var stage = 0

func _ready():
	#refresh() -- will be called on settings ready
	pass

func get_cacheable_items(scn, ignore_skeletons):
	var result = []
	if scn is MeshInstance:
		var sk = null if ignore_skeletons else scn.get_node(scn.get_skeleton_path())
		# Adding materials from MeshInstance's surfaces, if any
		var sc = scn.get_surface_material_count()
		for i in range(0, sc):
			var mat = scn.get_surface_material(i)
			if mat:
				result.append({"material": mat, "skeleton": sk if sk is Skeleton else null, "particles_material": null})
		# Adding materials from MeshInstance's meshes' surfaces, if any
		var mesh = scn.mesh
		if mesh and mesh is Mesh:
			var sc_mesh = mesh.get_surface_count()
			for j in range(0, sc_mesh):
				var mat = mesh.surface_get_material(j)
				if mat:
					result.append({"material": mat, "skeleton": sk if sk is Skeleton else null, "particles_material": null})
	elif scn is Particles:
		var pmat = scn.get_process_material()
		# TODO: add another draw pass materials if they will be used
		var mesh = scn.draw_pass_1
		if mesh and mesh is Mesh:
			var sc_mesh = mesh.get_surface_count()
			for j in range(0, sc_mesh):
				var mat = mesh.surface_get_material(j)
				if mat:
					result.append({"material": mat, "skeleton": null, "particles_material": pmat})

	for ch in scn.get_children():
		var items = get_cacheable_items(ch, ignore_skeletons)
		for item in items:
			result.append(item)
	return result

func make_asset(pos, material, skeleton_path):
	var skeleton = get_node(skeleton_path).duplicate(Node.DUPLICATE_USE_INSTANCING) if skeleton_path else null
	if skeleton:
		skeleton.set_transform(Transform())
		var aabb = AABB(Vector3(0, 0, 0), Vector3(STEP, STEP, STEP))
		for skeleton_child in skeleton.get_children():
			if skeleton_child is VisualInstance:
				aabb = aabb.merge(skeleton_child.get_aabb())
		var size = aabb.size
		skeleton.set_scale(Vector3(STEP / (2 * size.x), STEP / (2 * size.y), STEP / (2 * size.z)))
		holder1.add_child(skeleton)
		skeleton.global_translate(Vector3(pos.x, pos.y, 0))
		for ch in skeleton.get_children():
			if ch is AnimationPlayer:
				var anim_list = ch.get_animation_list()
				for anim in anim_list:
					ch.play(anim)
	else:
		var asset = MeshInstance.new()
		var mname = material.get_name()
		if not mname.empty():
			asset.set_name(mname)
		asset.mesh = SphereMesh.new()
		asset.mesh.radius = STEP / 4.0
		asset.mesh.height = STEP / 2.0
		asset.mesh.set_material(material)
		holder1.add_child(asset)
		asset.translate(Vector3(pos.x, pos.y, 0))
	pos.x = pos.x + STEP
	if pos.x > STEP * HALFROW:
		pos.x = -STEP * HALFROW
		pos.y = pos.y + STEP
	return pos

func make_particles(pos, particles_material, material):
	var particles = Particles.new()
	particles.set_name(particles_material.get_name() + "_" + material.get_name())
	particles.draw_pass_1 = SphereMesh.new()
	particles.draw_pass_1.radius = STEP / 4.0
	particles.draw_pass_1.height = STEP / 2.0
	holder1.add_child(particles)
	particles.translate(Vector3(pos.x, pos.y, 0))
	pos.x = pos.x + STEP
	if pos.x > STEP * HALFROW:
		pos.x = -STEP * HALFROW
		pos.y = pos.y + STEP
	particles.draw_pass_1.set_material(material)
	particles.set_process_material(particles_material)
	particles.emitting = true
	particles.restart()
	return pos

func add_material_meshes(pos, scn):
	pos.x = pos.x + STEP / 2.0
	pos.y = pos.y + STEP / 2.0
	var items = get_cacheable_items(scn, SHADER_CACHE_IGNORE_SKELETONS)
	var rids = {}
	var skeleton_paths = {}
	for item in items:
		var material = item["material"]
		var skeleton = item["skeleton"]
		var particles_material = item["particles_material"]
		var id = material.get_rid().get_id()
		if not rids.has(id):
			rids[id] = true
			pos = make_asset(pos, material, null)
		if skeleton:
			var skeleton_path = skeleton.get_path()
			if not skeleton_paths.has(skeleton_path):
				skeleton_paths[skeleton_path] = true
				pos = make_asset(pos, material, skeleton_path)
		if particles_material:
			var pid = particles_material.get_rid().get_id()
			if not rids.has(pid):
				rids[pid] = true
				pos = make_particles(pos, particles_material, material)
	return pos

func _process(delta):
	match stage:
		0:
			pass
		1:
			stage = stage + 1
			label_container.visible = true
			for node in holder1.get_children():
				node.queue_free()
			for node in holder2.get_children():
				node.queue_free()
			get_tree().call_group("room_enablers", "set_active", false)
		2:
			stage = stage + 1
			var pos = Vector2(-STEP * HALFROW, 0)
			pos = add_material_meshes(pos, get_node("/root"))
		3:
			stage = stage + 1
			# Show all items for one frame
		_:
			if SHADER_CACHE_HIDING_ENABLED:
				for node in holder1.get_children():
					holder1.remove_child(node)
					holder2.add_child(node)
			label_container.visible = false
			get_tree().call_group("room_enablers", "set_active", true)
			stage = 0

func refresh():
	if SHADER_CACHE_ENABLED:
		stage = 1
	else:
		label_container.visible = false
		get_tree().call_group("room_enablers", "set_active", true)