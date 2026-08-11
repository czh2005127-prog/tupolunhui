class_name PhysicalDiceBoard
extends SubViewportContainer

## 受控三维骰子：自由物理翻滚后平滑校准到逻辑结果，再冻结并排序。
## 游戏点数由 DiceCup 生成；本节点只负责忠实表现，绝不反向改写规则结果。

const FACE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/dice/die_1.png"),
	preload("res://assets/dice/die_2.png"),
	preload("res://assets/dice/die_3.png"),
	preload("res://assets/dice/die_4.png"),
	preload("res://assets/dice/die_5.png"),
	preload("res://assets/dice/die_6.png"),
]
const BASE_TEXTURE: Texture2D = preload("res://assets/dice/die_base.png")

const CONTROL_START_SECONDS := 0.48
const CONTROL_HEIGHT := 0.92
const MAX_FREE_ROLL_SECONDS := 1.12
const FACE_CORRECTION_SECONDS := 0.14
const LANDING_HOLD_SECONDS := 0.32
const SORT_LIFT_SECONDS := 0.10
const SORT_SLIDE_SECONDS := 0.28
const REST_HEIGHT := 0.08

var _viewport: SubViewport
var _world: Node3D
var _bodies: Array[RigidBody3D] = []
var _last_signature := ""
var _generation := 0
var _rolling := false
var _roll_elapsed := 0.0
var _rolling_generation := 0
var _rolling_dice: Array = []
var _landing_pause_started := false
var _detected_top_values: Array[int] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	stretch = true
	_build_world()
	set_physics_process(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_instance_valid(_viewport):
		_viewport.size = Vector2i(maxi(1, roundi(size.x)), maxi(1, roundi(size.y)))

func set_dice(dice: Array, rolling_indices: Array[int] = []) -> void:
	var signature := _signature(dice)
	if signature == _last_signature and _bodies.size() == dice.size():
		return
	_last_signature = signature
	_generation += 1
	var generation := _generation
	_rolling = false
	_landing_pause_started = false
	set_physics_process(false)

	var previous_positions: Dictionary = {}
	for old_body in _bodies:
		if is_instance_valid(old_body) and old_body.has_meta("source_index"):
			previous_positions[int(old_body.get_meta("source_index"))] = old_body.position
	_clear_bodies()

	for display_index in range(dice.size()):
		var die_data := dice[display_index] as Dictionary
		var body := _create_die_body(display_index, die_data)
		var source_index := int(die_data.get("_source_index", display_index))
		body.set_meta("source_index", source_index)
		body.set_meta("target_value", clampi(int(die_data.get("value", 1)), 1, 6))
		body.set_meta("target_tilted", bool(die_data.get("locked", false)))
		body.set_meta("landing_top", 0)
		body.set_meta("settle_phase", "rolling" if display_index in rolling_indices else "settled")
		_bodies.append(body)
		_world.add_child(body)

		if display_index in rolling_indices:
			_throw_die(body, rolling_indices.find(display_index), rolling_indices.size())
		else:
			body.freeze = true
			body.position = previous_positions.get(source_index, _settled_position(display_index, dice.size()))
			body.basis = _top_basis(int(die_data.get("value", 1)), bool(die_data.get("locked", false)))
			_lock_landing_value(body, int(die_data.get("value", 1)))

	if rolling_indices.is_empty():
		_refresh_detected_values()
		_sort_static_bodies(dice.size(), generation)
	else:
		_begin_roll_watch(dice, generation)

## 自由抛掷阶段：每颗骰子拥有独立出生点、冲量和三轴扭矩。
func _throw_die(body: RigidBody3D, order: int, rolling_count: int) -> void:
	var count := maxi(rolling_count, 1)
	var slot_width := 8.2 / float(count)
	var spawn_x := -4.1 + slot_width * (float(order) + 0.5)
	body.position = Vector3(spawn_x, randf_range(3.4, 5.3), randf_range(-1.65, 1.45))
	body.rotation = Vector3(randf_range(-PI, PI), randf_range(-PI, PI), randf_range(-PI, PI))
	body.freeze = false
	body.sleeping = false
	body.apply_central_impulse(Vector3(randf_range(-2.3, 2.3) - spawn_x * 0.14, randf_range(0.3, 1.45), randf_range(-1.65, 1.65)))
	body.apply_torque_impulse(Vector3(randf_range(-5.8, 5.8), randf_range(-5.8, 5.8), randf_range(-5.8, 5.8)))

func _begin_roll_watch(dice: Array, generation: int) -> void:
	_rolling = true
	_roll_elapsed = 0.0
	_rolling_generation = generation
	_rolling_dice = dice.duplicate(true)
	_detected_top_values.clear()
	set_physics_process(true)

## 接近停止后才进入受控阶段，前半段保持真实碰撞与翻滚。
func _physics_process(delta: float) -> void:
	if not _rolling or _rolling_generation != _generation:
		set_physics_process(false)
		return
	_roll_elapsed += delta
	for body in _bodies:
		if not is_instance_valid(body) or body.freeze or str(body.get_meta("settle_phase", "")) != "rolling":
			continue
		var close_to_table := body.position.y <= CONTROL_HEIGHT
		# The result correction happens while the die is still moving quickly. Waiting until
		# it has visibly stopped is what made the old animation look as if it turned itself.
		if _roll_elapsed >= CONTROL_START_SECONDS and close_to_table:
			_begin_face_correction(body, _rolling_generation)
		elif _roll_elapsed >= MAX_FREE_ROLL_SECONDS:
			_begin_face_correction(body, _rolling_generation)

## 将目标面以短暂缓动转到上方。校准完成的这一刻就是唯一落地点数判定时刻。
func _begin_face_correction(body: RigidBody3D, generation: int) -> void:
	if generation != _generation or not is_instance_valid(body) or str(body.get_meta("settle_phase", "")) != "rolling":
		return
	body.set_meta("settle_phase", "correcting")
	body.freeze = true
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	var target_value := int(body.get_meta("target_value", 1))
	var random_yaw := randf_range(-PI, PI)
	var target_basis := Basis(Vector3.UP, random_yaw) * _top_basis(target_value, bool(body.get_meta("target_tilted", false)))
	var target_position := body.position
	target_position.x = clampf(target_position.x, -5.15, 5.15)
	target_position.y = REST_HEIGHT
	target_position.z = clampf(target_position.z, -2.25, 2.25)
	var correction := create_tween().set_parallel(true)
	correction.tween_property(body, "position", target_position, FACE_CORRECTION_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	correction.tween_property(body, "quaternion", target_basis.get_rotation_quaternion(), FACE_CORRECTION_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	correction.finished.connect(func() -> void:
		if generation != _generation or not is_instance_valid(body):
			return
		body.basis = target_basis
		var physical_value := _detect_physical_top_value(body)
		# 浮点插值结束后再次校验；正常情况下 physical_value 就是 target_value。
		if physical_value != target_value:
			body.basis = target_basis
		_lock_landing_value(body, target_value)
		body.set_meta("landing_rotation", body.quaternion)
		body.set_meta("settle_phase", "landed")
		_try_finish_landing(generation)
	)

func _try_finish_landing(generation: int) -> void:
	if generation != _generation or _landing_pause_started:
		return
	for body in _bodies:
		if is_instance_valid(body) and str(body.get_meta("settle_phase", "")) in ["rolling", "correcting"]:
			return
	_landing_pause_started = true
	_rolling = false
	set_physics_process(false)
	_refresh_detected_values()
	_hold_landing_then_sort(generation)

## 给玩家留出看清落点的时间，然后再整理队列。
func _hold_landing_then_sort(generation: int) -> void:
	await get_tree().create_timer(LANDING_HOLD_SECONDS).timeout
	if generation == _generation:
		_sort_static_bodies(_bodies.size(), generation)

## 排序只改变位置，并在保持同一顶面的前提下整理朝向。
func _sort_static_bodies(count: int, generation: int) -> void:
	for index in range(_bodies.size()):
		var body := _bodies[index]
		if not is_instance_valid(body):
			continue
		body.freeze = true
		body.set_meta("settle_phase", "sorting")
		var landing_basis := body.basis
		var final_position := _settled_position(index, count)
		var lifted_position := body.position
		lifted_position.y += 0.14
		var sorting := create_tween()
		sorting.tween_interval(float(index) * 0.045)
		sorting.tween_property(body, "position", lifted_position, SORT_LIFT_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		sorting.tween_property(body, "position", final_position, SORT_SLIDE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		sorting.finished.connect(func() -> void:
			if generation == _generation and is_instance_valid(body):
				# Sorting is positional only: retain the exact face and yaw seen at landing.
				body.basis = landing_basis
				body.set_meta("settle_phase", "settled")
		)

func _lock_landing_value(body: RigidBody3D, value: int) -> void:
	var locked_value := clampi(value, 1, 6)
	body.set_meta("landing_top", locked_value)
	body.set_meta("detected_top", locked_value)
	body.freeze = true
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO

## 锁定后返回唯一落地结果；锁定前则根据六个世界法线真实检测顶面。
func _detect_top_value(body: RigidBody3D) -> int:
	var locked_value := int(body.get_meta("landing_top", 0))
	return locked_value if locked_value > 0 else _detect_physical_top_value(body)

func _detect_physical_top_value(body: RigidBody3D) -> int:
	var best_value := 1
	var best_dot := -INF
	for value in range(1, 7):
		var world_normal := body.basis * _local_face_normal(value)
		var alignment := world_normal.normalized().dot(Vector3.UP)
		if alignment > best_dot:
			best_dot = alignment
			best_value = value
	return best_value

func _refresh_detected_values() -> void:
	_detected_top_values.clear()
	for body in _bodies:
		if is_instance_valid(body):
			_detected_top_values.append(_detect_top_value(body))

func _local_face_normal(value: int) -> Vector3:
	match clampi(value, 1, 6):
		1: return Vector3.UP
		2: return Vector3(0, 0, 1)
		3: return Vector3.RIGHT
		4: return Vector3.LEFT
		5: return Vector3(0, 0, -1)
		_: return Vector3.DOWN

func _top_basis(value: int, tilted: bool) -> Basis:
	var basis := Basis.IDENTITY
	match clampi(value, 1, 6):
		2: basis = Basis(Vector3.RIGHT, -PI * 0.5)
		3: basis = Basis(Vector3.FORWARD, -PI * 0.5)
		4: basis = Basis(Vector3.FORWARD, PI * 0.5)
		5: basis = Basis(Vector3.RIGHT, PI * 0.5)
		6: basis = Basis(Vector3.RIGHT, PI)
	if tilted:
		basis = Basis(Vector3.FORWARD, deg_to_rad(12.0)) * basis
	return basis

func _settled_position(index: int, count: int) -> Vector3:
	var columns := 8
	var row := floori(float(index) / float(columns))
	var column := index % columns
	var count_this_row := mini(columns, count - row * columns)
	var start_x := -float(count_this_row - 1) * 0.725
	var row_count := ceili(float(count) / float(columns))
	var start_z := -float(row_count - 1) * 0.675
	return Vector3(start_x + float(column) * 1.45, REST_HEIGHT, start_z + float(row) * 1.35)

func _build_world() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "DiceViewport3D"
	_viewport.size = Vector2i(maxi(1, roundi(size.x)), maxi(1, roundi(size.y)))
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_world = Node3D.new()
	_world.name = "DiceWorld3D"
	_viewport.add_child(_world)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 33.0
	camera.position = Vector3(0, 10.8, 5.8)
	camera.look_at_from_position(camera.position, Vector3(0, 0.22, 0), Vector3.UP)
	_world.add_child(camera)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-56, -32, 0)
	light.light_energy = 0.72
	light.shadow_enabled = true
	_world.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35, 145, 0)
	fill.light_energy = 0.18
	fill.shadow_enabled = false
	_world.add_child(fill)

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("927d66")
	env.ambient_light_energy = 0.48
	environment.environment = env
	_world.add_child(environment)

	_add_boundary(Vector3(0, -0.65, 0), Vector3(12.0, 0.5, 6.2))
	_add_boundary(Vector3(-6.1, 1.5, 0), Vector3(0.3, 4.5, 6.2))
	_add_boundary(Vector3(6.1, 1.5, 0), Vector3(0.3, 4.5, 6.2))
	_add_boundary(Vector3(0, 1.5, -3.1), Vector3(12.0, 4.5, 0.3))
	_add_boundary(Vector3(0, 1.5, 3.1), Vector3(12.0, 4.5, 0.3))

func _add_boundary(position_value: Vector3, box_size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = position_value
	var material := PhysicsMaterial.new()
	material.friction = 0.82
	material.bounce = 0.23
	body.physics_material_override = material
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	collision.shape = shape
	body.add_child(collision)
	_world.add_child(body)

func _create_die_body(index: int, data: Dictionary) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = "PhysicalDie%d" % index
	body.mass = randf_range(0.82, 0.90)
	body.gravity_scale = randf_range(1.24, 1.34)
	body.linear_damp = randf_range(0.72, 0.82)
	body.angular_damp = randf_range(0.62, 0.72)
	body.continuous_cd = true
	body.contact_monitor = true
	body.max_contacts_reported = 8
	body.collision_layer = 1
	body.collision_mask = 1
	var material := PhysicsMaterial.new()
	material.friction = randf_range(0.70, 0.78)
	material.bounce = randf_range(0.25, 0.32)
	body.physics_material_override = material

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.94, 0.94, 0.94)
	collision.shape = shape
	body.add_child(collision)

	var core := MeshInstance3D.new()
	var core_box := BoxMesh.new()
	core_box.size = Vector3(0.94, 0.94, 0.94)
	var core_material := StandardMaterial3D.new()
	core_material.albedo_texture = BASE_TEXTURE
	core_material.albedo_color = Color.WHITE
	core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	core_material.alpha_scissor_threshold = 0.05
	core_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	core_material.roughness = 0.9
	core_box.material = core_material
	core.mesh = core_box
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.add_child(core)

	var face_mesh := MeshInstance3D.new()
	face_mesh.mesh = _create_die_mesh(bool(data.get("hidden", false)))
	face_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(face_mesh)
	return body

func _create_die_mesh(hidden: bool) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var edge := 0.472
	var faces := [
		{"normal":Vector3.UP,"corners":[Vector3(-edge,edge,-edge),Vector3(edge,edge,-edge),Vector3(edge,edge,edge),Vector3(-edge,edge,edge)],"value":1},
		{"normal":Vector3(0,0,1),"corners":[Vector3(-edge,-edge,edge),Vector3(edge,-edge,edge),Vector3(edge,edge,edge),Vector3(-edge,edge,edge)],"value":2},
		{"normal":Vector3.RIGHT,"corners":[Vector3(edge,-edge,edge),Vector3(edge,-edge,-edge),Vector3(edge,edge,-edge),Vector3(edge,edge,edge)],"value":3},
		{"normal":Vector3.LEFT,"corners":[Vector3(-edge,-edge,-edge),Vector3(-edge,-edge,edge),Vector3(-edge,edge,edge),Vector3(-edge,edge,-edge)],"value":4},
		{"normal":Vector3(0,0,-1),"corners":[Vector3(edge,-edge,-edge),Vector3(-edge,-edge,-edge),Vector3(-edge,edge,-edge),Vector3(edge,edge,-edge)],"value":5},
		{"normal":Vector3.DOWN,"corners":[Vector3(-edge,-edge,edge),Vector3(edge,-edge,edge),Vector3(edge,-edge,-edge),Vector3(-edge,-edge,-edge)],"value":6},
	]
	for face in faces:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var corners: Array = face.corners
		var vertex_indices := [0, 1, 2, 0, 2, 3]
		if face.normal == Vector3.UP or face.normal == Vector3.DOWN:
			vertex_indices = [0, 2, 1, 0, 3, 2]
		var uvs := [Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)]
		for vertex_index in vertex_indices:
			surface.set_normal(face.normal)
			surface.set_uv(uvs[vertex_index])
			surface.add_vertex(corners[vertex_index])
		surface.commit(mesh)
		var face_material := StandardMaterial3D.new()
		face_material.albedo_texture = BASE_TEXTURE if hidden else FACE_TEXTURES[int(face.value) - 1]
		face_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		face_material.alpha_scissor_threshold = 0.05
		face_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		face_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		face_material.roughness = 0.92
		mesh.surface_set_material(mesh.get_surface_count() - 1, face_material)
	return mesh

func _clear_bodies() -> void:
	_rolling = false
	for body in _bodies:
		if is_instance_valid(body):
			if body.get_parent() != null:
				body.get_parent().remove_child(body)
			body.queue_free()
	_bodies.clear()

func _signature(dice: Array) -> String:
	var parts: Array[String] = []
	for die in dice:
		parts.append("%d:%d:%d:%d" % [int(die.get("value", 0)), int(die.get("locked", false)), int(die.get("hidden", false)), int(die.get("modified", 0))])
	return "|".join(parts)
