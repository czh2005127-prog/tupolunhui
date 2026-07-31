## ShopUI — 展示架风格: 情报横条(上) → 货架卡片(中) → 道具挂钩(下)
extends Control

var _flow: Node
var _refresh_count: int = 0
var _shelf_root: Control

func set_parent_flow(f: Node) -> void:
	_flow = f
	_refresh_count = 0
	GameState.refresh_shop(6)
	_build()

func _build() -> void:
	for child in get_children():
		child.queue_free()

	var bg := ColorRect.new()
	bg.color = Color(0.027, 0.027, 0.039)
	bg.anchor_right = 1.0; bg.anchor_bottom = 1.0
	add_child(bg)

	# ── Top bar ──
	_draw_topbar()
	# ── Intel strip ──
	_draw_intel_strip()
	# ── Shelf + cards ──
	_draw_shelf()
	# ── Inventory hooks ──
	_draw_inv_hooks()

# ═══════════════════════════════════════════════
# TOP BAR
# ═══════════════════════════════════════════════
func _draw_topbar() -> void:
	var y := 14.0
	var gold := Label.new()
	gold.name = "GoldLbl"
	gold.text = "%d" % GameState.gold
	gold.position = Vector2(30, y)
	gold.add_theme_font_size_override("font_size", 15)
	gold.add_theme_color_override("font_color", Color(0.835, 0.647, 0.208))
	add_child(gold)

	var stage_names: Array[String] = ["破烂后院", "地下赌场", "黑帮私局", "终极赌场"]
	var tag := Label.new()
	tag.text = "%s · 商店" % stage_names[clamp(GameState.current_stage, 0, 3)]
	tag.position = Vector2(100, y + 2)
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_color_override("font_color", Color(0.35, 0.35, 0.42))
	add_child(tag)

	var exit := Button.new()
	exit.text = "退出"
	exit.position = Vector2(1200, y - 2); exit.size = Vector2(56, 24)
	exit.flat = true
	var es := StyleBoxFlat.new(); es.bg_color = Color(0.12, 0.12, 0.18)
	exit.add_theme_stylebox_override("normal", es)
	exit.add_theme_font_size_override("font_size", 11)
	exit.pressed.connect(_on_continue)
	add_child(exit)

# ═══════════════════════════════════════════════
# INTEL STRIP
# ═══════════════════════════════════════════════
func _draw_intel_strip() -> void:
	var y := 50.0
	var strip_h := 46.0
	var x := 30.0
	var col_w := 280

	var bg := ColorRect.new()
	bg.name = "IntelStrip"
	bg.position = Vector2(x, y)
	bg.size = Vector2(1220, strip_h)
	bg.color = Color(0.039, 0.039, 0.055)
	add_child(bg)

	var stage_names: Array[String] = ["破烂后院", "地下赌场", "黑帮私局", "终极赌场"]
	var mutation_names: Array[String] = ["标准规则", "每人1颗暗骰", "黑吃黑", "圣洁禁忌"]
	var boss_names: Array[String] = ["瘸腿老杰克", "独眼龙老板娘", "西装暴徒三人组", "骰子之神HOLO"]

	_intel_block(x, y, strip_h, "变质规则", mutation_names[clamp(GameState.current_stage, 0, 3)])
	x += col_w
	_intel_block(x, y, strip_h, "关卡进度", "%s · %d/5" % [stage_names[clamp(GameState.current_stage, 0, 3)], GameState.current_node_index + 1])
	x += col_w

	var defeated := ""
	for s in range(GameState.current_stage):
		if s < boss_names.size():
			if defeated != "": defeated += ", "
			defeated += boss_names[s]
	if defeated == "": defeated = "暂无"
	_intel_block(x, y, strip_h, "已击败", defeated)
	x += col_w

	# Continue button in last column
	var cbtn := Button.new()
	cbtn.text = "继续"
	cbtn.position = Vector2(x + 20, y + 8); cbtn.size = Vector2(160, 30)
	cbtn.flat = true
	var cs := StyleBoxFlat.new(); cs.bg_color = Color(0.102, 0.165, 0.102)
	cbtn.add_theme_stylebox_override("normal", cs)
	var chs := StyleBoxFlat.new(); chs.bg_color = Color(0.125, 0.227, 0.125)
	cbtn.add_theme_stylebox_override("hover", chs)
	cbtn.add_theme_font_size_override("font_size", 12)
	cbtn.add_theme_color_override("font_color", Color(0.227, 0.478, 0.227))
	cbtn.pressed.connect(_on_continue)
	add_child(cbtn)

func _intel_block(x: float, y: float, h: float, label: String, value: String) -> void:
	var sep := ColorRect.new()
	sep.position = Vector2(x, y + 6); sep.size = Vector2(1, h - 12)
	sep.color = Color(0.086, 0.086, 0.149)
	add_child(sep)

	var tl := Label.new()
	tl.text = label
	tl.position = Vector2(x + 12, y + 4)
	tl.add_theme_font_size_override("font_size", 9)
	tl.add_theme_color_override("font_color", Color(0.227, 0.227, 0.314))
	add_child(tl)

	var vl := Label.new()
	vl.text = value
	vl.position = Vector2(x + 12, y + 20)
	vl.size = Vector2(256, 22)
	vl.add_theme_font_size_override("font_size", 11)
	vl.add_theme_color_override("font_color", Color(0.502, 0.502, 0.565))
	add_child(vl)

# ═══════════════════════════════════════════════
# SHELF + CARDS
# ═══════════════════════════════════════════════
func _draw_shelf() -> void:
	if _shelf_root and is_instance_valid(_shelf_root):
		_shelf_root.queue_free()
	_shelf_root = Control.new()
	_shelf_root.name = "ShelfRoot"
	add_child(_shelf_root)

	var items: Array = GameState.shop_items.duplicate()
	var card_w := 180
	var card_h := 220
	var gap := 10
	var total_w: float = items.size() * card_w + (items.size() - 1) * gap
	var start_x: float = (1280 - total_w) / 2
	var y := 110.0

	# Shelf bg
	var shelf := ColorRect.new()
	shelf.name = "ShelfBg"
	shelf.position = Vector2(start_x - 12, y - 6)
	shelf.size = Vector2(total_w + 24, card_h + 18)
	shelf.color = Color(0.102, 0.086, 0.055)
	_shelf_root.add_child(shelf)

	# Shelf top highlight
	var top_edge := ColorRect.new()
	top_edge.name = "ShelfTop"
	top_edge.position = Vector2(shelf.position.x + 8, shelf.position.y)
	top_edge.size = Vector2(shelf.size.x - 16, 1)
	top_edge.color = Color(1, 1, 1, 0.04)
	_shelf_root.add_child(top_edge)

	for i in range(items.size()):
		var item = items[i]
		var cx := start_x + i * (card_w + gap)
		_draw_item_card(_shelf_root, cx, y, card_w, card_h, item)

	# Refresh
	var refresh_cost: int = 5 + _refresh_count * 5
	var rbtn := Button.new()
	rbtn.text = "刷新货架 · %d点" % refresh_cost
	rbtn.position = Vector2((1280 - 160) / 2, y + card_h + 16)
	rbtn.size = Vector2(160, 28); rbtn.flat = true
	var rs := StyleBoxFlat.new(); rs.bg_color = Color(0.102, 0.102, 0.18)
	rbtn.add_theme_stylebox_override("normal", rs)
	rbtn.add_theme_font_size_override("font_size", 11)
	rbtn.add_theme_color_override("font_color", Color(0.345, 0.345, 0.376))
	rbtn.pressed.connect(_on_refresh)
	_shelf_root.add_child(rbtn)

func _draw_item_card(parent: Control, cx: float, cy: float, w: int, h: int, item) -> void:
	var bg := ColorRect.new()
	bg.name = "Card_%s" % item.item_id
	bg.position = Vector2(cx, cy); bg.size = Vector2(w, h)
	bg.color = Color(0.071, 0.071, 0.149)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP

	var top_stripe := ColorRect.new()
	top_stripe.position = Vector2(0, 0); top_stripe.size = Vector2(w, 4)
	top_stripe.color = item.get_rarity_color()
	bg.add_child(top_stripe)

	var icon := Label.new()
	icon.text = _card_icon(item.item_id)
	icon.position = Vector2(0, 20); icon.size = Vector2(w, 80)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 36)
	icon.add_theme_color_override("font_color", Color(1, 1, 1, 0.08))
	bg.add_child(icon)

	var name := Label.new()
	name.text = item.item_name
	name.position = Vector2(4, 104); name.size = Vector2(w - 8, 22)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size", 12)
	name.add_theme_color_override("font_color", Color(0.753, 0.753, 0.816))
	bg.add_child(name)

	var rarity_tag := Label.new()
	rarity_tag.text = item.get_rarity_name()
	rarity_tag.position = Vector2(w - 48, 8); rarity_tag.size = Vector2(42, 16)
	rarity_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rarity_tag.add_theme_font_size_override("font_size", 8)
	rarity_tag.add_theme_color_override("font_color", item.get_rarity_color())
	bg.add_child(rarity_tag)

	var desc := Label.new()
	desc.text = item.description
	desc.position = Vector2(6, 128); desc.size = Vector2(w - 12, 36)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 9)
	desc.add_theme_color_override("font_color", Color(0.314, 0.314, 0.376))
	bg.add_child(desc)

	var price := Label.new()
	price.text = "%d" % item.price
	price.position = Vector2(0, 168); price.size = Vector2(w, 30)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.add_theme_font_size_override("font_size", 18)
	price.add_theme_color_override("font_color", Color(0.835, 0.647, 0.208))
	bg.add_child(price)

	var item_ref: Resource = item
	bg.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_on_buy(item_ref)
	)
	parent.add_child(bg)

func _card_icon(item_id: String) -> String:
	match item_id:
		"reroll_stone": return "🎲"
		"freeze_die": return "📌"
		"split_die": return "✂️"
		"full_reroll": return "🔀"
		"clone_die": return "📋"
		"flip_die": return "🔄"
		"see_dark": return "👁"
		"heat_vision": return "🔭"
		"emergency_restart": return "⚖️"
		"silent_turn": return "🔇"
		"fate_die": return "✨"
		"extra_die": return "➕"
		"purge_chip": return "💊"
		"gambler_hunch": return "🎯"
		"payout": return "💰"
		"rig_dice": return "🎭"
		"sabotage": return "⚡"
	return "📦"

# ═══════════════════════════════════════════════
# INVENTORY HOOKS
# ═══════════════════════════════════════════════
func _draw_inv_hooks() -> void:
	var y := 454.0
	var held: Array[String] = GameState.consumable_items.duplicate()

	var tag := Label.new()
	tag.name = "InvTag"
	tag.text = "道具栏"
	tag.position = Vector2(30, y + 2)
	tag.add_theme_font_size_override("font_size", 9)
	tag.add_theme_color_override("font_color", Color(0.227, 0.227, 0.314))
	add_child(tag)

	if held.size() == 0:
		var empty := Label.new()
		empty.name = "InvEmpty"
		empty.text = "空空如也"
		empty.position = Vector2(90, y + 2)
		empty.add_theme_font_size_override("font_size", 9)
		empty.add_theme_color_override("font_color", Color(0.18, 0.18, 0.24))
		add_child(empty)
		return

	var start_x := 90
	for i in range(held.size()):
		var sx := start_x + i * 130
		var bg := ColorRect.new()
		bg.name = "Held_%d" % i
		bg.position = Vector2(sx, y)
		bg.size = Vector2(120, 22)
		bg.color = Color(0.047, 0.055, 0.079)
		add_child(bg)

		var nl := Label.new()
		nl.name = "Held_lbl%d" % i
		var info: ItemData = GameState.get_item_info(held[i])
		var nm: String = held[i]
		if info: nm = info.item_name
		nl.text = nm
		nl.position = bg.position; nl.size = bg.size
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nl.add_theme_font_size_override("font_size", 9)
		nl.add_theme_color_override("font_color", Color(0.227, 0.416, 0.604))
		add_child(nl)

# ═══════════════════════════════════════════════
# BUY / REFRESH / CONTINUE
# ═══════════════════════════════════════════════
func _on_buy(item: Resource) -> void:
	if GameState.gold < item.price:
		_show_warning("点数不足!")
		return
	if GameState.consumable_items.size() >= GameState.MAX_CONSUMABLE:
		_show_discard_swapper(item.item_id, item)
		return
	GameState.spend_gold(item.price)
	GameState.add_consumable_item(item.item_id)
	_remove_from_shop(item)
	_refresh_gold()
	_update_inv_hooks()
	_update_shelf()

func _remove_from_shop(item: Resource) -> void:
	var i: int = 0
	while i < GameState.shop_items.size():
		if GameState.shop_items[i] == item or GameState.shop_items[i].item_id == item.item_id:
			GameState.shop_items.remove_at(i)
		else:
			i += 1

func _show_discard_swapper(new_id: String, item: Resource) -> void:
	var held: Array[String] = GameState.consumable_items.duplicate()
	var layer := CanvasLayer.new()
	layer.name = "DiscardPopup"
	layer.layer = 100
	add_child(layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.anchor_right = 1.0; dim.anchor_bottom = 1.0
	dim.gui_input.connect(func(ev: InputEvent): pass)
	layer.add_child(dim)

	var panel := ColorRect.new()
	panel.position = Vector2(200, 160); panel.size = Vector2(880, 360)
	panel.color = Color(0.04, 0.04, 0.08)
	layer.add_child(panel)

	var title := Label.new()
	title.text = "道具栏已满，选择替换"
	title.position = Vector2(0, 8); title.size = Vector2(880, 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.88, 0.44, 0.63))
	panel.add_child(title)

	for i in range(held.size()):
		var info: ItemData = GameState.get_item_info(held[i])
		var btn := Button.new()
		btn.text = (info.item_name if info else held[i]) + " → 换成 " + item.item_name
		btn.position = Vector2(60, 50 + i * 36); btn.size = Vector2(760, 30)
		btn.flat = true
		var bs := StyleBoxFlat.new(); bs.bg_color = Color(0.08, 0.08, 0.14)
		btn.add_theme_stylebox_override("normal", bs)
		btn.add_theme_font_size_override("font_size", 11)
		btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		var item_id: String = item.item_id
		var item_ref: Resource = item
		var price: int = item.price
		var idx: int = i
		btn.pressed.connect(func():
			if GameState.gold < price:
				layer.queue_free()
				_show_warning("点数不足!")
				return
			GameState.spend_gold(price)
			GameState.force_swap_consumable(new_id, idx)
			_remove_from_shop(item_ref)
			layer.queue_free()
			_refresh_gold()
			_update_inv_hooks()
			_update_shelf()
		)
		panel.add_child(btn)

	var cancel := Button.new()
	cancel.text = "放弃购买"
	cancel.position = Vector2(360, 320); cancel.size = Vector2(160, 30)
	cancel.flat = true
	var cs := StyleBoxFlat.new(); cs.bg_color = Color(0.2, 0.08, 0.08)
	cancel.add_theme_stylebox_override("normal", cs)
	cancel.add_theme_font_size_override("font_size", 11)
	cancel.pressed.connect(func():
		GameState.gold += item.price
		layer.queue_free()
		_refresh_gold())
	panel.add_child(cancel)

func _on_refresh() -> void:
	var cost: int = 5 + _refresh_count * 5
	if GameState.gold < cost:
		_show_warning("刷新需要 %d 点!" % cost)
		return
	GameState.spend_gold(cost)
	_refresh_count += 1
	GameState.refresh_shop(6)
	_refresh_gold()
	_update_shelf()

func _on_continue() -> void:
	EventBus.shop_exited.emit()
	queue_free()

# ═══════════════════════════════════════════════
# UPDATE HELPERS
# ═══════════════════════════════════════════════
func _refresh_gold() -> void:
	for child in get_children():
		if child is Label and "GoldLbl" in str(child.name):
			child.text = "%d" % GameState.gold

func _show_warning(text: String) -> void:
	var warn := Label.new()
	warn.text = text
	warn.position = Vector2(500, 4)
	warn.size = Vector2(280, 24)
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn.add_theme_font_size_override("font_size", 12)
	warn.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	add_child(warn)
	var tw: Tween = create_tween()
	tw.tween_property(warn, "modulate:a", 0.0, 1.5)
	tw.tween_callback(warn.queue_free)

func _update_shelf() -> void:
	for child in get_children():
		var n: String = child.name
		if n.begins_with("Card_") or n.begins_with("Shelf"):
			child.queue_free()
	_draw_shelf()

func _update_inv_hooks() -> void:
	for child in get_children():
		var n: String = child.name
		if n.begins_with("Held_") or n == "InvTag" or n == "InvEmpty":
			child.queue_free()
	_draw_inv_hooks()
