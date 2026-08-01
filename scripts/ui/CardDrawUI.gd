## Manual card picking UI — boss: phase1 pick 2 mixed → phase2 pick 1 boss → flip.
class_name CardDrawUI
extends Control

var _pool: Array = []
var _selected: Array = []
var _flow_parent: Node = null
var _is_boss: bool = false
var _boss_pool: Array = []
var _card_rects: Array = []
var _phase: String = "pick"
var _boss_phase: String = ""    # "mixed" then "boss" for boss stages
var _selected_indices: Array = []
var _boss_selected_idx: int = -1
var _boss_card_panels: Array[ColorRect] = []
var _mixed_picks: Array = []    # save phase1 picks during boss flow

var _pick_count: int = 2

var _stage: int = 0

func setup(pool: Array, boss_pool: Array, flow: Node, is_boss: bool, pick_count: int = 2, stage: int = 0) -> void:
	pool.shuffle()
	_pool = pool
	_boss_pool = boss_pool
	_flow_parent = flow
	_is_boss = is_boss
	_pick_count = pick_count
	_stage = stage
	_selected.clear()
	_card_rects.clear()
	_boss_card_panels.clear()
	_phase = "pick"
	_selected_indices.clear()
	_boss_selected_idx = -1
	_mixed_picks.clear()
	_boss_phase = ""
	_build_backs()

func _build_backs() -> void:
	for child: Node in get_children(): child.queue_free()
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06); bg.position = Vector2.ZERO; bg.size = Vector2(1280, 720)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var title_text: String
	var hint_text: String
	var sub_text: String = ""
	var mixed_rar_name := _rarity_name_for_stage(_stage)
	var boss_rar_name := _boss_rarity_name_for_stage(_stage)

	if _is_boss:
		if _boss_phase == "":
			title_text = "暗牌 · 选出 2 张 %s 对手" % mixed_rar_name
			hint_text = "点选 2 张 · 然后翻牌"
			sub_text = "BOSS 战 · 稍后追加 1 张 %s" % boss_rar_name
			_build_card_row(bg, _pool, 140, false)
		else:
			title_text = "BOSS 追加 · 选择 1 张 %s" % boss_rar_name
			hint_text = "点选 1 张加入对手阵容"
			_build_card_row(bg, _boss_pool, 380, true)
	else:
		title_text = "暗牌 · 选出 %d 张做为对手" % _pick_count
		hint_text = "点选 %d 张卡牌 · 选满后点确认 · 然后翻牌" % _pick_count
		_build_card_row(bg, _pool, 140, false)

	var title := _lbl(title_text, Vector2(0, 30), Vector2(1280, 40), Color(0.78, 0.69, 0.41), 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; bg.add_child(title)
	var hint := _lbl(hint_text, Vector2(0, 70), Vector2(1280, 24), Color(0.5, 0.5, 0.5), 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; bg.add_child(hint)
	if sub_text != "":
		var st := _lbl(sub_text, Vector2(0, 94), Vector2(1280, 20), Color(0.98, 0.35, 0.35), 11)
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; bg.add_child(st)

	var is_boss_phase2: bool = (_is_boss and _boss_phase != "")
	var required: int = 1 if is_boss_phase2 else _pick_count
	var confirm: Button = Button.new()
	confirm.name = "ConfirmBtn"
	confirm.text = "确认 (0/%d)" % required
	if is_boss_phase2:
		confirm.position = Vector2(540, 480)
	else:
		confirm.position = Vector2(540, 420)
	confirm.size = Vector2(200, 48)
	confirm.disabled = true
	var nb := StyleBoxFlat.new()
	nb.bg_color = Color(0.78, 0.69, 0.41).darkened(0.5)
	nb.border_color = Color(0.78, 0.69, 0.41)
	nb.border_width_left = 2; nb.border_width_right = 2; nb.border_width_top = 2; nb.border_width_bottom = 2
	nb.corner_radius_top_left = 6; nb.corner_radius_top_right = 6; nb.corner_radius_bottom_right = 6; nb.corner_radius_bottom_left = 6
	confirm.add_theme_stylebox_override("normal", nb)
	confirm.add_theme_stylebox_override("disabled", nb)
	confirm.add_theme_font_size_override("font_size", 14)
	confirm.add_theme_color_override("font_color", Color(0.98, 0.78, 0.29))
	var hb := StyleBoxFlat.new()
	hb.bg_color = Color(0.78, 0.69, 0.41).darkened(0.3)
	hb.border_color = Color(1, 0.85, 0.5)
	hb.border_width_left = 2; hb.border_width_right = 2; hb.border_width_top = 2; hb.border_width_bottom = 2
	hb.corner_radius_top_left = 6; hb.corner_radius_top_right = 6; hb.corner_radius_bottom_right = 6; hb.corner_radius_bottom_left = 6
	confirm.add_theme_stylebox_override("hover", hb)
	confirm.add_theme_stylebox_override("pressed", hb)
	confirm.pressed.connect(_on_confirm)
	bg.add_child(confirm)
	_update_confirm()

func _build_card_row(parent: Control, cards: Array, y: int, is_boss_row: bool) -> void:
	var total: int = cards.size()
	var card_w: int = 140; var card_h: int = 220; var gap: int = 12
	var row_w: int = total * card_w + (total - 1) * gap
	var start_x: int = (1280 - row_w) / 2
	for i in range(total):
		var card: Resource = cards[i]
		var x: int = start_x + i * (card_w + gap)
		_create_card_back(parent, card, x, y, card_w, card_h, i, is_boss_row)

func _create_card_back(parent: Control, card: Resource, x: int, y: int, w: int, h: int, idx: int, is_boss: bool = false) -> void:
	var acc: Color = card.get_rarity_color()
	# The back of the card — solid color + decorative pattern, NO info revealed
	var panel := ColorRect.new()
	panel.position = Vector2(x, y); panel.size = Vector2(w, h)
	panel.color = Color(0.08, 0.07, 0.1)
	panel.name = "CardBack_%d" % idx
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(panel)

	# Top accent stripe shows rarity color only
	var stripe := ColorRect.new()
	stripe.position = Vector2(0, 0); stripe.size = Vector2(w, 4); stripe.color = acc
	panel.add_child(stripe)

	# Decorative back pattern — concentric circles + center icon
	var cx: int = w / 2; var cy: int = h / 2 - 10

	var ring1 := ColorRect.new()
	ring1.position = Vector2(cx - 30, cy - 30); ring1.size = Vector2(60, 60)
	ring1.color = Color(0.06, 0.05, 0.08)
	panel.add_child(ring1)

	var ring2 := ColorRect.new()
	ring2.position = Vector2(cx - 24, cy - 24); ring2.size = Vector2(48, 48)
	ring2.color = Color(0.1, 0.09, 0.13)
	panel.add_child(ring2)

	var center := ColorRect.new()
	center.position = Vector2(cx - 12, cy - 12); center.size = Vector2(24, 24)
	center.color = acc.darkened(0.3)
	panel.add_child(center)

	# Bottom label "?"
	var qmark := _lbl("?", Vector2(0, h - 36), Vector2(w, 30), Color(0.35, 0.35, 0.4), 28)
	qmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(qmark)

	var entry := {"rect": panel, "card": card, "idx": idx, "back_stripe": stripe, "back_center": center, "back_qmark": qmark}
	_card_rects.append(entry)

	panel.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if _phase == "pick":
				_toggle_card(idx))

func _create_card_face(parent: Control, card: Resource, x: int, y: int, w: int, h: int, idx: int) -> void:
	var acc: Color = card.get_rarity_color()
	var panel := ColorRect.new()
	panel.position = Vector2(x, y); panel.size = Vector2(w, h)
	panel.color = Color(0.08, 0.07, 0.1)
	panel.name = "BossCard_%d" % idx
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(panel)
	var stripe := ColorRect.new()
	stripe.position = Vector2(0, 0); stripe.size = Vector2(w, 4); stripe.color = acc
	panel.add_child(stripe)
	var nm := _lbl(card.card_name, Vector2(0, 16), Vector2(w, 24), acc, 13)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(nm)
	var sk := _lbl("「%s」" % card.skill_name, Vector2(0, 50), Vector2(w, 24), Color(0.85, 0.85, 0.85), 11)
	sk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(sk)
	var sd := _lbl(card.skill_desc, Vector2(8, 80), Vector2(w - 16, h - 100), Color(0.7, 0.7, 0.75), 10)
	sd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(sd)
	panel.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if _phase == "pick":
				_toggle_boss(idx))
	_boss_card_panels.append(panel)

func _toggle_card(idx: int) -> void:
	var card: Resource
	if _is_boss and _boss_phase == "boss":
		card = _boss_pool[idx]
	else:
		card = _pool[idx]
	var already_idx: int = _selected_indices.find(idx)

	if already_idx >= 0:
		_selected.remove_at(already_idx)
		_selected_indices.remove_at(already_idx)
		_card_rects[idx].rect.color = Color(0.08, 0.07, 0.1)
	else:
		var max_picks: int = 1 if (_is_boss and _boss_phase == "boss") else _pick_count
		if _selected.size() >= max_picks: return
		_selected.append(card)
		_selected_indices.append(idx)
		_card_rects[idx].rect.color = _card_rects[idx].back_center.color.lightened(0.4)
	_update_confirm()

func _update_confirm() -> void:
	var b: Button = find_child("ConfirmBtn", true, false) as Button
	if b:
		var required: int = 1 if (_is_boss and _boss_phase == "boss") else _pick_count
		b.text = "确认 (%d/%d)" % [_selected.size(), required]
		b.disabled = (_selected.size() != required)

func _toggle_boss(idx: int) -> void:
	if _boss_selected_idx == idx:
		_boss_selected_idx = -1
	else:
		_boss_selected_idx = idx
	for j in range(_boss_card_panels.size()):
		var p: ColorRect = _boss_card_panels[j] as ColorRect
		if not p: continue
		if j == _boss_selected_idx:
			p.color = _boss_pool[j].get_rarity_color().darkened(0.4)
		else:
			p.color = Color(0.08, 0.07, 0.1)
	_update_confirm()

func _on_confirm() -> void:
	if _is_boss and _boss_phase == "":
		# Phase 1 done: save mixed picks, switch to boss phase
		if _selected.size() != _pick_count: return
		_mixed_picks = _selected.duplicate()
		_boss_phase = "boss"
		_selected.clear()
		_selected_indices.clear()
		_card_rects.clear()
		_build_backs()
		return

	# Final confirm (non-boss, or boss phase 2 done)
	var required: int = 1 if (_is_boss and _boss_phase == "boss") else _pick_count
	if _selected.size() != required: return
	_phase = "revealing"
	var b: Button = find_child("ConfirmBtn", true, false) as Button
	if b: b.disabled = true

	for i in range(_card_rects.size()):
		var entry: Dictionary = _card_rects[i]
		var rect: ColorRect = entry.rect
		var is_picked: bool = i in _selected_indices
		if not is_picked:
			rect.modulate = Color(0.3, 0.3, 0.3, 0.5)
			continue
		_animate_flip(rect)

func _animate_flip(rect: ColorRect) -> void:
	# Simple flip: collapse horizontally → swap content → expand back
	var t := create_tween()
	t.tween_property(rect, "scale:x", 0.05, 0.15)
	t.tween_callback(func(): _flip_content(rect))
	t.tween_interval(0.05)
	t.tween_property(rect, "scale:x", 1.0, 0.15)
	t.tween_callback(func(): _check_all_flipped())

func _flip_content(rect: ColorRect) -> void:
	# Find the entry matching this rect
	var entry: Dictionary = {}
	for e in _card_rects:
		if e.rect == rect: entry = e; break
	if entry.is_empty(): return
	var card: Resource = entry.card
	var acc: Color = card.get_rarity_color()
	# Clear existing children
	for child in rect.get_children(): child.queue_free()
	# Replace content with front face
	rect.color = acc.darkened(0.7)

	var stripe := ColorRect.new()
	stripe.position = Vector2(0, 0); stripe.size = Vector2(rect.size.x, 4)
	stripe.color = acc
	rect.add_child(stripe)

	var rarity_lbl := _lbl(card.get_rarity_name(), Vector2(6, 6), Vector2(50, 16), acc, 9)
	rect.add_child(rarity_lbl)

	var name_lbl := _lbl(card.card_name, Vector2(6, 50), Vector2(rect.size.x - 12, 28), Color(0.88, 0.85, 0.8), 12)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; rect.add_child(name_lbl)

	var sk_bg := ColorRect.new()
	sk_bg.position = Vector2(4, 165); sk_bg.size = Vector2(rect.size.x - 8, 50)
	sk_bg.color = Color(0.08, 0.06, 0.04); rect.add_child(sk_bg)

	var sk_lbl := _lbl(card.skill_name, Vector2(6, 168), Vector2(rect.size.x - 12, 22), acc, 11)
	sk_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; rect.add_child(sk_lbl)

	var skd_lbl := _lbl(card.skill_desc, Vector2(6, 188), Vector2(rect.size.x - 12, 24), Color(0.4, 0.4, 0.4), 8)
	skd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skd_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rect.add_child(skd_lbl)

func _check_all_flipped() -> void:
	if _phase != "revealing": return
	# Show "start battle" button after all flips
	var bg := get_child(0) as Control
	if not bg: return
	var existing = bg.find_child("StartBtn", true, false)
	if existing: existing.queue_free()

	var sb := Button.new()
	sb.name = "StartBtn"
	sb.text = "进入战斗"
	sb.position = Vector2(540, 480)
	sb.size = Vector2(200, 48)
	var sb_nb := StyleBoxFlat.new()
	sb_nb.bg_color = Color(0.78, 0.69, 0.41).darkened(0.3)
	sb_nb.border_color = Color(0.98, 0.85, 0.4)
	sb_nb.border_width_left = 2; sb_nb.border_width_right = 2; sb_nb.border_width_top = 2; sb_nb.border_width_bottom = 2
	sb_nb.corner_radius_top_left = 6; sb_nb.corner_radius_top_right = 6; sb_nb.corner_radius_bottom_right = 6; sb_nb.corner_radius_bottom_left = 6
	sb.add_theme_stylebox_override("normal", sb_nb)
	sb.add_theme_font_size_override("font_size", 16)
	sb.pressed.connect(_on_start)
	bg.add_child(sb)
	_phase = "revealed"

func _on_start() -> void:
	var final: Array
	if _is_boss and _mixed_picks.size() > 0:
		final = _mixed_picks + _selected
	else:
		final = _selected.duplicate()
	_start_selected_battle(final)

func _start_selected_battle(final: Array) -> void:
	queue_free()
	if _flow_parent and _flow_parent.has_method("_on_cards_confirmed"):
		_flow_parent._on_cards_confirmed(final)

func _lbl(t: String, p: Vector2, s: Vector2, c: Color, fs: int) -> Label:
	var l := Label.new(); l.text = t; l.position = p; l.size = s
	l.add_theme_font_size_override("font_size", fs); l.add_theme_color_override("font_color", c); return l

func _rarity_name_for_stage(stage: int) -> String:
	match stage:
		0: return "普通"
		1: return "稀有"
		2: return "史诗"
		3: return "传说"
	return "普通"

func _boss_rarity_name_for_stage(stage: int) -> String:
	match stage:
		0: return "史诗卡"
		1: return "传说卡"
		2: return "传说卡"
		3: return "创世卡"
	return "稀有卡"
