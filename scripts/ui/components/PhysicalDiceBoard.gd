class_name PhysicalDiceBoard
extends SubViewportContainer

const FACE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/dice/die_1.png"),
	preload("res://assets/dice/die_2.png"),
	preload("res://assets/dice/die_3.png"),
	preload("res://assets/dice/die_4.png"),
	preload("res://assets/dice/die_5.png"),
	preload("res://assets/dice/die_6.png"),
]
const HIDDEN_TEXTURE: Texture2D = preload("res://assets/dice/die_hidden.png")

var _viewport: SubViewport
var _world: Node3D
var _bodies: Array[RigidBody3D] = []
var _last_signature := ""
var _generation := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	_build_world()

func set_dice(dice: Array, animate: bool) -> void:
	var signature := _signature(dice)
	if signature == _last_signature and _bodies.size() == dice.size():
		return
	_last_signature = signature
	_generation += 1
	var generation := _generation
	_clear_bodies()
	for display_index in range(dice.size()):
		var body := _create_die_body(display_index, dice[display_index])
		_bodies.append(body)
		_world.add_child(body)
		if animate:
			body.position = Vector3(randf_range(-4.5, 4.5), randf_range(3.5, 6.2), randf_range(-1.6, 1.4))
			body.rotation = Vector3(randf_range(-PI, PI), randf_range(-PI, PI), randf_range(-PI, PI))
			body.apply_central_impulse(Vector3(randf_range(-2.5, 2.5), randf_range(0.6, 2.0), randf_range(-1.4, 1.4)))
			body.apply_torque_impulse(Vector3(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0), randf_range(-5.0, 5.0)))
		else:
			body.freeze = true
			body.position = _settled_position(display_index, dice.size())
			body.basis = _top_basis(int((dice[display_index] as Dictionary).get("value", 1)), bool((dice[display_index] as Dictionary).get("locked", false)))
	if animate:
		get_tree().create_timer(0.75).timeout.connect(_settle.bind(dice.duplicate(true), generation))

func _build_world() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "DiceViewport3D"
	_viewport.size = Vector2i(maxi(1, int(size.x)), maxi(1, int(size.y)))
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_world = Node3D.new()
	_world.name = "DiceWorld"
	_viewport.add_child(_world)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.2
	camera.position = Vector3(0, 8.2, 7.8)
	camera.look_at_from_position(camera.position, Vector3(0, 0.25, 0), Vector3.UP)
	_world.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-58, -28, 0)
	light.light_energy = 1.25
	light.shadow_enabled = true
	_world.add_child(light)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8a755f")
	env.ambient_light_energy = 0.72
	environment.environment = env
	_world.add_child(environment)
	_add_boundary(Vector3(0, -0.65, 0), Vector3(12.0, 0.5, 6.2))
	_add_boundary(Vector3(-6.1, 1.4, 0), Vector3(0.3, 4.2, 6.2))
	_add_boundary(Vector3(6.1, 1.4, 0), Vector3(0.3, 4.2, 6.2))
	_add_boundary(Vector3(0, 1.4, -3.1), Vector3(12.0, 4.2, 0.3))
	_add_boundary(Vector3(0, 1.4, 3.1), Vector3(12.0, 4.2, 0.3))

func _add_boundary(position_value: Vector3, box_size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = position_value
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	collision.shape = shape
	body.add_child(collision)
	_world.add_child(body)

func _create_die_body(index: int, data: Dictionary) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = "PhysicalDie%d" % index
	body.mass = 0.85
	body.gravity_scale = 1.35
	body.linear_damp = 1.1
	body.angular_damp = 0.85
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.96, 0.96, 0.96)
	collision.shape = shape
	body.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = _create_die_mesh(bool(data.get("hidden", false)))
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.add_child(mesh_instance)
	return body

func _create_die_mesh(hidden: bool) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var faces := [
		{"normal":Vector3.UP,"corners":[Vector3(-.48,.48,-.48),Vector3(.48,.48,-.48),Vector3(.48,.48,.48),Vector3(-.48,.48,.48)],"value":1},
		{"normal":Vector3(0,0,1),"corners":[Vector3(-.48,-.48,.48),Vector3(.48,-.48,.48),Vector3(.48,.48,.48),Vector3(-.48,.48,.48)],"value":2},
		{"normal":Vector3.RIGHT,"corners":[Vector3(.48,-.48,.48),Vector3(.48,-.48,-.48),Vector3(.48,.48,-.48),Vector3(.48,.48,.48)],"value":3},
		{"normal":Vector3.LEFT,"corners":[Vector3(-.48,-.48,-.48),Vector3(-.48,-.48,.48),Vector3(-.48,.48,.48),Vector3(-.48,.48,-.48)],"value":4},
		{"normal":Vector3(0,0,-1),"corners":[Vector3(.48,-.48,-.48),Vector3(-.48,-.48,-.48),Vector3(-.48,.48,-.48),Vector3(.48,.48,-.48)],"value":5},
		{"normal":Vector3.DOWN,"corners":[Vector3(-.48,-.48,.48),Vector3(.48,-.48,.48),Vector3(.48,-.48,-.48),Vector3(-.48,-.48,-.48)],"value":6},
	]
	for face in faces:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var corners: Array = face.corners
		var vertex_indices := [0, 1, 2, 0, 2, 3]
		var uvs := [Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(0,0)]
		for triangle_index in range(vertex_indices.size()):
			var vertex_index: int = vertex_indices[triangle_index]
			surface.set_normal(face.normal)
			surface.set_uv(uvs[triangle_index])
			surface.add_vertex(corners[vertex_index])
		surface.commit(mesh)
		var material := StandardMaterial3D.new()
		material.albedo_texture = HIDDEN_TEXTURE if hidden else FACE_TEXTURES[int(face.value) - 1]
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.roughness = 0.86
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	return mesh

func _settle(dice: Array, generation: int) -> void:
	if generation != _generation:
		return
	for index in range(mini(_bodies.size(), dice.size())):
		var body := _bodies[index]
		body.freeze = true
		var tween := create_tween().set_parallel(true)
		tween.tween_property(body, "position", _settled_position(index, dice.size()), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(body, "basis", _top_basis(int((dice[index] as Dictionary).get("value", 1)), bool((dice[index] as Dictionary).get("locked", false))), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _settled_position(index: int, count: int) -> Vector3:
	var columns := 8
	var row := floori(float(index) / float(columns))
	var column := index % columns
	var count_this_row := mini(columns, count - row * columns)
	var start_x := -float(count_this_row - 1) * 0.725
	var row_count := ceili(float(count) / float(columns))
	var start_z := -float(row_count - 1) * 0.675
	return Vector3(start_x + float(column) * 1.45, -0.02, start_z + float(row) * 1.35)

func _top_basis(value: int, tilted: bool) -> Basis:
	var basis := Basis.IDENTITY
	match clampi(value, 1, 6):
		2: basis = Basis(Vector3.RIGHT, -PI * 0.5)
		3: basis = Basis(Vector3.FORWARD, -PI * 0.5)
		4: basis = Basis(Vector3.FORWARD, PI * 0.5)
		5: basis = Basis(Vector3.RIGHT, PI * 0.5)
		6: basis = Basis(Vector3.RIGHT, PI)
	if tilted:
		basis = Basis(Vector3.UP, deg_to_rad(15.0)) * basis
	return basis

func _clear_bodies() -> void:
	for body in _bodies:
		if is_instance_valid(body):
			body.queue_free()
	_bodies.clear()

func _signature(dice: Array) -> String:
	var parts: Array[String] = []
	for die in dice:
		parts.append("%d:%d:%d" % [int(die.get("value", 0)), int(die.get("locked", false)), int(die.get("hidden", false))])
	return "|".join(parts)
