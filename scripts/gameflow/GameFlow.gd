## Manages the full game run — stages, nodes, scene transitions.
## Linear six-node progression: two battles, one shop, two events, then boss.
extends Control

signal fragment_choice_resolved
signal contract_choice_resolved

enum NodeType { DICE, EVENT, SHOP, BOSS }
const CardPoolRef = preload("res://scripts/cards/CardPool.gd")
const BossFragmentDataRef = preload("res://scripts/resources/BossFragmentData.gd")

var stages: Array = []
var current_stage_index: int = 0
var current_node_index: int = 0
var nodes_this_stage: Array = []
var _skip_to_boss: bool = false
var _drawn_cards: Array = []
var _is_boss_node: bool = false
var _battle_gold: int = 0
var _battle_reward_multiplier: float = 1.0
var _redraw_used: bool = false

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
	var key: String = str(current_stage_index)
	if GameState.stage_node_orders.has(key):
		nodes_this_stage.assign(GameState.stage_node_orders[key])
		# Save migration: old runs had one event and five nodes per stage.
		if nodes_this_stage.size() == 5 and nodes_this_stage.count(NodeType.EVENT) == 1 and nodes_this_stage.back() == NodeType.BOSS:
			nodes_this_stage.insert(nodes_this_stage.size() - 1, NodeType.EVENT)
			GameState.stage_node_orders[key] = nodes_this_stage.duplicate()
		if current_node_index > 0 or _node_order_is_valid(nodes_this_stage):
			return
	var prefix: Array = [NodeType.DICE, NodeType.DICE, NodeType.SHOP, NodeType.EVENT, NodeType.EVENT]
	while true:
		prefix.shuffle()
		var shop_index: int = prefix.find(NodeType.SHOP)
		var first_battle_index: int = prefix.find(NodeType.DICE)
		var double_event_opening: bool = prefix[0] == NodeType.EVENT and prefix[1] == NodeType.EVENT
		if first_battle_index >= 0 and first_battle_index < shop_index and not double_event_opening:
			break
	nodes_this_stage = prefix + [NodeType.BOSS]
	GameState.stage_node_orders[key] = nodes_this_stage.duplicate()

func _node_order_is_valid(order: Array) -> bool:
	if order.size() != 6 or order.back() != NodeType.BOSS:
		return false
	if order.count(NodeType.DICE) != 2 or order.count(NodeType.EVENT) != 2 or order.count(NodeType.SHOP) != 1:
		return false
	if order.find(NodeType.DICE) >= order.find(NodeType.SHOP):
		return false
	return not (order[0] == NodeType.EVENT and order[1] == NodeType.EVENT)

func _run_node(node_type: int) -> void:
	for child: Node in get_children():
		if child is Control and child != self:
			child.queue_free()
	await get_tree().process_frame
	match node_type:
		NodeType.DICE, NodeType.BOSS: _launch_battle(node_type == NodeType.BOSS)
		NodeType.EVENT: _launch_event()
		NodeType.SHOP: _launch_shop()

func _launch_battle(is_boss: bool) -> void:
	_is_boss_node = is_boss
	_battle_gold = CardPoolRef.get_battle_gold(current_stage_index)
	if not GameState.saved_battle_card_ids.is_empty():
		_drawn_cards.clear()
		for card_id in GameState.saved_battle_card_ids:
			var restored_card = CardData.get_card_by_id(card_id)
			if restored_card != null:
				_drawn_cards.append(restored_card)
		if not _drawn_cards.is_empty():
			_battle_reward_multiplier = GameState.get_battle_reward_multiplier(_drawn_cards)
			_actually_launch_battle()
			return

	# Build pool for manual card selection
	var mixed_pool := CardPoolRef.get_mixed_pool(current_stage_index)
	var boss_pool: Array = CardPoolRef.get_boss_pool(current_stage_index) if is_boss else []

	# Show card picking UI
	var card_ui := preload("res://scripts/ui/CardDrawUI.gd").new()
	card_ui.name = "CardDrawUI"
	add_child(card_ui)
	card_ui.setup(mixed_pool, boss_pool, self, is_boss, 2, current_stage_index, not _redraw_used)

func _on_card_redraw_requested() -> void:
	if _redraw_used: return
	_redraw_used = true
	_launch_battle(_is_boss_node)

## Called by CardDrawUI when player confirms selected cards
func _on_cards_confirmed(cards: Array) -> void:
	_drawn_cards = cards
	_battle_reward_multiplier = GameState.get_battle_reward_multiplier(cards)
	if _is_boss_node and current_stage_index == 3:
		await _show_prisoner_king_reveal()
	else:
		await _offer_prisoner_contract(cards)
	GameState.capture_battle_entry(cards)
	_actually_launch_battle()

func _offer_prisoner_contract(cards: Array) -> void:
	GameState.current_contract.clear()
	if cards.is_empty() or not GameState.prisoner_can_appear(current_stage_index):
		return
	GameState.record_prisoner_offer(current_stage_index)
	var offers: Array[Dictionary] = [
		{"id":"no_item", "title":"保持清醒", "desc":"本场不使用任何道具并获胜", "reward_type":"gold", "reward":25, "penalty_type":"gold", "penalty":10, "penalty_desc":"扣除10金币"},
		{"id":"bold_bid", "title":"大胆开价", "desc":"至少一次合法叫到存活人数＋4以上并获胜", "reward_type":"item", "reward":"common_random", "penalty_type":"gold", "penalty":15, "penalty_desc":"扣除15金币"},
		{"id":"five_twos", "title":"五个二", "desc":"至少一次合法叫到不少于5个②并获胜", "reward_type":"gold", "reward":30, "penalty_type":"gold", "penalty":12, "penalty_desc":"扣除12金币"},
		{"id":"three_faces", "title":"报遍三面", "desc":"整场合法叫过至少3种不同点数并获胜", "reward_type":"item", "reward":"common_random", "penalty_type":"gold", "penalty":10, "penalty_desc":"扣除10金币"},
		{"id":"three_rounds", "title":"熬过三轮", "desc":"至少完成3轮质疑结算后再获胜", "reward_type":"gold", "reward":35, "penalty_type":"next_die", "penalty":1, "penalty_desc":"下一场战斗基础骰子−1"},
	]
	offers.shuffle()
	var contracts: Array[Dictionary] = [offers[0].duplicate(true), offers[1].duplicate(true)]
	for contract in contracts:
		contract["source"] = "无名囚徒"
		contract["stage"] = current_stage_index
		if contract.penalty_type == "gold":
			contract["penalty_desc"] = "扣除%d金币" % (int(contract.penalty) + current_stage_index * 5)
	var overlay := ColorRect.new(); overlay.position = Vector2.ZERO; overlay.size = Vector2(1280, 720); overlay.color = Color(0.015, 0.01, 0.025, 0.94); overlay.z_index = 450; add_child(overlay)
	var title := Label.new(); title.text = "无名囚徒把两张契约推到你面前"; title.position = Vector2(240, 70); title.size = Vector2(800, 50); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size", 25); overlay.add_child(title)
	var story_lines: Array[String] = ["‘先让我看看，你是不是另一个只会说大话的人。’", "‘你又来了。盒子正在听，但它还不知道你是谁。’", "‘越靠近王座，卡牌里哭喊的声音就越清楚。’", "‘门后就是篡位者。先证明你还能承担承诺。’"]
	var story := Label.new(); story.text = story_lines[clampi(current_stage_index, 0, 3)]; story.position = Vector2(240, 125); story.size = Vector2(800, 34); story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; story.add_theme_font_size_override("font_size", 15); overlay.add_child(story)
	for i in range(2):
		var contract: Dictionary = contracts[i]
		var panel := ColorRect.new(); panel.position = Vector2(145 + i * 505, 190); panel.size = Vector2(485, 300); panel.color = Color(0.055, 0.035, 0.07, 0.98); overlay.add_child(panel)
		var name_label := Label.new(); name_label.text = str(contract.title); name_label.position = Vector2(20, 18); name_label.size = Vector2(445, 38); name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; name_label.add_theme_font_size_override("font_size", 21); panel.add_child(name_label)
		var desc := Label.new(); desc.text = "%s\n\n奖励：%s\n违约：%s" % [contract.desc, "%d金币" % contract.reward if contract.reward_type == "gold" else "1件普通道具", contract.penalty_desc]; desc.position = Vector2(28, 70); desc.size = Vector2(429, 135); desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; desc.add_theme_font_size_override("font_size", 15); panel.add_child(desc)
		var accept := Button.new(); accept.text = "接受这份契约"; accept.position = Vector2(115, 225); accept.size = Vector2(255, 48); accept.pressed.connect(_accept_prisoner_contract.bind(contract, overlay)); panel.add_child(accept)
	var reject := Button.new(); reject.text = "全部拒绝"; reject.position = Vector2(515, 535); reject.size = Vector2(250, 50); reject.pressed.connect(func(): overlay.queue_free(); contract_choice_resolved.emit()); overlay.add_child(reject)
	await contract_choice_resolved

func _accept_prisoner_contract(contract: Dictionary, overlay: Control) -> void:
	GameState.current_contract = contract.duplicate(true)
	GameState.record_prisoner_acceptance(current_stage_index)
	overlay.queue_free()
	contract_choice_resolved.emit()

func _show_prisoner_king_reveal() -> void:
	if GameState.prisoner_identity_revealed or not GameState.prisoner_king_arc_complete():
		return
	GameState.prisoner_identity_revealed = true
	GameState.royal_fragment_available = true
	var overlay := ColorRect.new(); overlay.position = Vector2.ZERO; overlay.size = Vector2(1280, 720); overlay.color = Color(0.012, 0.008, 0.022, 0.97); overlay.z_index = 470; add_child(overlay)
	var title := Label.new(); title.text = "被流放的国王"; title.position = Vector2(240, 90); title.size = Vector2(800, 55); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size", 30); overlay.add_child(title)
	var desc := Label.new(); desc.text = "无名囚徒终于翻开自己的卡面。\n\n‘我曾是这个国度的国王。骰子之神夺走王座，把我的子民压进卡牌，又把我流放到赌桌之外。’\n‘我一直在挑选一个守得住承诺的人。现在，把这块王权带到他面前。’\n\n获得独立碎片【王权碎片】\n若你在骰子之神战中完全同化，可消耗它重置并重战一次。"; desc.position = Vector2(250, 180); desc.size = Vector2(780, 300); desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; desc.add_theme_font_size_override("font_size", 18); overlay.add_child(desc)
	var proceed := Button.new(); proceed.text = "接过王权碎片"; proceed.position = Vector2(490, 535); proceed.size = Vector2(300, 56); proceed.pressed.connect(func(): overlay.queue_free(); contract_choice_resolved.emit()); overlay.add_child(proceed)
	await contract_choice_resolved

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
	GameState.clear_battle_entry()
	_redraw_used = false
	var unknown_count: int = 0
	for card in _drawn_cards:
		if card and card.rarity == CardData.Rarity.UNKNOWN:
			unknown_count += 1
	var unknown_gold_multiplier: float = 1.25 if unknown_count >= 2 else 1.0
	# Regular battle rewards; the independently generated shop node handles shopping.
	if not _is_boss_node and nodes_this_stage[current_node_index] == NodeType.DICE:
		GameState.add_gold(maxi(_battle_gold, floori(_battle_gold * _battle_reward_multiplier * unknown_gold_multiplier)))
		if unknown_count > 0:
			var elite_reward: String = CardPoolRef.get_rare_item() if unknown_count >= 2 else CardPoolRef.get_elite_item()
			if not GameState.add_consumable_item(elite_reward):
				await EventBus.discard_resolved
			GameState.add_rust_points(4 if unknown_count >= 2 else 2)
			GameState.save_progress()
		await _advance_node()
		return

	# Boss: give legendary item
	if _is_boss_node:
		GameState.add_gold(maxi(_battle_gold, floori(_battle_gold * _battle_reward_multiplier * unknown_gold_multiplier)))
		var leg_item: String = CardPoolRef.get_legendary_item()
		if not GameState.add_consumable_item(leg_item):
			await EventBus.discard_resolved
		EventBus.hint_show.emit("获得传说道具: " + GameState.get_item_info(leg_item).item_name, 3.0, Color(0.98, 0.78, 0.29))
		if unknown_count > 0:
			var elite_item: String = CardPoolRef.get_rare_item() if unknown_count >= 2 else CardPoolRef.get_elite_item()
			if not GameState.add_consumable_item(elite_item):
				await EventBus.discard_resolved
			GameState.add_rust_points(4 if unknown_count >= 2 else 2)
			EventBus.hint_show.emit("未知精英追加奖励：%s + %d锈蚀点" % ["保底稀有道具" if unknown_count >= 2 else "精英道具", 4 if unknown_count >= 2 else 2], 3.0, Color(0.75, 0.45, 0.85))
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
		if not _drawn_cards.is_empty():
			var boss_card = _drawn_cards.back()
			if boss_card and BossFragmentDataRef.has_definition(boss_card.card_id):
				await _award_boss_fragment(boss_card.card_id)
		await _advance_node()
		return
	await _advance_node()

func _advance_node() -> void:
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
	await _advance_node()

func _award_boss_fragment(card_id: String) -> void:
	var result: String = GameState.add_boss_fragment(card_id)
	var fragment_name: String = BossFragmentDataRef.get_fragment_name(card_id)
	if result == "added":
		EventBus.hint_show.emit("获得Boss碎片：%s" % fragment_name, 4.0, Color(0.98, 0.78, 0.29))
		return
	if result == "duplicate":
		EventBus.hint_show.emit("已持有%s，同名碎片不叠加" % fragment_name, 3.0, Color(0.72, 0.72, 0.78))
		return
	if result != "full":
		return
	var overlay := ColorRect.new()
	overlay.name = "FragmentReplaceOverlay"
	overlay.position = Vector2.ZERO
	overlay.size = Vector2(1280, 720)
	overlay.color = Color(0.01, 0.01, 0.02, 0.94)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 500
	add_child(overlay)
	var title := Label.new()
	title.text = "Boss碎片已满"
	title.position = Vector2(340, 100); title.size = Vector2(600, 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.98, 0.78, 0.29))
	overlay.add_child(title)
	var desc := Label.new()
	desc.text = "新碎片：%s\n%s\n\n选择要替换的碎片，或丢弃新碎片。" % [fragment_name, BossFragmentDataRef.get_fragment_desc(card_id)]
	desc.position = Vector2(290, 165); desc.size = Vector2(700, 110)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 17)
	overlay.add_child(desc)
	for i in range(GameState.boss_fragments.size()):
		var old_id: String = GameState.boss_fragments[i]
		var button := Button.new()
		button.text = "替换 %s" % BossFragmentDataRef.get_fragment_name(old_id)
		button.position = Vector2(300 + i * 350, 330); button.size = Vector2(280, 54)
		button.pressed.connect(func(index: int = i):
			GameState.replace_boss_fragment(index, card_id)
			overlay.queue_free()
			fragment_choice_resolved.emit())
		overlay.add_child(button)
	var discard := Button.new()
	discard.text = "丢弃 %s" % fragment_name
	discard.position = Vector2(500, 430); discard.size = Vector2(280, 54)
	discard.pressed.connect(func():
		overlay.queue_free()
		fragment_choice_resolved.emit())
	overlay.add_child(discard)
	await fragment_choice_resolved

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
