class_name PhysicalDiceBoard
extends SubViewportContainer

## 仅负责骰子的二维刚体投掷、静止检测和点数锁定。
## 特效、发光与粒子不属于本节点。

const FACE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/dice/die_1.png"),
	preload("res://assets/dice/die_2.png"),
	preload("res://assets/dice/die_3.png"),
	preload("res://assets/dice/die_4.png"),
	preload("res://assets/dice/die_5.png"),
	preload("res://assets/dice/die_6.png"),
]
const HIDDEN_TEXTURE: Texture2D = preload("res://assets/dice/die_hidden.png")

const DIE_SIZE := 46.0
const LINEAR_STOP_THRESHOLD := 12.0
const ANGULAR_STOP_THRESHOLD := 0.42
const REQUIRED_STILL_FRAMES := 12
const MAX_ROLL_SECONDS := 3.2
const SETTLE_TIME := 0.34
const FACE_SECTOR := TAU / 6.0

var _viewport: SubViewport
var _world: Node2D
var _bodies: Array[RigidBody2D] = []
var _last_signature := ""
var _generation := 0
var _rolling := false
var _roll_elapsed := 0.0
var _still_frames := 0
var _rolling_generation := 0
var _rolling_dice: Array = []
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

## 建立一轮展示；rolling_indices 以排序后的显示下标为准。
func set_dice(dice: Array, rolling_indices: Array[int] = []) -> void:
	var signature := _signature(dice)
	if signature == _last_signature and _bodies.size() == dice.size():
		return
	_last_signature = signature
	_generation += 1
	var generation := _generation
	_rolling = false
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
		body.set_meta("hidden", bool(die_data.get("hidden", false)))
		body.set_meta("target_tilted", bool(die_data.get("locked", false)))
		body.set_meta("face_phase", randf_range(0.0, TAU))
		body.set_meta("landing_top", 0)
		body.set_meta("settle_phase", "rolling" if display_index in rolling_indices else "settled")
		_bodies.append(body)
		_world.add_child(body)

		if display_index in rolling_indices:
			_throw_die(body, rolling_indices.find(display_index), rolling_indices.size())
		else:
			body.freeze = true
			body.position = previous_positions.get(source_index, _settled_position(display_index, dice.size()))
			body.rotation = _settled_rotation(bool(die_data.get("locked", false)))
			_lock_value(body, int(die_data.get("value", 1)))

	if rolling_indices.is_empty():
		_refresh_detected_values()
		_sort_static_bodies(dice.size(), generation)
	else:
		_begin_roll_watch(dice, generation)

## 抛掷：刚体从骰子区上方落下，并获得随机水平冲量和扭矩。
func _throw_die(body: RigidBody2D, order: int, rolling_count: int) -> void:
	var board_width := maxf(size.x, 1.0)
	var usable_width := maxf(DIE_SIZE, board_width - DIE_SIZE * 2.0)
	var slot := usable_width / float(maxi(rolling_count, 1))
	body.position = Vector2(DIE_SIZE + slot * (float(order) + 0.5), randf_range(DIE_SIZE, DIE_SIZE * 2.2))
	body.rotation = randf_range(-PI, PI)
	body.freeze = false
	body.sleeping = false
	body.apply_central_impulse(Vector2(randf_range(-165.0, 165.0), randf_range(-95.0, -35.0)))
	body.apply_torque_impulse(randf_range(-8.5, 8.5))

## 每个物理帧检测所有仍在运动的骰子；线速度和角速度均达标才算静止。
func _physics_process(delta: float) -> void:
	if not _rolling or _rolling_generation != _generation:
		set_physics_process(false)
		return
	_roll_elapsed += delta
	var all_still := not _bodies.is_empty()
	for body in _bodies:
		if not is_instance_valid(body) or body.freeze:
			continue
		_update_rolling_face(body)
		if body.linear_velocity.length() > LINEAR_STOP_THRESHOLD or absf(body.angular_velocity) > ANGULAR_STOP_THRESHOLD:
			all_still = false
	_still_frames = _still_frames + 1 if all_still else 0
	if _still_frames >= REQUIRED_STILL_FRAMES or _roll_elapsed >= MAX_ROLL_SECONDS:
		_rolling = false
		set_physics_process(false)
		_settle(_rolling_dice.duplicate(true), _rolling_generation)

func _begin_roll_watch(dice: Array, generation: int) -> void:
	_rolling = true
	_roll_elapsed = 0.0
	_still_frames = 0
	_rolling_generation = generation
	_rolling_dice = dice.duplicate(true)
	_detected_top_values.clear()
	set_physics_process(true)

## 静止后只判定一次点数，立即冻结刚体；后续排序不会重新判点。
func _settle(dice: Array, generation: int) -> void:
	if generation != _generation:
		return
	for index in range(mini(_bodies.size(), dice.size())):
		var body := _bodies[index]
		if not is_instance_valid(body):
			continue
		var target_value := clampi(int((dice[index] as Dictionary).get("value", 1)), 1, 6)
		_align_face_mapping(body, target_value)
		var detected_value := _detect_top_value(body)
		_lock_value(body, detected_value)
		body.freeze = true
		body.sleeping = true
		body.linear_velocity = Vector2.ZERO
		body.angular_velocity = 0.0
	_refresh_detected_values()
	_sort_static_bodies(dice.size(), generation)

## 将当前物理朝向解释为逻辑已经生成的结果，避免动画改写游戏数值。
func _align_face_mapping(body: RigidBody2D, target_value: int) -> void:
	var target_sector := float(clampi(target_value, 1, 6) - 1) * FACE_SECTOR
	body.set_meta("face_phase", target_sector - body.rotation)
	body.set_meta("landing_top", 0)

## 依据平面旋转角度及骰子初始面向，计算当前朝上的点数。
func _detect_top_value(body: RigidBody2D) -> int:
	var locked_value := int(body.get_meta("landing_top", 0))
	if locked_value > 0:
		return locked_value
	var phase := float(body.get_meta("face_phase", 0.0))
	var normalized_angle := fposmod(body.rotation + phase, TAU)
	return posmod(roundi(normalized_angle / FACE_SECTOR), 6) + 1

func _lock_value(body: RigidBody2D, value: int) -> void:
	var locked_value := clampi(value, 1, 6)
	body.set_meta("landing_top", locked_value)
	body.set_meta("detected_top", locked_value)
	_set_face_texture(body, locked_value)

func _update_rolling_face(body: RigidBody2D) -> void:
	_set_face_texture(body, _detect_top_value(body))

func _set_face_texture(body: RigidBody2D, value: int) -> void:
	var sprite := body.get_node_or_null("Face") as Sprite2D
	if sprite == null:
		return
	var texture := HIDDEN_TEXTURE if bool(body.get_meta("hidden", false)) else FACE_TEXTURES[clampi(value, 1, 6) - 1]
	sprite.texture = texture
	if texture != null and texture.get_width() > 0 and texture.get_height() > 0:
		sprite.scale = Vector2(DIE_SIZE / float(texture.get_width()), DIE_SIZE / float(texture.get_height()))

func _refresh_detected_values() -> void:
	_detected_top_values.clear()
	for body in _bodies:
		if is_instance_valid(body):
			_detected_top_values.append(_detect_top_value(body))

func _sort_static_bodies(count: int, generation: int) -> void:
	for index in range(_bodies.size()):
		var body := _bodies[index]
		if not is_instance_valid(body):
			continue
		body.freeze = true
		body.set_meta("settle_phase", "sorting")
		var final_rotation := _settled_rotation(bool(body.get_meta("target_tilted", false)))
		var sorting := create_tween().set_parallel(true)
		sorting.tween_property(body, "position", _settled_position(index, count), SETTLE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		sorting.tween_property(body, "rotation", final_rotation, SETTLE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		sorting.finished.connect(func() -> void:
			if generation == _generation and is_instance_valid(body):
				body.rotation = final_rotation
				body.set_meta("settle_phase", "settled")
		)

func _settled_rotation(tilted: bool) -> float:
	return deg_to_rad(12.0) if tilted else 0.0

func _settled_position(index: int, count: int) -> Vector2:
	var columns := 8
	var row := floori(float(index) / float(columns))
	var column := index % columns
	var count_this_row := mini(columns, count - row * columns)
	var spacing_x := 62.0
	var spacing_y := 61.0
	var row_count := ceili(float(count) / float(columns))
	var start_x := (size.x - float(count_this_row - 1) * spacing_x) * 0.5
	var bottom_y := maxf(DIE_SIZE * 0.75, size.y - DIE_SIZE * 0.78)
	var start_y := bottom_y - float(row_count - 1) * spacing_y
	return Vector2(start_x + float(column) * spacing_x, start_y + float(row) * spacing_y)

func _build_world() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "DiceViewport2D"
	_viewport.size = Vector2i(maxi(1, roundi(size.x)), maxi(1, roundi(size.y)))
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_world = Node2D.new()
	_world.name = "DiceWorld2D"
	_viewport.add_child(_world)
	_build_boundaries()

func _build_boundaries() -> void:
	var board_width := maxf(size.x, 1.0)
	var board_height := maxf(size.y, 1.0)
	_add_boundary(Vector2(board_width * 0.5, board_height - 9.0), Vector2(board_width, 18.0))
	_add_boundary(Vector2(9.0, board_height * 0.5), Vector2(18.0, board_height))
	_add_boundary(Vector2(board_width - 9.0, board_height * 0.5), Vector2(18.0, board_height))
	_add_boundary(Vector2(board_width * 0.5, 9.0), Vector2(board_width, 18.0))

func _add_boundary(position_value: Vector2, box_size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = position_value
	var material := PhysicsMaterial.new()
	material.friction = 0.78
	material.bounce = 0.24
	material.rough = true
	body.physics_material_override = material
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = box_size
	collision.shape = shape
	body.add_child(collision)
	_world.add_child(body)

func _create_die_body(index: int, data: Dictionary) -> RigidBody2D:
	var body := RigidBody2D.new()
	body.name = "PhysicalDie%d" % index
	body.mass = 0.82
	body.gravity_scale = 1.35
	body.linear_damp = 0.72
	body.angular_damp = 1.45
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	body.contact_monitor = true
	body.max_contacts_reported = 8
	body.collision_layer = 1
	body.collision_mask = 1
	var material := PhysicsMaterial.new()
	material.friction = 0.72
	material.bounce = 0.34
	material.rough = true
	body.physics_material_override = material
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(DIE_SIZE * 0.88, DIE_SIZE * 0.88)
	collision.shape = shape
	body.add_child(collision)
	var sprite := Sprite2D.new()
	sprite.name = "Face"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.add_child(sprite)
	body.set_meta("hidden", bool(data.get("hidden", false)))
	_set_face_texture(body, int(data.get("value", 1)))
	return body

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
