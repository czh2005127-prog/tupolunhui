## RustWorkshop — card album upgrade UI
extends Control

const CARD_W := 170
const CARD_H := 238
const GAP := 14
const GRID_X := 40
const GRID_Y := 90
const COLS := 5

var _all_cards: Array = []
var _filter: int = -1
var _selected_id: String = ""
var _card_slots: Array = []
var _detail_overlay: Node = null
var _scroll_container: ScrollContainer = null
var _grid_parent: Control = null

func _ready() -> void:
	_build()

func _build() -> void:
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame

	var bg := ColorRect.new()
	bg.color = Color(0.031, 0.031, 0.047)
	bg.anchor_right = 1.0; bg.anchor_bottom = 1.0
	add_child(bg)

	var title := Label.new()
	title.text = "锈蚀工坊"
	title.position = Vector2(GRID_X, 26)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.83, 0.66, 0.29))
	add_child(title)

	var pts := Label.new()
	pts.name = "RustPts"
	pts.text = "%d 锈蚀点" % GameState.rust_points
	pts.position = Vector2(GRID_X, 56)
	pts.add_theme_font_size_override("font_size", 12)
	pts.add_theme_color_override("font_color", Color(0.72, 0.47, 0.09))
	add_child(pts)

	var reset_btn := _make_btn(Vector2(1050, 26), Vector2(120, 32), "清空", Color(0.22, 0.18, 0.22), func():
		GameState.clear_all_levels()
		_close_detail()
		_selected_id = ""
		_build()
	)

	_create_filters()
	_load_cards()

	_scroll_container = ScrollContainer.new()
	_scroll_container.position = Vector2(0, GRID_Y)
	_scroll_container.size = Vector2(1280, 720 - GRID_Y)
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(_scroll_container)

	_grid_parent = Control.new()
	_scroll_container.add_child(_grid_parent)

	_draw_grid()
	var back := _make_btn(Vector2(GRID_X, GRID_Y + 4 * (CARD_H + GAP) + 10), Vector2(100, 36), "返回", Color(0.35, 0.35, 0.38), _on_back)
	_grid_parent.add_child(back)

	var top_back := _make_btn(Vector2(1150, 56), Vector2(80, 28), "返回", Color(0.35, 0.35, 0.38), _on_back)

func _create_filters() -> void:
	var filters := [
		{"label": "全部", "rarity": -1},
		{"label": "普通", "rarity": 0},
		{"label": "稀有", "rarity": 1},
		{"label": "史诗", "rarity": 2},
		{"label": "传说", "rarity": 3},
	]
	var x := GRID_X
	for f in filters:
		var r: int = f["rarity"]
		var btn := _make_btn(Vector2(x, 66), Vector2(48, 20), f["label"], Color(0.18, 0.18, 0.22), func():
			_filter = r
			if _scroll_container: _scroll_container.scroll_vertical = 0
			_draw_grid()
		)
		if _filter == f["rarity"]:
			var s := StyleBoxFlat.new()
			s.bg_color = Color(0.1, 0.16, 0.23)
			btn.add_theme_stylebox_override("normal", s)
		x += 56

func _load_cards() -> void:
	_all_cards.clear()
	for pool in [CardData.get_common_pool(), CardData.get_rare_pool(), CardData.get_epic_pool(), CardData.get_legendary_pool(), CardData.get_genesis_pool(), CardData.get_unknown_pool()]:
		for card in pool:
			_all_cards.append(card)

func _draw_grid() -> void:
	for child in _grid_parent.get_children():
		child.queue_free()
	_card_slots.clear()

	var filtered: Array = []
	for card in _all_cards:
		if _filter < 0 or card.rarity == _filter:
			filtered.append(card)

	var rows: int = ceili(float(filtered.size()) / COLS)
	_grid_parent.custom_minimum_size = Vector2(1280, max(600, GRID_Y + rows * (CARD_H + GAP) + GAP + 60))

	var idx := 0
	var max_per_page := COLS * 5
	for card in filtered:
		if idx >= max_per_page: break
		var col := idx % COLS
		var row := idx / COLS
		var rx := GRID_X + col * (CARD_W + GAP)
		var ry := GRID_Y + row * (CARD_H + GAP)
		_draw_card(rx, ry, card, idx)
		idx += 1

func _is_card_unlocked(card: CardData) -> bool:
	if card.rarity >= CardData.Rarity.GENESIS:
		return true
	return card.card_id in GameState.unlocked_cards

func _draw_card(rx: float, ry: float, card: CardData, idx: int) -> void:
	var cid: String = card.card_id
	var locked: bool = not _is_card_unlocked(card)
	var card_prefix := "Card_%d" % idx

	# Background
	var bg := ColorRect.new()
	bg.name = card_prefix
	bg.position = Vector2(rx, ry)
	bg.size = Vector2(CARD_W, CARD_H)
	if locked:
		bg.color = Color(0.08, 0.08, 0.12)
	else:
		bg.color = _rarity_bg(card.rarity)
	if not locked:
		bg.mouse_filter = Control.MOUSE_FILTER_STOP
		bg.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_selected_id = cid
				_show_detail(CardData.get_card_by_id(cid))
				_draw_grid()
		)
	_grid_parent.add_child(bg)
	_card_slots.append(bg)

	if locked:
		var q := Label.new()
		q.text = "???"
		q.position = Vector2(rx, ry + 70)
		q.size = Vector2(CARD_W, 60)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.add_theme_font_size_override("font_size", 36)
		q.add_theme_color_override("font_color", Color(0.2, 0.2, 0.25))
		_grid_parent.add_child(q)
		var lock := Label.new()
		lock.text = "未解锁"
		lock.position = Vector2(rx, ry + 140)
		lock.size = Vector2(CARD_W, 30)
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock.add_theme_font_size_override("font_size", 13)
		lock.add_theme_color_override("font_color", Color(0.25, 0.25, 0.35))
		_grid_parent.add_child(lock)
		return

	var is_sel := (card.card_id == _selected_id)
	if is_sel:
		var sel_border := ColorRect.new()
		sel_border.name = card_prefix + "_sel"
		sel_border.position = Vector2(rx, ry)
		sel_border.size = Vector2(CARD_W, CARD_H)
		sel_border.color = Color(0.35, 0.6, 0.8, 0.2)
		_grid_parent.add_child(sel_border)

	var name_lbl := Label.new()
	name_lbl.name = card_prefix + "_name"
	name_lbl.text = card.card_name
	name_lbl.position = Vector2(rx + 10, ry + 8)
	name_lbl.size = Vector2(CARD_W - 20, 22)
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", _rarity_name_color(card.rarity))
	_grid_parent.add_child(name_lbl)

	var rar_lbl := Label.new()
	rar_lbl.name = card_prefix + "_rar"
	rar_lbl.text = card.get_rarity_name()
	rar_lbl.position = Vector2(rx + 10, ry + 28)
	rar_lbl.size = Vector2(CARD_W - 20, 16)
	rar_lbl.add_theme_font_size_override("font_size", 9)
	rar_lbl.add_theme_color_override("font_color", _rarity_sub_color(card.rarity))
	_grid_parent.add_child(rar_lbl)

	var portrait := ColorRect.new()
	portrait.name = card_prefix + "_portrait"
	portrait.position = Vector2(rx + 12, ry + 52)
	portrait.size = Vector2(CARD_W - 24, CARD_W - 24 + 28)
	portrait.color = _portrait_bg(card.rarity)
	_grid_parent.add_child(portrait)

	var pletter := Label.new()
	pletter.name = card_prefix + "_pletter"
	pletter.text = card.card_name.substr(0, 1)
	pletter.position = portrait.position
	pletter.size = portrait.size
	pletter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pletter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pletter.add_theme_font_size_override("font_size", 42)
	pletter.add_theme_color_override("font_color", _portrait_letter(card.rarity))
	_grid_parent.add_child(pletter)

	var skill_y: float = ry + 52 + (CARD_W - 24 + 28) + 6
	var skill_lbl := Label.new()
	skill_lbl.name = card_prefix + "_skill"
	skill_lbl.text = card.skill_name + " — " + card.skill_desc.left(20)
	skill_lbl.position = Vector2(rx + 10, skill_y)
	skill_lbl.size = Vector2(CARD_W - 20, 30)
	skill_lbl.add_theme_font_size_override("font_size", 9)
	skill_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	_grid_parent.add_child(skill_lbl)

	var lv := GameState.get_card_level(card.card_id)
	var mx := GameState.get_max_level_for_card(card.card_id)
	if mx > 0:
		for i in range(mx):
			var dot := ColorRect.new()
			dot.name = card_prefix + "_dot%d" % i
			dot.position = Vector2(rx + CARD_W - 14 - (mx - i) * 10, ry + CARD_H - 14)
			dot.size = Vector2(6, 6)
			dot.color = Color(0.35, 0.6, 0.8) if i < lv else Color(0.16, 0.16, 0.2)
			_grid_parent.add_child(dot)

func _show_detail(card: CardData) -> void:
	_close_detail()
	var layer := CanvasLayer.new()
	layer.name = "DetailOverlay"
	layer.layer = 100
	_detail_overlay = layer
	add_child(layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.anchor_right = 1.0; dim.anchor_bottom = 1.0
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_close_detail()
			_selected_id = ""
			_draw_grid.call_deferred()
	)
	layer.add_child(dim)

	var panel := ColorRect.new()
	panel.name = "DetailPanel"
	panel.position = Vector2(420, 210)
	panel.size = Vector2(440, 300)
	panel.color = Color(0.07, 0.07, 0.1)
	layer.add_child(panel)

	var pbg := ColorRect.new()
	pbg.position = Vector2(12, 12)
	pbg.size = Vector2(80, 112)
	pbg.color = _portrait_bg(card.rarity)
	panel.add_child(pbg)

	var pletter := Label.new()
	pletter.text = card.card_name.substr(0, 1)
	pletter.position = pbg.position
	pletter.size = pbg.size
	pletter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pletter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pletter.add_theme_font_size_override("font_size", 32)
	pletter.add_theme_color_override("font_color", _portrait_letter(card.rarity))
	panel.add_child(pletter)

	var px := 108
	var name_lbl := Label.new()
	name_lbl.text = card.card_name
	name_lbl.position = Vector2(px, 12)
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", _rarity_name_color(card.rarity))
	panel.add_child(name_lbl)

	var rar_lbl := Label.new()
	rar_lbl.text = card.get_rarity_name() + " · " + card.card_id.to_upper()
	rar_lbl.position = Vector2(px, 32)
	rar_lbl.add_theme_font_size_override("font_size", 9)
	rar_lbl.add_theme_color_override("font_color", _rarity_sub_color(card.rarity))
	panel.add_child(rar_lbl)

	var desc := Label.new()
	var lv := GameState.get_card_level(card.card_id)
	var lines := _get_level_descs(card.card_id)
	var desc_text: String = card.skill_desc
	if lv > 0 and lv <= lines.size():
		desc_text = lines[lv - 1]
	desc.text = desc_text
	desc.position = Vector2(px, 50)
	desc.size = Vector2(320, 28)
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", Color(0.35, 0.6, 0.8))
	panel.add_child(desc)

	_show_level_path(panel, card, px)

	var mx := GameState.get_max_level_for_card(card.card_id)
	var cost: int = GameState.get_upgrade_cost_for_rarity(card.rarity) + lv
	var pts := GameState.rust_points
	var can_up := lv < mx and pts >= cost
	var can_down := lv > 0

	var line := ColorRect.new()
	line.position = Vector2(px, 250)
	line.size = Vector2(320, 1)
	line.color = Color(0.15, 0.15, 0.2)
	panel.add_child(line)

	var cost_lbl := Label.new()
	cost_lbl.text = "费用 %d 点" % cost
	cost_lbl.position = Vector2(px, 260)
	cost_lbl.add_theme_font_size_override("font_size", 10)
	cost_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	panel.add_child(cost_lbl)

	if can_up:
		var cid: String = card.card_id
		var upbtn := _make_btn(Vector2(px + 80, 254), Vector2(60, 24), "升阶", Color(0.35, 0.6, 0.8), func():
			if GameState.upgrade_card(cid):
				_refresh_points()
				_show_detail(CardData.get_card_by_id(cid))
				_draw_grid()
		, panel)
	elif lv >= mx:
		var max_lbl := Label.new()
		max_lbl.text = "已满级"
		max_lbl.position = Vector2(px + 80, 260)
		max_lbl.add_theme_font_size_override("font_size", 10)
		max_lbl.add_theme_color_override("font_color", Color(0.7, 0.55, 0.2))
		panel.add_child(max_lbl)
	else:
		var nope := Label.new()
		nope.text = "点数不足"
		nope.position = Vector2(px + 80, 260)
		nope.add_theme_font_size_override("font_size", 10)
		nope.add_theme_color_override("font_color", Color(0.6, 0.25, 0.25))
		panel.add_child(nope)

	if can_down:
		var cid: String = card.card_id
		var dnbtn := _make_btn(Vector2(px + 150, 254), Vector2(60, 24), "降级", Color(0.6, 0.4, 0.25), func():
			if GameState.downgrade_card(cid):
				_refresh_points()
				_show_detail(CardData.get_card_by_id(cid))
				_draw_grid()
		, panel)
	else:
		var dn_lbl := Label.new()
		dn_lbl.text = "降级"
		dn_lbl.position = Vector2(px + 150, 254)
		dn_lbl.size = Vector2(60, 24)
		dn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dn_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dn_lbl.add_theme_font_size_override("font_size", 10)
		dn_lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
		panel.add_child(dn_lbl)
		var avail := Label.new()
		avail.text = "持有 %d 点" % pts
		avail.position = Vector2(340, 262)
		avail.add_theme_font_size_override("font_size", 9)
		avail.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		panel.add_child(avail)
	var close_btn := _make_btn(Vector2(408, 6), Vector2(22, 22), "x", Color(0.4, 0.25, 0.25), func():
		_close_detail()
		_selected_id = ""
		_draw_grid()
	, panel)

func _show_level_path(panel: Control, card: CardData, px: float) -> void:
	var lv := GameState.get_card_level(card.card_id)
	var mx := GameState.get_max_level_for_card(card.card_id)
	if mx <= 0: return
	var lines := _get_level_descs(card.card_id)
	var y := 84.0
	var title := Label.new()
	title.text = "升阶路线"
	title.position = Vector2(px, y)
	title.add_theme_font_size_override("font_size", 9)
	title.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	panel.add_child(title)
	y += 16
	for i in range(mx):
		var row := Label.new()
		var is_cur := (i == lv)
		var is_next := (i == lv + 1 and lv < mx)
		var lv_text := "Lv.%d" % (i + 1)
		if is_cur: lv_text += " <"
		var line := ""
		if i < lines.size(): line = lines[i]
		row.text = "%s  %s" % [lv_text, line]
		row.position = Vector2(px, y)
		row.add_theme_font_size_override("font_size", 10)
		if is_cur:
			row.add_theme_color_override("font_color", Color(0.35, 0.6, 0.8))
		elif is_next:
			row.add_theme_color_override("font_color", Color(0.35, 0.6, 0.8))
		else:
			row.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		panel.add_child(row)
		var sep := ColorRect.new()
		sep.position = Vector2(px, y + 16)
		sep.size = Vector2(320, 1)
		sep.color = Color(0.1, 0.1, 0.14)
		panel.add_child(sep)
		y += 20

func _get_level_descs(card_id: String) -> Array:
	match card_id:
		"jack_crt": return ["每局1次：看2颗骰子", "每局1次：看2颗+可用2次", "每局1次：看3颗+2次+公开"]
		"rust_warrior": return ["淘汰时给2人生存+1骰①", "淘汰时对手-1骰", "淘汰时所有存活者+1骰①+对手-1骰"]
		"battery_kid": return ["免死2次", "免死3次", "免死3次+每次+1骰"]
		"signal_noise": return ["禁用玩家2个道具", "禁用玩家3个道具", "禁用玩家4个道具"]
		"cyclops_lcd": return ["每局删2个点数", "每局删3个点数", "每局删3个+暴露对手1骰"]
		"chamberlain": return ["开局获得5个道具", "5道具+保底1稀有", "6道具+保底2稀有"]
		"recycler": return ["有人开失败+2骰", "+2骰+吸对手1骰", "+2+吸+每局结束+1骰"]
		"lucky_one": return ["骰子永远多2个①", "骰子永远多3个①", "多3个①+他的①别人当不了万能"]
		"referee": return ["第2轮强制所有人开", "第2轮开+公布危险点数", "第1轮结束强制开+危险点数"]
		"table_ghost": return ["淘汰后附身2个对手", "附身2人+被附身1轮免疫质疑", ""]
		"alliance_oled": return ["知道n-1人的全部骰子", "", ""]
		"casino_owner": return ["每人+2颗暗骰", "+2暗骰+自己能看", "每人+3暗骰+自己全看到"]
		"prophet": return ["重掷后+1骰", "重掷后+1骰+每轮可重掷2次", ""]
	return ["—"]

func _close_detail() -> void:
	if _detail_overlay and is_instance_valid(_detail_overlay):
		_detail_overlay.queue_free()
		_detail_overlay = null

func _refresh_points() -> void:
	for child in get_children():
		if "RustPts" in str(child.name):
			child.text = "%d 锈蚀点" % GameState.rust_points

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _make_btn(pos: Vector2, size: Vector2, text: String, col: Color, cb: Callable, parent: Control = null) -> Button:
	var p := parent if parent else self
	var btn := Button.new()
	btn.position = pos; btn.size = size
	btn.text = text
	btn.flat = true
	var style := StyleBoxFlat.new()
	style.bg_color = col
	btn.add_theme_stylebox_override("normal", style)
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = col.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	btn.add_theme_font_size_override("font_size", 10)
	btn.pressed.connect(cb)
	p.add_child(btn)
	return btn

func _rarity_bg(r: int) -> Color:
	match r:
		0: return Color(0.11, 0.09, 0.07)
		1: return Color(0.07, 0.1, 0.14)
		2: return Color(0.09, 0.07, 0.13)
		3: return Color(0.11, 0.09, 0.05)
		4: return Color(0.1, 0.05, 0.05)
	return Color(0.07, 0.07, 0.1)

func _rarity_name_color(r: int) -> Color:
	match r:
		0: return Color(0.85, 0.55, 0.32)
		1: return Color(0.35, 0.6, 0.8)
		2: return Color(0.56, 0.38, 0.75)
		3: return Color(0.88, 0.69, 0.19)
		4: return Color(0.91, 0.33, 0.33)
	return Color(0.8, 0.8, 0.8)

func _rarity_sub_color(r: int) -> Color:
	match r:
		0: return Color(0.42, 0.25, 0.19)
		1: return Color(0.16, 0.35, 0.48)
		2: return Color(0.29, 0.16, 0.44)
		3: return Color(0.5, 0.38, 0.06)
		4: return Color(0.5, 0.13, 0.13)
	return Color(0.4, 0.4, 0.4)

func _portrait_bg(r: int) -> Color:
	match r:
		0: return Color(0.16, 0.08, 0.09)
		1: return Color(0.05, 0.12, 0.21)
		2: return Color(0.1, 0.06, 0.19)
		3: return Color(0.16, 0.1, 0.03)
		4: return Color(0.16, 0.06, 0.06)
	return Color(0.12, 0.12, 0.16)

func _portrait_letter(r: int) -> Color:
	match r:
		0: return Color(0.72, 0.35, 0.19)
		1: return Color(0.29, 0.54, 0.75)
		2: return Color(0.5, 0.3, 0.69)
		3: return Color(0.85, 0.66, 0.13)
		4: return Color(0.88, 0.25, 0.25)
	return Color(0.7, 0.7, 0.7)
