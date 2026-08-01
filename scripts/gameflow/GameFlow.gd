## Manages the full game run — stages, nodes, scene transitions.
## V2: Linear progression, no map, shop after every regular battle.
extends Control

enum NodeType { DICE, EVENT, BOSS }
const CardPoolRef = preload("res://scripts/cards/CardPool.gd")

var stages: Array = []
var current_stage_index: int = 0
var current_node_index: int = 0
var nodes_this_stage: Array = []
var _skip_to_boss: bool = false
var _drawn_cards: Array = []
var _is_boss_node: bool = false
var _battle_gold: int = 0

func _ready() -> void:
	_build_stages()
	EventBus.node_completed.connect(_on_node_completed)
	EventBus.shop_exited.connect(_on_shop_exited)
	if GameState.get("_debug_jump_boss") and GameState._debug_jump_boss:
		current_stage_index = GameState.current_stage
		GameState._debug_jump_boss = false
		_skip_to_boss = true
	elif GameState.has_saved_game() and (GameState.current_stage > 0 or GameState.current_node_index > 0):
		current_stage_index = GameState.current_stage
		current_node_index = GameState.current_node_index
	elif GameState.current_stage > 0:
		current_stage_index = GameState.current_stage

	# Tutorial now on main menu button, not auto-triggered
	_on_enter()

func _build_stages() -> void:
	var StageDataScript := preload("res://scripts/resources/StageData.gd")
	for i in range(4):
		var s: Resource = StageDataScript.new()
		match i:
			0: s.stage_name = "破烂��院"; s.mutation = 0
			1: s.stage_name = "地下赌场"; s.mutation = 1
			2: s.stage_name = "黑帮私局"; s.mutation = 2
			3: s.stage_name = "终极赌场"; s.mutation = 3
		stages.append(s)

func _on_enter() -> void:
	if current_stage_index >= stages.size():
		_victory(); return
	GameState.current_stage = current_stage_index
	EventBus.stage_changed.emit(current_stage_index, stages[current_stage_index].stage_name)
	_generate_nodes()
	current_node_index = clampi(current_node_index, 0, nodes_this_stage.size() - 1)
	if _skip_to_boss:
		_skip_to_boss = false
		current_node_index = nodes_this_stage.size() - 1
	GameState.current_node_index = current_node_index
	_run_node(nodes_this_stage[current_node_index])

func _generate_nodes() -> void:
	nodes_this_stage.clear()
	match current_stage_index:
		0: nodes_this_stage.append_array([NodeType.DICE, NodeType.DICE, NodeType.BOSS])
		1: nodes_this_stage.append_array([NodeType.DICE, NodeType.DICE, NodeType.EVENT, NodeType.BOSS])
		2: nodes_this_stage.append_array([NodeType.DICE, NodeType.DICE, NodeType.DICE, NodeType.BOSS])
		3: nodes_this_stage.append_array([NodeType.DICE, NodeType.DICE, NodeType.DICE, NodeType.DICE, NodeType.BOSS])
		_: nodes_this_stage.append(NodeType.BOSS)

func _run_node(node_type: int) -> void:
	for child: Node in get_children():
		if child is Control and child != self:
			child.queue_free()
	await get_tree().process_frame
	match node_type:
		NodeType.DICE, NodeType.BOSS: _launch_battle(node_type == NodeType.BOSS)
		NodeType.EVENT: _launch_event()

func _launch_battle(is_boss: bool) -> void:
	_is_boss_node = is_boss
	_battle_gold = CardPoolRef.get_battle_gold(current_stage_index)

	# Build pool for manual card selection
	var mixed_pool := CardPoolRef.get_mixed_pool(current_stage_index)
	var boss_pool: Array = CardPoolRef.get_boss_pool(current_stage_index) if is_boss else []

	# Show card picking UI
	var card_ui := preload("res://scripts/ui/CardDrawUI.gd").new()
	card_ui.name = "CardDrawUI"
	add_child(card_ui)
	card_ui.setup(mixed_pool, boss_pool, self, is_boss, 2, current_stage_index)

## Called by CardDrawUI when player confirms selected cards
func _on_cards_confirmed(cards: Array) -> void:
	_drawn_cards = cards
	_actually_launch_battle()

func _actually_launch_battle() -> void:
	var is_boss: bool = _is_boss_node
	var scene_path := "res://scenes/gameflow/BossGameScene.tscn" if is_boss else "res://scenes/gameflow/DiceGameScene.tscn"
	var scene: PackedScene = load(scene_path) as PackedScene
	if not scene: push_error("GameFlow: failed to load %s" % scene_path); return
	var inst: Control = scene.instantiate() as Control
	if not inst: return
	add_child(inst)
	if inst.has_method("setup_with_flow"):
		inst.setup_with_flow(stages[current_stage_index], self, _drawn_cards)

func _launch_shop() -> void:
	var scene: PackedScene = load("res://scenes/gameflow/ShopScene.tscn") as PackedScene
	if not scene: return
	var inst: Control = scene.instantiate() as Control
	if not inst: return
	inst.name = "ShopUI"
	add_child(inst)
	if inst.has_method("set_parent_flow"):
		inst.set_parent_flow(self)

func _launch_event() -> void:
	var scene: PackedScene = load("res://scenes/gameflow/EventScene.tscn") as PackedScene
	if not scene: return
	var inst: Control = scene.instantiate() as Control
	if not inst: return
	inst.name = "EventUI"
	add_child(inst)
	if inst.has_method("set_parent_flow"):
		inst.set_parent_flow(self)

func _on_node_completed(_type: String) -> void:
	var was_elite: bool = false
	for card in _drawn_cards:
		if card and card.rarity == CardData.Rarity.UNKNOWN:
			was_elite = true
			break
	# If this was a regular battle, launch shop automatically
	if not _is_boss_node and nodes_this_stage[current_node_index] == NodeType.DICE:
		GameState.add_gold(_battle_gold)
		if was_elite:
			if not GameState.add_consumable_item(CardPoolRef.get_elite_item()):
				await EventBus.discard_resolved
			GameState.add_rust_points(2)
			GameState.save_progress()
			current_node_index += 1
			GameState.current_node_index = current_node_index
			await _show_corridor()
			_run_node(nodes_this_stage[current_node_index])
			return
		_launch_shop()
		return

	# Boss: give legendary item
	if _is_boss_node:
		GameState.add_gold(_battle_gold)
		var leg_item: String = CardPoolRef.get_legendary_item()
		if not GameState.add_consumable_item(leg_item):
			await EventBus.discard_resolved
		EventBus.hint_show.emit("获得传说道具: " + GameState.get_item_info(leg_item).item_name, 3.0, Color(0.98, 0.78, 0.29))
		if was_elite:
			var elite_item: String = CardPoolRef.get_elite_item()
			if not GameState.add_consumable_item(elite_item):
				await EventBus.discard_resolved
			GameState.add_rust_points(2)
			EventBus.hint_show.emit("未知精英追加奖励: 稀有判定道具 + 2锈蚀点", 3.0, Color(0.75, 0.45, 0.85))
		# Record boss defeat
		GameState.bosses_defeated.append(str(current_stage_index))
		# Award rust points
		var rp: int = 0
		match current_stage_index:
			1: rp = 1
			2: rp = 2
			3: rp = 3
		if rp > 0:
			GameState.add_rust_points(rp)
			GameState.save_progress()

	# Advance
	current_node_index += 1
	GameState.current_node_index = current_node_index
	if current_node_index >= nodes_this_stage.size():
		current_stage_index += 1
		current_node_index = 0
		await _show_corridor()
		_on_enter()
	else:
		await _show_corridor()
		_run_node(nodes_this_stage[current_node_index])

func _on_shop_exited() -> void:
	# After shop, advance to next node
	current_node_index += 1
	GameState.current_node_index = current_node_index
	if current_node_index >= nodes_this_stage.size():
		current_stage_index += 1
		current_node_index = 0
		await _show_corridor()
		_on_enter()
	else:
		await _show_corridor()
		_run_node(nodes_this_stage[current_node_index])

func _show_intro() -> void:
	var overlay := Control.new()
	overlay.name = "IntroOverlay"
	overlay.position = Vector2.ZERO
	overlay.size = Vector2(1280, 720)
	add_child(overlay)

	var dark := ColorRect.new()
	dark.anchor_right = 1.0; dark.anchor_bottom = 1.0
	dark.color = Color(0, 0, 0, 1)
	overlay.add_child(dark)

	var lines: Array[String] = [
		"骰子是你的命。",
		"叫稳了再开。",
		"推翻国王——或者成为新的国王。",
	]
	var labels: Array[Label] = []
	for i in range(lines.size()):
		var l := Label.new()
		l.text = lines[i]
		l.position = Vector2(290, 240 + i * 60); l.size = Vector2(700, 40)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.modulate.a = 0.0
		l.add_theme_font_size_override("font_size", 28)
		l.add_theme_color_override("font_color", Color(0.91, 0.773, 0.416))
		overlay.add_child(l)
		labels.append(l)

	# Fade in text
	for l in labels:
		var t := create_tween()
		t.tween_property(l, "modulate:a", 1.0, 0.5)
		await get_tree().create_timer(0.25).timeout
	await get_tree().create_timer(3.0).timeout
	# Fade out everything
	var t := create_tween()
	t.tween_property(overlay, "modulate:a", 0.0, 0.8)
	await t.finished
	overlay.queue_free()

func _show_corridor() -> void:
	for child: Node in get_children():
		if child is Control and child.name == "CorridorOverlay":
			child.queue_free()
	await get_tree().process_frame

	var stage: int = min(current_stage_index, 3)
	var texts: Array = [
		["生锈的通风管飘来机油味。远处的废料堆里，几张旧卡牌散落在骰子旁边。",
		 "墙上贴着一张泛黄的告示。有人用骰子压着一角，让它不再卷边。"],
		["霓虹灯管嗡嗡响。墙壁上投影着上一局的牌面。筹码碰撞声从每一条走廊渗出。",
		 "角落里一个醉倒的守卫喃喃自语：'骰子之神…是盒子里的第一张卡…'"],
		["空气变冷了。这里没有霓虹灯，只有卡牌在墙壁上无声翻转。三张卡并排躺在走廊尽头。",
		 "一个穿西装的机器人与你擦肩，袖口闪过一张微型卡牌。它没有看你。"],
		["大理石地面光滑如镜，映出你的脸。一张巨大的卡牌悬浮在半空——牌面是空白的，它在等你。",
		 "走廊尽头的那扇门没有任何标记。但你知道骰子之神在那扇门后面。那张创世卡在等你。"],
	][stage]
	var text: String = texts[randi() % texts.size()]

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 1.0)
	bg.position = Vector2.ZERO; bg.size = Vector2(1280, 720)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP; bg.z_index = 200
	add_child(bg)

	var lbl := Label.new()
	lbl.text = text; lbl.position = Vector2(60, 280); lbl.size = Vector2(1160, 200)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	bg.add_child(lbl)

	var skipped: Array = [false]
	bg.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed: skipped[0] = true)

	var t: float = 0.0
	while t < 1.5 and not skipped[0]:
		t += get_process_delta_time()
		await get_tree().process_frame
		if not is_instance_valid(bg): return
	bg.queue_free()

func _victory() -> void:
	for child: Node in get_children():
		if child is Control and child != self: child.queue_free()
	await get_tree().process_frame
	GameState._pending_xp += GameState.XP_FULL_CLEAR
	GameState.commit_pending_xp()
	GameState.has_cleared_game = true
	GameState.save_progress()
	EventBus.run_ended.emit(true)
	var v: Control = load("res://scripts/ui/VictoryUI.gd").new()
	add_child(v)

func handle_event_death() -> void:
	GameState.final_stage_reached = current_stage_index
	GameState.final_node_reached = current_node_index
	GameState.commit_pending_xp()
	GameState.delete_run_save()
	GameState.save_progress()
	EventBus.run_ended.emit(false)
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func emit_node_done() -> void:
	EventBus.node_completed.emit("")
