## In-game HUD for 1v1 dice game. All UI is built procedurally in _ready() to avoid .tscn compatibility issues.
extends Control

# Preload companion scripts
const GameButton := preload("res://scripts/ui/components/GameButton.gd")
const GamePanel := preload("res://scripts/ui/components/GamePanel.gd")

var flow_parent: Node
var _drawn_cards: Array = []   # Cards drawn for current battle (for upcoming card UI)
var game_ctrl: Node

# UI references (all created in _ready)
var opponent_label: Label
var opponent_face: Label
var opponent_label2: Label
var opponent_face2: Label
var opponent_label3: Label
var opponent_face3: Label
var _sk_label1: Label
var _sk_label2: Label
var _sk_label3: Label
var _bid_face1: String = ""
var _bid_face2: String = ""
var _opp_bg1: ColorRect
var _opp_bg2: ColorRect
var _opp_bg3: ColorRect
var _sk_bg1: ColorRect
var _sk_bg2: ColorRect
var _sk_bg3: ColorRect
var _card_count: int = 2  # 1v2 default, set to 3 for boss
var status_label: Label
var bid_display: Label
var dice_container: HBoxContainer
var bid_adjust: Control

var _btn_challenge: ColorRect
var _btn_challenge_lbl: Label
var _btn_bid: ColorRect
var _btn_bid_lbl: Label
var points_label: Label
var _btn_count_minus: ColorRect
var _btn_count_minus_lbl: Label
var _btn_count_plus: ColorRect
var _btn_count_plus_lbl: Label
var _btn_value_minus: ColorRect
var _btn_value_minus_lbl: Label
var _btn_value_plus: ColorRect
var _btn_value_plus_lbl: Label
var _btn_count_num_lbl: Label
var _btn_value_num_lbl: Label

# Track item backgrounds for clean refresh
var _item_bgs: Array[ColorRect] = []
var _consumable_labels: Array[Label] = []
var _consumable_name_labels: Array[Label] = []
var _consumable_use_btns: Array[ColorRect] = []
var _notify_label: RichTextLabel
var _tutorial_bar: ColorRect
var _tutorial_label: Label
var _tutorial_tween: Tween
var _tutorial_history: Array[String] = []
var _tutorial_review_panel: ColorRect
var _tutorial_review_text: RichTextLabel
var _tutorial_focus_nodes: Array[CanvasItem] = []
var _hint_history: Array[String] = []
var _history_index: int = 0
var _last_reveal_text: String = ""  # 骰子揭示文本 (显示在继续按钮上方)
var _last_reveal_round: int = -1

func _log_event(msg: String) -> void:
	_hint_history.append(msg)

# Pause menu
var _pause_overlay: Control
var _pause_visible: bool = false

# Dice labels
var _die_labels: Array = []
var _die_boxes: Array[ColorRect] = []
var _die_target_positions: Array[Vector2] = []
var _anim_playing: bool = false
var _selecting_mode: bool = false
var _selection_mode_type: String = ""  # "reroll" or "flip"
var _selected_dice: Array[bool] = []
var _active_item_id: String = ""
var _select_confirm_btn: ColorRect
var _select_cancel_btn: ColorRect
var _item_charges: Dictionary = {}  # per-item remaining uses
var _item_locked: bool = false  # re-entrancy guard for item usage

# Peek mode (透屏: two-phase — select opponent then position)
var _peek_phase: String = ""  # "opponent" | "position" | ""
var _peek_opponent: String = ""  # "ai1", "ai2", or "ai3"
var _peek_btn1: ColorRect
var _peek_btn2: ColorRect
var _peek_btn3: ColorRect

var _bid_count: int = 1
var _bid_value: int = 2

func _ready() -> void:
	game_ctrl = $DiceGame
	_build_all_ui()
	_connect_all()
	_refresh_points()
	_refresh_virus()
	# Force show buttons immediately (overrides whatever _build_all_ui set)
	_show_actions(true)

func _build_all_ui() -> void:
	# === LEFT ICON DOCK (44px) ===
	var DW: int = 44
	var dock: ColorRect = ColorRect.new()
	dock.position = Vector2(0, 0)
	dock.size = Vector2(DW, 720)
	dock.color = Color(0.055, 0.055, 0.086, 1)
	add_child(dock)
	_consumable_labels.clear()
	_consumable_name_labels.clear()
	_consumable_use_btns.clear()
	_item_bgs.clear()
	var icon_size: int = 30
	var lbl_h: int = 12
	var icon_gap: int = 6
	var per_row: int = icon_size + lbl_h + icon_gap
	var icon_x: int = (DW - icon_size) / 2
	var icon_start_y: int = 4
	for i in range(GameState.MAX_CONSUMABLE):
		var sy: int = icon_start_y + i * per_row
		var ibg: ColorRect = ColorRect.new()
		ibg.position = Vector2(icon_x, sy)
		ibg.size = Vector2(icon_size, icon_size)
		ibg.color = Color(0.086, 0.086, 0.133, 1)
		ibg.name = "ItemSlot" + str(i)
		dock.add_child(ibg)
		_item_bgs.append(ibg)
		var ilbl: Label = Label.new()
		ilbl.position = Vector2(0, 0)
		ilbl.size = Vector2(icon_size, icon_size)
		ilbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ilbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ilbl.add_theme_font_size_override("font_size", 14)
		ilbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
		ilbl.text = "-"
		ibg.add_child(ilbl)
		_consumable_labels.append(ilbl)
		# Short name label below icon
		var nlbl: Label = Label.new()
		nlbl.position = Vector2(icon_x, sy + icon_size + 2)
		nlbl.size = Vector2(icon_size, lbl_h)
		nlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nlbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nlbl.add_theme_font_size_override("font_size", 8)
		nlbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
		nlbl.text = ""
		nlbl.name = "ItemName" + str(i)
		dock.add_child(nlbl)
		_consumable_name_labels.append(nlbl)
		ibg.mouse_filter = Control.MOUSE_FILTER_STOP
		var slot_idx: int = i
		ibg.mouse_entered.connect(func():
			if _notify_label and slot_idx < GameState.consumable_items.size():
				var cur: ItemData = GameState.get_item_info(GameState.consumable_items[slot_idx])
				if cur:
					_notify_label.text = "[%s] %s · %s" % [cur.get_rarity_name(), cur.item_name, cur.description]
		)
		ibg.mouse_exited.connect(func():
			if _notify_label and _notify_label.text.begins_with("["): _notify_label.text = ""
		)
		var slot_id: int = i
		ibg.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				if slot_id < GameState.consumable_items.size():
					_use_consumable_item(GameState.consumable_items[slot_id])
		)
	var dcnt: Label = Label.new()
	dcnt.position = Vector2(icon_x, icon_start_y + 6 * per_row + 16)
	dcnt.size = Vector2(icon_size, icon_size)
	dcnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dcnt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dcnt.add_theme_font_size_override("font_size", 10)
	dcnt.add_theme_color_override("font_color", Color(0.357, 0.627, 0.961))
	dcnt.text = "0"
	dcnt.name = "DockCount"
	dock.add_child(dcnt)

	# === MAIN CONTENT ===
	var MX: int = DW + 4
	var MW: int = 1280 - MX - 4

	var stage_label: Label = _make_label("", Vector2(MX, 2), Vector2(200, 18), Color(0.29, 0.29, 0.33), 9)
	add_child(stage_label)
	stage_label.name = "StageLabel"
	points_label = _make_label("", Vector2(MX + MW - 190, 2), Vector2(120, 18), Color(0.29, 0.29, 0.33), 9)
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(points_label)

	# Dedicated tutorial strip. It occupies the unused space above opponent cards
	# and never replaces the normal skill/item notification strip.
	_tutorial_bar = ColorRect.new()
	_tutorial_bar.name = "TutorialBar"
	_tutorial_bar.position = Vector2(MX + 150, 24)
	_tutorial_bar.size = Vector2(MW - 300, 30)
	_tutorial_bar.color = Color(0.035, 0.12, 0.105, 0.96)
	_tutorial_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_bar.visible = false
	add_child(_tutorial_bar)
	_add_border(_tutorial_bar, int(_tutorial_bar.size.x), int(_tutorial_bar.size.y), Color(0.36, 0.79, 0.65), 2)
	_tutorial_label = Label.new()
	_tutorial_label.position = Vector2(12, 2)
	_tutorial_label.size = Vector2(_tutorial_bar.size.x - 24, 26)
	_tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tutorial_label.add_theme_font_size_override("font_size", 13)
	_tutorial_label.add_theme_color_override("font_color", Color(0.78, 1.0, 0.9))
	_tutorial_bar.add_child(_tutorial_label)
	var tutorial_review_btn := Button.new()
	tutorial_review_btn.name = "TutorialReviewButton"
	tutorial_review_btn.text = "教程回顾"
	tutorial_review_btn.position = Vector2(MX, 24)
	tutorial_review_btn.size = Vector2(130, 30)
	tutorial_review_btn.visible = GameState.tutorial_enabled
	tutorial_review_btn.pressed.connect(_toggle_tutorial_review)
	add_child(tutorial_review_btn)
	_build_tutorial_review_panel()
	# Virus health squares (2 squares, inline next to exit btn)
	for i in range(2):
		var vq: ColorRect = ColorRect.new()
		vq.position = Vector2(MX + MW - 44 + i * 10, 6)
		vq.size = Vector2(8, 8)
		vq.color = Color(0.06, 0.06, 0.06)
		vq.name = "VirusSquare" + str(i)
		add_child(vq)
		_add_border(vq, 8, 8, Color(0.18, 0.18, 0.18), 1)
	var eb: ColorRect = ColorRect.new()
	eb.position = Vector2(MX + MW - 20, 2)
	eb.size = Vector2(16, 16)
	eb.color = Color(0.22, 0.07, 0.07, 1)
	add_child(eb)
	var el: Label = _make_label("X", Vector2(0, 0), Vector2(16, 16), Color(1, 0.6, 0.6), 10)
	el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	el.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	eb.add_child(el)
	eb.mouse_filter = Control.MOUSE_FILTER_STOP
	eb.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_show_pause_menu())

	# === OPPONENT AREA === (2 cards for 1v2, 3 cards for boss)
	var opp_y: int = 60
	var opp_h: int = 240  # bigger cards per mockup
	var gap: int = 24  # more space between cards
	var layout_count: int = 3 if _card_count >= 3 else 2
	var card_w: int = 195

	for ai_idx in range(3):
		var is_visible := ai_idx < _card_count
		var ox: int = 0
		if _card_count == 2 and ai_idx < 2:
			ox = [312, 789][ai_idx]
		elif _card_count >= 3 and ai_idx < 3:
			ox = [174, 543, 912][ai_idx]
		else:
			ox = MX + ai_idx * (card_w + gap)

		var obg := ColorRect.new()
		obg.position = Vector2(ox, opp_y)
		obg.size = Vector2(card_w, opp_h)
		obg.color = Color(0.06, 0.06, 0.08)
		obg.visible = is_visible
		obg.mouse_filter = Control.MOUSE_FILTER_STOP
		var obg_ai_idx: int = ai_idx
		obg.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_show_opponent_skill(obg_ai_idx))
		add_child(obg)
		_add_border(obg, card_w, opp_h, Color(0.2, 0.2, 0.22), 2)

		# Card name (large, centered)
		var nl := Label.new()
		nl.text = "???"; nl.position = Vector2(ox + 8, opp_y + 20)
		nl.size = Vector2(card_w - 16, 30); nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.add_theme_font_size_override("font_size", 15)
		nl.add_theme_color_override("font_color", Color(0.88, 0.85, 0.8))
		add_child(nl)

		# Skill name badge
		var sk_bg := ColorRect.new()
		sk_bg.position = Vector2(ox + (card_w - 160) / 2, opp_y + 60)
		sk_bg.size = Vector2(160, 28); sk_bg.color = Color(0.08, 0.06, 0.04)
		add_child(sk_bg)
		var skl := Label.new()
		skl.text = ""; skl.position = Vector2(ox + 8, opp_y + 62)
		skl.size = Vector2(card_w - 16, 24); skl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skl.add_theme_font_size_override("font_size", 11)
		skl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.4))
		add_child(skl)

		# Status / bid text
		var bl := Label.new()
		bl.text = ""; bl.position = Vector2(ox + 8, opp_y + opp_h - 36)
		bl.size = Vector2(card_w - 16, 28); bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bl.add_theme_font_size_override("font_size", 13)
		bl.add_theme_color_override("font_color", Color(0.98, 0.78, 0.29))
		add_child(bl)

		if ai_idx == 0: _opp_bg1 = obg; opponent_label = nl; opponent_face = bl; _sk_bg1 = sk_bg
		elif ai_idx == 1: _opp_bg2 = obg; opponent_label2 = nl; opponent_face2 = bl; _sk_bg2 = sk_bg
		else: _opp_bg3 = obg; opponent_label3 = nl; opponent_face3 = bl; _sk_bg3 = sk_bg

		# Store skill label for later update
		if ai_idx == 0: _sk_label1 = skl
		elif ai_idx == 1: _sk_label2 = skl
		else: _sk_label3 = skl

# === HINT BAR (40h, blue-bordered notification strip) ===
	var hint_y: int = opp_y + opp_h + 16
	var hint_h: int = 40
	var hint_bg: ColorRect = ColorRect.new()
	hint_bg.position = Vector2(MX, hint_y)
	hint_bg.size = Vector2(MW, hint_h)
	hint_bg.color = Color(0.04, 0.06, 0.1)
	add_child(hint_bg)
	_add_border(hint_bg, MW, hint_h, Color(0.36, 0.5, 0.84), 2)
	var hint_dot := ColorRect.new()
	hint_dot.position = Vector2(MX + 12, hint_y + (hint_h - 8) / 2)
	hint_dot.size = Vector2(8, 8)
	hint_dot.color = Color(0.36, 0.5, 0.84)
	hint_bg.add_child(hint_dot)
	_notify_label = RichTextLabel.new()
	_notify_label.position = Vector2(MX + 30, hint_y + 2)
	_notify_label.size = Vector2(MW - 40, 20)
	_notify_label.bbcode_enabled = true
	_notify_label.text = ""
	_notify_label.fit_content = true
	_notify_label.scroll_active = false
	_notify_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_notify_label.add_theme_font_size_override("normal_font_size", 11)
	_notify_label.add_theme_color_override("default_color", Color(0.75, 0.85, 0.95))
	_notify_label.gui_input.connect(_on_hint_clicked)
	hint_bg.add_child(_notify_label)

# === BID SECTION: title + count/value controls (centered, larger) ===
	var bid_y: int = hint_y + hint_h + 18
	var bid_h: int = 64
	# Title "当前叫牌 · <player>"
	var bid_title: Label = _make_label("", Vector2(MX, bid_y - 18), Vector2(MW, 16), Color(0.6, 0.6, 0.65), 10)
	bid_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(bid_title)
	bid_display = bid_title

	# Controls area
	var cnt_box_w: int = 60
	var cnt_box_h: int = 44
	var cnt_x: int = MX + (MW - (cnt_box_w * 4 + 36)) / 2
	var cnt_y: int = bid_y + 14
	# Number
	_btn_count_minus = _make_btn_at(self, Vector2(cnt_x, cnt_y), Vector2(cnt_box_w, cnt_box_h), "-", Color(0.96, 0.78, 0.32), true, func(): _adjust_count(-1))
	_btn_count_minus_lbl = _btn_count_minus.get_child(0) as Label
	_btn_count_num_lbl = _make_label("3", Vector2(cnt_x + cnt_box_w + 6, cnt_y), Vector2(54, cnt_box_h), Color(0.95, 0.95, 0.95), 24)
	_btn_count_num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_btn_count_num_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_btn_count_num_lbl)
	_btn_count_plus = _make_btn_at(self, Vector2(cnt_x + cnt_box_w + 66, cnt_y), Vector2(cnt_box_w, cnt_box_h), "+", Color(0.96, 0.78, 0.32), true, func(): _adjust_count(1))
	_btn_count_plus_lbl = _btn_count_plus.get_child(0) as Label
	# 个 separator
	var sep_lbl := _make_label("个", Vector2(cnt_x + cnt_box_w * 2 + 80, cnt_y), Vector2(28, cnt_box_h), Color(0.6, 0.6, 0.6), 14)
	sep_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sep_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(sep_lbl)
	# Value
	var val_x: int = cnt_x + cnt_box_w * 2 + 110
	_btn_value_minus = _make_btn_at(self, Vector2(val_x, cnt_y), Vector2(cnt_box_w, cnt_box_h), "-", Color(0.96, 0.78, 0.32), true, func(): _adjust_value(-1))
	_btn_value_minus_lbl = _btn_value_minus.get_child(0) as Label
	_btn_value_num_lbl = _make_label("2", Vector2(val_x + cnt_box_w + 6, cnt_y), Vector2(54, cnt_box_h), Color(0.95, 0.95, 0.95), 24)
	_btn_value_num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_btn_value_num_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_btn_value_num_lbl)
	_btn_value_plus = _make_btn_at(self, Vector2(val_x + cnt_box_w + 66, cnt_y), Vector2(cnt_box_w, cnt_box_h), "+", Color(0.96, 0.78, 0.32), true, func(): _adjust_value(1))
	_btn_value_plus_lbl = _btn_value_plus.get_child(0) as Label

# === ACTION ROW: confirm + challenge (large buttons) ===
	var action_y: int = bid_y + bid_h + 14
	var action_h: int = 56
	var btn_w: int = (MW - 24) / 2
	_btn_bid = _make_btn_at(self, Vector2(MX, action_y), Vector2(btn_w, action_h), "确认叫牌", Color(0.92, 0.92, 0.92), true, func(): _on_bid_pressed())
	_btn_bid_lbl = _btn_bid.get_child(0) as Label
	_btn_challenge = _make_btn_at(self, Vector2(MX + btn_w + 24, action_y), Vector2(btn_w, action_h), "质疑", Color(0.94, 0.4, 0.4), true, func(): _on_challenge_pressed())
	_btn_challenge_lbl = _btn_challenge.get_child(0) as Label

	# === DICE ROW (76h, centered) ===
	var dice_y: int = action_y + action_h + 10
	var dice_h: int = 76
	var dice_bg: ColorRect = ColorRect.new()
	dice_bg.position = Vector2(MX, dice_y)
	dice_bg.size = Vector2(MW, dice_h)
	dice_bg.color = Color(0.055, 0.055, 0.086, 1)
	add_child(dice_bg)
	_add_border(dice_bg, MW, dice_h, Color(0.16, 0.16, 0.16), 1)
	var dt: Label = _make_label("你的骰子", Vector2(MX + 8, dice_y + 2), Vector2(MW - 16, 12), Color(0.33, 0.33, 0.33), 7)
	dt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(dt)

	_die_labels.clear()
	_die_boxes.clear()
	_die_target_positions.clear()
	var die_size: int = 48
	var die_gap: int = 12
	var total_dice_w: int = 5 * die_size + 4 * die_gap
	var die_start_x: int = MX + (MW - total_dice_w) / 2
	var die_cy: int = dice_y + (dice_h - die_size) / 2 + 2
	for i in range(8):
		var dx: int = die_start_x + i * (die_size + die_gap)
		var die_box: ColorRect = ColorRect.new()
		die_box.position = Vector2(dx, die_cy)
		die_box.size = Vector2(die_size, die_size)
		_die_target_positions.append(die_box.position)
		die_box.color = Color(1, 1, 1, 1)
		die_box.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(die_box)
		var didx: int = i
		die_box.gui_input.connect(func(event: InputEvent): _on_die_click(didx, event))
		var dl: Label = Label.new()
		dl.position = Vector2(0, 0)
		dl.size = Vector2(die_size, die_size)
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dl.add_theme_font_size_override("font_size", 28)
		dl.add_theme_color_override("font_color", Color(0.17, 0.17, 0.17))
		dl.text = "?"
		die_box.add_child(dl)
		_die_labels.append(dl)
		_die_boxes.append(die_box)
		if i >= 5: die_box.visible = false

	# === INFO STRIP (12h) ===
	var info_y: int = dice_y + dice_h + 6
	var info_h: int = 14
	var info_bg: ColorRect = ColorRect.new()
	info_bg.position = Vector2(MX, info_y)
	info_bg.size = Vector2(MW, info_h)
	info_bg.color = Color(0.055, 0.055, 0.086, 1)
	add_child(info_bg)
	var info_lbl: Label = _make_label("左键点击骰子标记 · 右键取消 · 点数相同的骰子会被合并计算", Vector2(MX, info_y), Vector2(MW, info_h), Color(0.25, 0.25, 0.28), 7)
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(info_lbl)

	if _opp_bg3:
		_opp_bg3.visible = false

	_refresh_item_display()
	# Build pause menu LAST so its overlay renders on top of all other UI
	_build_pause_menu()

## Unified die click handler (replaces inline lambda for new layout)
func _on_die_click(die_idx: int, event: InputEvent) -> void:
	if not _selecting_mode or not game_ctrl: return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT): return
	if _selection_mode_type == "see_dark" and _peek_phase == "position":
		_on_peek_position(die_idx)
	elif _selection_mode_type == "borrow_die" and _peek_phase == "position":
		_on_borrow_die(die_idx)
	elif _selection_mode_type == "flip_die":
		game_ctrl.flip_die_at(die_idx)
		GameState.use_consumable(_active_item_id)
		game_ctrl.mirror_item("flip_die", {"index": die_idx})
		_exit_selection_mode()
		_refresh_item_display()
		_log_event("翻骰: 翻转骰子")
	elif _selection_mode_type == "clone_die":
		var paired: Array[int] = game_ctrl.get_player_paired_dice()
		if die_idx in paired:
			game_ctrl.clone_player_die(die_idx)
			GameState.use_consumable(_active_item_id)
			game_ctrl.mirror_item("clone_die", {"index": die_idx})
			_exit_selection_mode()
			_refresh_item_display()
			_log_event("克隆: 复制对子")
	elif _selection_mode_type == "freeze_die":
		if game_ctrl:
			game_ctrl.lock_player_die(die_idx)
		GameState.use_consumable(_active_item_id)
		game_ctrl.mirror_item("freeze_die", {"index": die_idx})
		_exit_selection_mode()
		_refresh_item_display()
		_log_event("定格: 锁定骰子直至下轮")
	elif _selection_mode_type == "fate_die":
		game_ctrl.activate_fate_die(die_idx)
		GameState.use_consumable(_active_item_id)
		game_ctrl.mirror_item("fate_die", {"index": die_idx})
		_exit_selection_mode()
		_refresh_item_display()
		_log_event("命运骰: 该位置连续3轮固定")
	elif _selection_mode_type == "reroll_stone" or _selection_mode_type == "split_die" or _selection_mode_type == "rig_dice":
		if die_idx < _selected_dice.size():
			if _selection_mode_type == "split_die":
				var values: Array = game_ctrl.player_cup.get_values()
				if die_idx >= values.size() or values[die_idx] < 4: return
				_selected_dice[die_idx] = true
				_on_select_confirm()
				return
			if _selection_mode_type == "rig_dice" and not _selected_dice[die_idx]:
				var selected_count: int = _selected_dice.count(true)
				if selected_count >= 2: return
			_selected_dice[die_idx] = not _selected_dice[die_idx]
			_update_die_highlight(die_idx)


func _make_label(text: String, pos: Vector2, sz: Vector2, col: Color, fsize: int) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	return l

## Helper: section header (title + count on right)
func _add_section_header(parent: Control, y: int, title: String, count: String, color: Color) -> void:
	var tl: Label = _make_label(title, Vector2(10, y), Vector2(120, 16), color, 9)
	parent.add_child(tl)
	var cl: Label = _make_label(count, Vector2(180, y), Vector2(50, 16), Color(0.35, 0.35, 0.35), 8)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	parent.add_child(cl)

## Helper: thin horizontal separator
func _add_separator(parent: Control, y: int) -> void:
	var sep: ColorRect = ColorRect.new()
	sep.position = Vector2(8, y)
	sep.size = Vector2(169, 1)
	sep.color = Color(0.18, 0.18, 0.18, 1)
	parent.add_child(sep)

## Helper: create count/value adjuster row
func _make_count_adjuster(adj_y: int, label_text: String, is_count: bool) -> void:
	var cx: int = 220 if is_count else 600
	var bg: ColorRect = ColorRect.new()
	bg.position = Vector2(cx, adj_y + 2)
	bg.size = Vector2(180, 32)
	bg.color = Color(0.1, 0.1, 0.11, 1)
	add_child(bg)
	_add_border(bg, 180, 32, Color(0.2, 0.2, 0.2), 1)

	var lbl: Label = _make_label(label_text, Vector2(cx + 6, adj_y + 6), Vector2(40, 20), Color(0.45, 0.45, 0.45), 10)
	add_child(lbl)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Minus button
	var minus: ColorRect = _make_small_btn(self, Vector2(cx + 48, adj_y + 6), "−", true, func(): (_adjust_count(-1) if is_count else _adjust_value(-1)))
	minus.get_child(0).add_theme_font_size_override("font_size", 14)
	# Number label
	var num_lbl: Label
	if is_count:
		num_lbl = _make_label("3", Vector2(cx + 88, adj_y + 6), Vector2(40, 20), Color(0.98, 0.78, 0.29), 16)
		_btn_count_num_lbl = num_lbl
	else:
		num_lbl = _make_label("5", Vector2(cx + 88, adj_y + 6), Vector2(40, 20), Color(0.98, 0.78, 0.29), 16)
		_btn_value_num_lbl = num_lbl
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(num_lbl)
	# Plus button
	var plus: ColorRect = _make_small_btn(self, Vector2(cx + 132, adj_y + 6), "+", true, func(): _adjust_count(1) if is_count else _adjust_value(1))

	# Store button refs for refresh
	if is_count:
		_btn_count_minus = minus
		_btn_count_plus = plus
		_btn_count_num_lbl = num_lbl
	else:
		_btn_value_minus = minus
		_btn_value_plus = plus
		_btn_value_num_lbl = num_lbl

func _add_rounded_border(parent: Control, w: int, h: int, col: Color, thickness: int, radius: int) -> void:
	# Simulate rounded border with 4 thin rectangles + corner pixels
	# Top and bottom edges
	var top: ColorRect = ColorRect.new()
	top.position = Vector2(0, 0)
	top.size = Vector2(w, thickness)
	top.color = col
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(top)

	var bot: ColorRect = ColorRect.new()
	bot.position = Vector2(0, h - thickness)
	bot.size = Vector2(w, thickness)
	bot.color = col
	bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bot)

	# Left and right edges
	var lef: ColorRect = ColorRect.new()
	lef.position = Vector2(0, 0)
	lef.size = Vector2(thickness, h)
	lef.color = col
	lef.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lef)

	var rig: ColorRect = ColorRect.new()
	rig.position = Vector2(w - thickness, 0)
	rig.size = Vector2(thickness, h)
	rig.color = col
	rig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rig)

	# Corner pixels (simulate rounding)
	for cx: int in [0, w - thickness]:
		for cy: int in [0, h - thickness]:
			if (cx == 0 and cy == 0) or (cx == w - thickness and cy == 0) or (cx == 0 and cy == h - thickness) or (cx == w - thickness and cy == h - thickness):
				var corner: ColorRect = ColorRect.new()
				corner.position = Vector2(cx, cy)
				corner.size = Vector2(thickness, thickness)
				corner.color = col
				corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
				parent.add_child(corner)

func _make_btn(parent: Control, col_index: int, label: String, text_col: Color, enabled: bool) -> ColorRect:
	return _make_btn_at(parent, Vector2(60 + col_index * 200, 0), Vector2(180, 50), label, text_col, enabled, _noop)

func _make_btn_at(parent: Control, pos: Vector2, sz: Vector2, label: String, text_col: Color, enabled: bool, callback: Callable) -> ColorRect:
	if parent == null:
		push_error("_make_btn_at: parent is null")
		return null
	var bg: ColorRect = ColorRect.new()
	bg.position = pos
	bg.size = sz
	# Brighter background for visibility against dark scene
	bg.color = Color(0.5, 0.5, 0.55, 1) if enabled else Color(0.2, 0.2, 0.24, 0.7)
	parent.add_child(bg)

	# Add Label FIRST so it's always child[0] (borders are added after as children 1-4)
	var lbl: Label = Label.new()
	lbl.text = label
	lbl.position = Vector2(0, 0)
	lbl.size = sz
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", text_col if enabled else Color(0.4, 0.4, 0.4, 0.6))
	bg.add_child(lbl)

	# Use brighter border for visibility
	_add_border(bg, int(sz.x), int(sz.y), Color(0.98, 0.78, 0.29, 1) if enabled else Color(0.4, 0.4, 0.4, 0.6))

	if enabled:
		bg.mouse_filter = Control.MOUSE_FILTER_STOP
		var base_bg: Color = bg.color
		var hover_bg: Color = Color(0.32, 0.32, 0.36, 1)
		var base_lbl: Color = text_col
		var hover_lbl: Color = text_col.lightened(0.3)
		bg.mouse_entered.connect(func(): bg.color = hover_bg; lbl.add_theme_color_override("font_color", hover_lbl))
		bg.mouse_exited.connect(func(): bg.color = base_bg; lbl.add_theme_color_override("font_color", base_lbl))
		bg.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				callback.call()
		)
	return bg

func _make_small_btn(parent: Control, pos: Vector2, label: String, enabled: bool, callback: Callable) -> ColorRect:
	return _make_btn_at(parent, pos, Vector2(36, 36), label, Color(0.98, 0.78, 0.29), enabled, callback)

## Compact inline bid control: [label] [-] [N] [+]
func _build_bid_control(x: int, y: int, title: String, name_suffix: String, on_minus: Callable, on_plus: Callable) -> void:
	var bg: ColorRect = ColorRect.new()
	bg.position = Vector2(x, y)
	bg.size = Vector2(58, 30)
	bg.color = Color(0.071, 0.071, 0.11, 1)
	add_child(bg)
	_add_border(bg, 58, 30, Color(0.125, 0.125, 0.188), 1)

	var tl: Label = _make_label(title, Vector2(x, y + 1), Vector2(58, 8), Color(0.33, 0.33, 0.33), 6)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(tl)

	var minus_btn := _make_btn_at(self, Vector2(x + 2, y + 10), Vector2(16, 14), "-", Color(0.98, 0.78, 0.29), true, on_minus)
	var plus_btn := _make_btn_at(self, Vector2(x + 40, y + 10), Vector2(16, 14), "+", Color(0.98, 0.78, 0.29), true, on_plus)
	var num_lbl: Label = _make_label("0", Vector2(x + 20, y + 12), Vector2(18, 14), Color(0.98, 0.78, 0.29), 11)
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(num_lbl)

	if name_suffix == "_count":
		_btn_count_minus = minus_btn
		_btn_count_plus = plus_btn
		_btn_count_num_lbl = num_lbl
	else:
		_btn_value_minus = minus_btn
		_btn_value_plus = plus_btn
		_btn_value_num_lbl = num_lbl

func _add_border(parent: Control, w: int, h: int, col: Color, thickness: int = 2) -> void:
	var t: int = thickness
	for d: Array in [[0,0,w,t], [0,h-t,w,t], [0,0,t,h], [w-t,0,t,h]]:
		var r: ColorRect = ColorRect.new()
		r.position = Vector2(d[0], d[1])
		r.size = Vector2(d[2] - d[0], d[3] - d[1])
		r.color = col
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(r)

func _paint_card_to_bg(bg: ColorRect, card: Resource) -> void:
	if bg == null or card == null: return
	# Remove old stripes/badges
	for child in bg.get_children():
		if child.name.begins_with("CardStripe_") or child.name.begins_with("RarityBadge_"):
			child.queue_free()
	var accent: Color = card.get_rarity_color()
	bg.color = accent.darkened(0.7)
	var stripe := ColorRect.new()
	stripe.position = Vector2(0, 0)
	stripe.size = Vector2(bg.size.x, 4)
	stripe.color = accent
	stripe.name = "CardStripe_" + str(card.card_id)
	bg.add_child(stripe)
	var badge := Label.new()
	badge.text = card.get_rarity_name()
	badge.position = Vector2(bg.size.x - 56, 6)
	badge.size = Vector2(50, 16)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.add_theme_font_size_override("font_size", 9)
	badge.add_theme_color_override("font_color", accent)
	badge.name = "RarityBadge_" + str(card.card_id)
	bg.add_child(badge)

func _noop() -> void:
	pass

func _connect_all() -> void:
	if game_ctrl == null:
		push_error("game_ctrl is null")
		return
	game_ctrl.turn_changed.connect(_on_turn_changed)
	game_ctrl.bid_updated.connect(_on_bid_updated)
	game_ctrl.challenge_happened.connect(_on_challenge_result)
	game_ctrl.game_over.connect(_on_game_over)
	game_ctrl.round_started.connect(_on_round_started)
	game_ctrl.dice_revealed.connect(_on_dice_revealed)
	if game_ctrl.has_signal("boss_skill_effect"):
		game_ctrl.boss_skill_effect.connect(_on_boss_skill_effect)

	# Buttons already connected via _make_btn_at — no extra gui_input needed

	EventBus.gold_changed.connect(_refresh_points)
	EventBus.half_assimilated.connect(_on_half_assimilated)
	EventBus.card_skill_triggered.connect(_on_card_skill_triggered)
	EventBus.hint_show.connect(_on_hint_show)
	EventBus.tutorial_hint_show.connect(_on_tutorial_hint_show)
	EventBus.discard_prompt.connect(_on_discard_prompt)

func setup_with_flow(stage: Resource, flow: Node, param3: Variant = null) -> void:
	flow_parent = flow
	var cards: Array = []
	var is_boss: bool = false
	if param3 is Array:
		cards = param3
		is_boss = cards.size() >= 3
		_drawn_cards = cards
	elif param3 is bool:
		is_boss = param3
	if is_boss:
		_card_count = 3
		var boss_x: Array[int] = [174, 543, 912]
		if _opp_bg1: _opp_bg1.position.x = boss_x[0]
		if _opp_bg2: _opp_bg2.position.x = boss_x[1]
		if _opp_bg3: _opp_bg3.position.x = boss_x[2]
		if opponent_label: opponent_label.position.x = boss_x[0] + 8
		if opponent_label2: opponent_label2.position.x = boss_x[1] + 8
		if opponent_label3: opponent_label3.position.x = boss_x[2] + 8
		if _sk_label1: _sk_label1.position.x = boss_x[0] + 8
		if _sk_label2: _sk_label2.position.x = boss_x[1] + 8
		if _sk_label3: _sk_label3.position.x = boss_x[2] + 8
		# Skill badge: position based on (card_w - 160) / 2 + ox
		if opponent_face: opponent_face.position.x = boss_x[0] + 8
		if opponent_face2: opponent_face2.position.x = boss_x[1] + 8
		if opponent_face3: opponent_face3.position.x = boss_x[2] + 8
		if _sk_bg1: _sk_bg1.position.x = boss_x[0] + (195 - 160) / 2
		if _sk_bg2: _sk_bg2.position.x = boss_x[1] + (195 - 160) / 2
		if _sk_bg3: _sk_bg3.position.x = boss_x[2] + (195 - 160) / 2
	# Build AI controllers from card data
	var card1: Resource = cards[0] if cards.size() > 0 else null
	var card2: Resource = cards[1] if cards.size() > 1 else null
	var card3: Resource = cards[2] if cards.size() > 2 else null
	_has_unknown = (card1 and card1.rarity == 5) or (card2 and card2.rarity == 5) or (card3 and card3.rarity == 5)
	_is_boss_match = card3 != null
	if card1 == null:
		push_error("DiceGameHUD: no cards provided!"); return
	var has_dark: bool = stage.mutation == 1
	if card3:
		game_ctrl.start_game(card1, card2, has_dark, card3, true)
		if opponent_label3: opponent_label3.text = card3.card_name
	else:
		game_ctrl.start_game(card1, card2, has_dark)
	if opponent_label: opponent_label.text = card1.card_name
	if card2:
		if opponent_label2: opponent_label2.text = card2.card_name
		if _sk_label2: _sk_label2.text = "技能：「%s」" % card2.skill_name
	else:
		# 单对手：隐藏 opponent_label2 整套元素
		if opponent_label2: opponent_label2.visible = false
		if _sk_label2: _sk_label2.visible = false
		if _sk_bg2: _sk_bg2.visible = false
		if opponent_face2: opponent_face2.visible = false
		if _opp_bg2:
			_opp_bg2.visible = false
			# 清理 bg 上的 card stripes/badges
			for child in _opp_bg2.get_children():
				child.queue_free()
	if _sk_label1: _sk_label1.text = "技能：「%s」" % card1.skill_name
	_paint_card_to_bg(_opp_bg1, card1)
	_paint_card_to_bg(_opp_bg2, card2)

	# Boss: show 3rd card
	var is_boss_actual := card3 != null
	if is_boss_actual:
		if GameState.mark_tutorial_topic("boss_card"):
			EventBus.tutorial_hint_show.emit("Boss战有三名对手：第三张卡是Boss主体，会同时拥有原技能和额外Boss技能。", 8.0)
		if _opp_bg3: _opp_bg3.visible = true
		if opponent_label3: opponent_label3.text = card3.card_name
		if _sk_label3:
			var boss_skill_name: String = preload("res://scripts/resources/BossFragmentData.gd").get_boss_skill_name(card3.card_id)
			_sk_label3.text = "技能：「%s」+「%s」" % [card3.skill_name, boss_skill_name]
		_paint_card_to_bg(_opp_bg3, card3)
	else:
		if _opp_bg3: _opp_bg3.visible = false
		if opponent_label3: opponent_label3.visible = false
		if opponent_face3: opponent_face3.visible = false
		if _sk_label3: _sk_label3.visible = false
	_bid_count = game_ctrl.get_min_opening()
	_bid_value = 2
	_refresh_adjust_labels()
	if GameState.assimilation_count == 1 and GameState.assimilation_curse.is_empty():
		call_deferred("_show_assimilation_choice")
	# NOTE: do NOT call _show_actions(false) here!
	# _on_round_started and _on_turn_changed handle visibility via signals

	if _opp_bg3 and _opp_bg3.get_parent(): _opp_bg3.visible = is_boss
	if opponent_label3 and opponent_label3.get_parent(): opponent_label3.visible = is_boss
	if opponent_face3 and opponent_face3.get_parent(): opponent_face3.visible = is_boss

func _adjust_count(delta: int) -> void:
	_bid_count = clampi(_bid_count + delta, 1, 99)
	_refresh_adjust_labels()

## Add 3rd opponent (boss) — 3 AIs share the big opponent area (same height 420, equal width)
func _add_boss_third_opponent(name: String) -> void:
	var dw: int = 44
	var mx: int = dw + 4
	var mw: int = 1280 - mx - 4
	var gap: int = 8
	var card_h: int = 420
	var card_y: int = 28
	var small_w: int = (mw - 2 * gap) / 3
	if _opp_bg1:
		_opp_bg1.position = Vector2(mx, card_y)
		_opp_bg1.size = Vector2(small_w, card_h)
	if _opp_bg2:
		_opp_bg2.position = Vector2(mx + small_w + gap, card_y)
		_opp_bg2.size = Vector2(small_w, card_h)
	if opponent_label: opponent_label.position = Vector2(mx + 12, card_y + 14)
	if opponent_label2: opponent_label2.position = Vector2(mx + small_w + gap + 12, card_y + 14)
	if opponent_face: opponent_face.position = Vector2(mx + 12, card_y + 60)
	if opponent_face2: opponent_face2.position = Vector2(mx + small_w + gap + 12, card_y + 60)
	# Boss card on the right (3rd slot)
	var boss_x: int = mx + 2 * (small_w + gap)
	var boss_bg: ColorRect = ColorRect.new()
	boss_bg.position = Vector2(boss_x, card_y)
	boss_bg.size = Vector2(small_w, card_h)
	boss_bg.color = Color(0.12, 0.05, 0.05, 1)
	add_child(boss_bg)
	_add_border(boss_bg, small_w, card_h, Color(0.85, 0.18, 0.18), 2)
	_opp_bg3 = boss_bg
	# Boss name (centered)
	var boss_name: Label = _make_label(name, Vector2(boss_x + 12, card_y + 14), Vector2(small_w - 24, 24), Color(1, 0.4, 0.4), 15)
	add_child(boss_name)
	opponent_label3 = boss_name
	# Boss bid
	var boss_bid: Label = _make_label("", Vector2(boss_x + 12, card_y + 60), Vector2(small_w - 24, 36), Color(1, 1, 0.3, 1), 16)
	boss_bid.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(boss_bid)
	opponent_face3 = boss_bid



func _adjust_value(delta: int) -> void:
	_bid_value = clampi(_bid_value + delta, 1, 6)
	_refresh_adjust_labels()

func _refresh_adjust_labels() -> void:
	if _btn_count_num_lbl:
		_btn_count_num_lbl.text = str(_bid_count)
	if _btn_value_num_lbl:
		_btn_value_num_lbl.text = str(_bid_value)
	if _btn_bid_lbl:
		_btn_bid_lbl.text = "确认 %d 个 %d" % [_bid_count, _bid_value]
	if _btn_bid:
		var valid: bool = _is_current_bid_valid()
		_btn_bid.color = Color(0.15, 0.35, 0.5, 1) if valid else Color(0.08, 0.08, 0.1, 0.6)
		_btn_bid.mouse_filter = Control.MOUSE_FILTER_STOP if valid else Control.MOUSE_FILTER_IGNORE

## Delegate all bid legality, including same-count higher-face raises, to game logic.
func _is_current_bid_valid() -> bool:
	if not game_ctrl:
		return false
	if _bid_value < 1 or _bid_value > 6 or _bid_count < 1:
		return false
	return game_ctrl.is_player_bid_valid(_bid_count, _bid_value)

func _select_legal_bid() -> void:
	if not game_ctrl or _is_current_bid_valid():
		return
	var legal: Dictionary = game_ctrl.find_legal_player_bid(_bid_count, _bid_value)
	if legal.is_empty():
		return
	_bid_count = int(legal.count)
	_bid_value = int(legal.value)

func _on_round_started() -> void:
	_game_over_winner = ""
	for child in get_children():
		if child is Control and child.name == "DiceRevealOverlay":
			child.queue_free()
	_bid_count = game_ctrl.get_min_opening()
	_bid_value = max(2, game_ctrl.current_bid_value)
	_select_legal_bid()
	if bid_display:
		bid_display.text = "开局"
	_refresh_adjust_labels()
	_play_dice_animation()
	# Clear bid overlays, restore avatar states
	_bid_face1 = ""; _bid_face2 = ""
	if opponent_face: opponent_face.text = ""
	if opponent_face2: opponent_face2.text = ""
	_update_eliminated()
	if game_ctrl.current_player == "player":
		_show_actions(true)
	else:
		_show_actions(false)

func _update_eliminated() -> void:
	if not game_ctrl: return
	var max_v: int = game_ctrl.AI_MAX_VIRUS
	if game_ctrl.ai1_virus >= max_v and opponent_face:
		opponent_face.text = "已淘汰 " + _dice_str(game_ctrl.get_ai_dice_values(0))
	if game_ctrl.ai2_virus >= max_v and opponent_face2:
		opponent_face2.text = "已淘汰 " + _dice_str(game_ctrl.get_ai_dice_values(1))
	if game_ctrl.ai3_virus >= max_v and opponent_face3:
		opponent_face3.text = "已淘汰 " + _dice_str(game_ctrl.get_ai_dice_values(2))

func _dice_str(vals: Array) -> String:
	if vals.is_empty(): return ""
	var parts: Array[String] = []
	for v in vals:
		parts.append(str(v) if v != -1 else "?")
	return " ".join(parts)

func _on_turn_changed(player: String) -> void:
	if not game_ctrl or not game_ctrl.game_active:
		return
	if player == "player":
		if status_label:
			status_label.text = "轮到你了"
			if game_ctrl.get("_tutorial_active") and game_ctrl.current_bid_count > 0:
				status_label.text = "对手叫牌已超过全桌骰子数，点击质疑"
				_set_tutorial_focus("challenge")
			elif game_ctrl.get("_tutorial_active"):
				_set_tutorial_focus("bid")
		if game_ctrl.current_bid_count > 0:
			_bid_count = max(game_ctrl.current_bid_count + 1, _bid_count)
		_select_legal_bid()
		_refresh_adjust_labels()
		_show_actions(true)
		_update_dice_display()
	else:
		var ai_name: String = game_ctrl.get_ai_name()
		if status_label:
			status_label.text = ai_name + " 思考中..."
		_show_actions(false)
		_update_dice_display()

func _on_bid_updated(count: int, value: int, player: String) -> void:
	if bid_display:
		bid_display.text = "%s: %d个%d" % [player, count, value]
	_log_event("%s 叫了 %d 个 %d" % [player, count, value])
	# AI bid: show bid text + trigger expression
	if player != "你" and game_ctrl and game_ctrl.ai_controller_1:
		var names_list: Array = game_ctrl.get_all_ai_names()
		var _ai_idx: int = -1
		if names_list.size() > 0 and player == names_list[0]:
			_ai_idx = 0
			_bid_face1 = "%d个%d" % [count, value]
			if opponent_face: opponent_face.text = _bid_face1
		elif names_list.size() > 1 and player == names_list[1]:
			_ai_idx = 1
			_bid_face2 = "%d个%d" % [count, value]
			if opponent_face2: opponent_face2.text = _bid_face2
		else:
			_ai_idx = 2
		# Update opponent bid text (no expression animation)
	_bid_count = count + 1
	_bid_value = value
	_select_legal_bid()
	# 较为夸张的叫牌 → 所有 AI 惊讶
	var total_dice: int = 10  # default 1v1: 5+5
	if game_ctrl:
		for cup in [game_ctrl.ai_cup_1, game_ctrl.ai_cup_2, game_ctrl.ai_cup_3]:
			if cup: total_dice += cup.dice.size()
		total_dice += game_ctrl.player_cup.dice.size() if game_ctrl.player_cup else 5
	var surprise_threshold: int = max(4, int(total_dice / 2))
	if count >= surprise_threshold and game_ctrl:
		for c in [game_ctrl.ai_controller_1, game_ctrl.ai_controller_2, game_ctrl.ai_controller_3]:
			if c and c.has_method("on_player_action"):
				pass  # AI notified
	_refresh_adjust_labels()

func _on_challenge_result(challenger: String, target: String, actual: int, bid: int) -> void:
	# Silent — challenge result is shown via the dice reveal overlay
	_log_event("%s 质疑 %s: 实有 %d, 叫 %d — %s" % [challenger, target, actual, bid, "质疑成功" if actual < bid else "质疑失败"])
	_show_actions(false)
	_update_dice_display()

## Shows both players' dice when a challenge resolves. Requires manual "继续" to proceed.
func _on_dice_revealed(player_vals: Array, ai1_vals: Array, ai2_vals: Array, ai3_vals: Array, is_final: bool, player_involved: bool, ai1_was_dead: bool, ai2_was_dead: bool) -> void:
	# Clean up any old overlay
	for child in get_children():
		if child is Control and child.name == "DiceRevealOverlay":
			child.queue_free()

	# Round 1 (no pre-dead): show all. Subsequent rounds: hide only AIs dead BEFORE this round
	var all_names: Array = game_ctrl.get_all_ai_names() if game_ctrl else []
	var ai1_name: String = str(all_names[0]) if all_names.size() > 0 else "对手1"
	var ai2_name: String = str(all_names[1]) if all_names.size() > 1 else "对手2"
	var ai3_name: String = str(all_names[2]) if all_names.size() > 2 else ""
	var lines: Array[String] = []
	lines.append(_dice_result_line("你", player_vals))
	if ai1_was_dead:
		lines.append("%s:  --已淘汰--" % ai1_name)
	else:
		lines.append(_dice_result_line(ai1_name, ai1_vals))
	if ai2_was_dead:
		lines.append("%s:  --已淘汰--" % ai2_name)
	else:
		lines.append(_dice_result_line(ai2_name, ai2_vals))
	if ai3_name != "":
		lines.append(_dice_result_line(ai3_name, ai3_vals))

	var text: String = "\n".join(lines)
	if game_ctrl and game_ctrl.has_method("get_chaos_reveal_text"):
		var chaos_txt: String = game_ctrl.get_chaos_reveal_text()
		if chaos_txt != "": text += "\n\n" + chaos_txt
	if _notify_label:
		_notify_label.text = text
	_hint_history.append(text)
	_last_reveal_text = text
	_last_reveal_round = game_ctrl.round_number if game_ctrl else -1

func _dice_result_line(display_name: String, values: Array) -> String:
	var dice_text: String = _dice_str(values) if not values.is_empty() else "无"
	return "%s（%d颗）:  %s" % [display_name, values.size(), dice_text]

func _get_final_dice_summary() -> String:
	if not _last_reveal_text.is_empty() and game_ctrl and _last_reveal_round == game_ctrl.round_number:
		return _last_reveal_text
	if not game_ctrl:
		return "暂无开骰记录"
	var names: Array = game_ctrl.get_all_ai_names()
	var lines: Array[String] = [_dice_result_line("你", game_ctrl.player_cup.get_all_values() if game_ctrl.player_cup else [])]
	var cups: Array = [game_ctrl.ai_cup_1, game_ctrl.ai_cup_2, game_ctrl.ai_cup_3]
	for i in range(mini(names.size(), cups.size())):
		var values: Array = cups[i].get_all_values() if cups[i] else []
		lines.append(_dice_result_line(str(names[i]), values))
	return "\n".join(lines)

func _add_final_dice_panel(parent: Control, position: Vector2, panel_size: Vector2) -> RichTextLabel:
	var panel := RichTextLabel.new()
	panel.name = "FinalDiceSummary"
	panel.bbcode_enabled = true
	panel.fit_content = false
	panel.text = "[b][color=#FFD766]最后开骰[/color][/b]\n" + _get_final_dice_summary()
	panel.position = position
	panel.size = panel_size
	panel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_theme_font_size_override("normal_font_size", 14)
	parent.add_child(panel)
	return panel

func _show_continue_button() -> void:
	var overlay: Control = Control.new()
	overlay.name = "DiceRevealOverlay"
	overlay.position = Vector2(0, 0)
	overlay.size = Vector2(1280, 720)
	add_child(overlay)
	var bg: ColorRect = ColorRect.new()
	bg.anchors_preset = 15; bg.anchor_right = 1.0; bg.anchor_bottom = 1.0
	bg.color = Color(0, 0, 0, 0)  # 完全透明
	overlay.add_child(bg)
	# Dice reveal text
	if _last_reveal_text != "":
		var rl := Label.new()
		rl.text = _last_reveal_text
		rl.position = Vector2(290, 380); rl.size = Vector2(700, 200)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rl.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
		rl.add_theme_font_size_override("font_size", 22)
		overlay.add_child(rl)
	var btn: ColorRect = _make_btn_at(overlay, Vector2(440, 640), Vector2(400, 50), "继续", Color(0.98, 0.78, 0.29), true,
		func():
			overlay.queue_free()
			if game_ctrl and game_ctrl.has_method("continue_after_challenge"):
				game_ctrl.continue_after_challenge()
	)

func _show_game_over_button() -> void:
	var overlay: Control = Control.new()
	overlay.name = "DiceRevealOverlay"
	overlay.position = Vector2(0, 0)
	overlay.size = Vector2(1280, 720)
	add_child(overlay)
	var bg: ColorRect = ColorRect.new()
	bg.anchors_preset = 15; bg.anchor_right = 1.0; bg.anchor_bottom = 1.0
	bg.color = Color(0, 0, 0, 0)  # 完全透明
	overlay.add_child(bg)
	# Dice reveal text
	if _last_reveal_text != "":
		var rl := Label.new()
		rl.text = _last_reveal_text
		rl.position = Vector2(290, 380); rl.size = Vector2(700, 200)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rl.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
		rl.add_theme_font_size_override("font_size", 22)
		overlay.add_child(rl)
	var btn: ColorRect = _make_btn_at(overlay, Vector2(440, 640), Vector2(400, 50), "继续", Color(0.98, 0.78, 0.29), true, _make_reveal_continue_callback(overlay))

func _make_reveal_continue_callback(overlay: Control) -> Callable:
	var ov_ref: Control = overlay
	return func():
		ov_ref.queue_free()
		if _game_over_winner == "ai":
			_show_death_dialog()
		elif flow_parent and flow_parent.has_method("emit_node_done"):
			await get_tree().create_timer(1.0).timeout
			flow_parent.emit_node_done()

## Show blue-screen death screen (full screen, no stats)
func _show_death_dialog() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.02, 0.05, 0.18)  # true blue
	bg.anchors_preset = PRESET_FULL_RECT
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.name = "DeathDialog"
	bg.z_index = 100
	add_child(bg)

	var sy: int = 180

	# Blue screen header
	var h1: Label = Label.new()
	h1.text = "CRITICAL_PROCESS_DIED"
	h1.position = Vector2(0, sy)
	h1.size = Vector2(1280, 50)
	h1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h1.add_theme_font_size_override("font_size", 36)
	h1.add_theme_color_override("font_color", Color(1, 1, 1))
	bg.add_child(h1)
	sy += 70

	var h2: Label = Label.new()
	h2.text = "你的系统崩溃了。又一个勇士倒下。"
	h2.position = Vector2(0, sy)
	h2.size = Vector2(1280, 30)
	h2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h2.add_theme_font_size_override("font_size", 16)
	h2.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	bg.add_child(h2)
	sy += 55

	# Error code
	var err: Label = Label.new()
	err.text = "ERROR: 0x0000DEAD  —  MEMORY DUMP"
	err.position = Vector2(0, sy)
	err.size = Vector2(1280, 25)
	err.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	err.add_theme_font_size_override("font_size", 13)
	err.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	bg.add_child(err)
	sy += 80

	# Buttons — centered
	var btn_y: int = sy
	var btn_w: int = 200
	var total_w: int = btn_w * 2 + 40
	var start_x: int = (1280 - total_w) / 2
	GameButton.create(bg, Vector2(start_x, btn_y), Vector2(btn_w, 50), "新的勇士", Color(0.36, 0.79, 0.65), _on_death_restart)
	GameButton.create(bg, Vector2(start_x + btn_w + 40, btn_y), Vector2(btn_w, 50), "返回主页面", Color(0.5, 0.5, 0.55), _on_death_to_menu)

func _on_death_restart() -> void:
	# Reset game state and restart from stage 1
	GameState.setup_new_run()
	GameState.current_stage = 0
	GameState.current_node_index = 0
	get_tree().change_scene_to_file("res://scenes/gameflow/RunManager.tscn")

func _on_death_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

var _dice_overlay: Control
var _game_over_winner: String = ""
var _has_unknown: bool = false
var _is_boss_match: bool = false

func _on_game_over(winner: String) -> void:
	_game_over_winner = winner
	if winner == "player":
		var payout_reward: int = game_ctrl.claim_payout_reward() if game_ctrl and game_ctrl.has_method("claim_payout_reward") else 0
		if payout_reward > 0:
			GameState.add_gold(payout_reward)
			EventBus.hint_show.emit("清算完成：胜利额外获得%d金币" % payout_reward, 3.0, Color(0.98, 0.78, 0.29))
		_resolve_prisoner_contract()
		if status_label:
			status_label.text = "你赢了!"
		# 追踪：击败敌人计数
		GameState.enemies_defeated_this_run += 1
		var base_xp: int = GameState.XP_PER_BOSS if _is_boss_match else GameState.XP_PER_ENEMY
		var reward_multiplier: float = GameState.get_battle_reward_multiplier(_drawn_cards)
		GameState._pending_xp += maxi(base_xp, floori(base_xp * reward_multiplier))
		_show_actions(false)
		# Rewards are resolved centrally by GameFlow.
		_show_victory_screen(false)
	else:
		if status_label:
			status_label.text = "你死机了... 蓝屏"
		_show_actions(false)
		if _is_boss_match and GameState.current_stage == 3 and game_ctrl and game_ctrl.get("_boss_card_id") == "dice_god" and GameState.royal_fragment_available:
			_show_royal_fragment_retry()
		else:
			_finalize_run_death()

func _resolve_prisoner_contract() -> void:
	if GameState.current_contract.is_empty() or not game_ctrl:
		return
	var title: String = str(GameState.current_contract.get("title", "囚徒交易"))
	if not game_ctrl.contract_was_completed():
		GameState.prisoner_breaches += 1
		var penalty_type: String = str(GameState.current_contract.get("penalty_type", ""))
		var penalty: int = int(GameState.current_contract.get("penalty", 0))
		if penalty_type == "gold":
			penalty += int(GameState.current_contract.get("stage", GameState.current_stage)) * 5
			var lost: int = mini(GameState.gold, penalty)
			if lost > 0: GameState.spend_gold(lost)
			EventBus.hint_show.emit("交易违约·%s：失去%d金币" % [title, lost], 4.0, Color(0.94, 0.4, 0.4))
		elif penalty_type == "next_die":
			GameState.adjust_bonus_dice(-penalty)
			EventBus.hint_show.emit("交易违约·%s：下一场战斗−%d骰" % [title, penalty], 4.0, Color(0.94, 0.4, 0.4))
		return
	if GameState.current_contract.get("reward_type", "") == "gold":
		var amount: int = int(GameState.current_contract.get("reward", 0))
		GameState.add_gold(amount)
		EventBus.hint_show.emit("交易完成·%s：+%d金币" % [title, amount], 4.0, Color(0.75, 0.45, 0.85))
	else:
		var item_id: String = "reroll_stone"
		var common_items: Array = ItemData.get_unlocked_pool().filter(func(item): return item.rarity == ItemData.Rarity.COMMON)
		if not common_items.is_empty(): item_id = common_items[randi() % common_items.size()].item_id
		GameState.add_consumable_item(item_id)
		EventBus.hint_show.emit("交易完成·%s：获得普通道具" % title, 4.0, Color(0.75, 0.45, 0.85))

func _finalize_run_death() -> void:
	GameState.final_stage_reached = GameState.current_stage
	GameState.final_node_reached = GameState.current_node_index
	GameState.commit_pending_xp()
	GameState.delete_run_save()
	GameState.save_progress()
	_show_death_screen()

func _show_royal_fragment_retry() -> void:
	var overlay := ColorRect.new()
	overlay.name = "RoyalFragmentRetry"
	overlay.position = Vector2.ZERO
	overlay.size = Vector2(1280, 720)
	overlay.color = Color(0.018, 0.012, 0.035, 0.98)
	overlay.z_index = 500
	add_child(overlay)
	var title := Label.new(); title.text = "王权碎片正在崩裂"; title.position = Vector2(240, 120); title.size = Vector2(800, 60); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size", 31); title.add_theme_color_override("font_color", Color(0.98, 0.78, 0.29)); overlay.add_child(title)
	var desc := Label.new(); desc.text = "被流放的国王替你挡住了完全同化。\n消耗王权碎片，可以将骰子之神战恢复到进入对局前并重新挑战一次。"; desc.position = Vector2(280, 225); desc.size = Vector2(720, 120); desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; desc.add_theme_font_size_override("font_size", 19); overlay.add_child(desc)
	var retry := Button.new(); retry.text = "消耗碎片 · 重新挑战"; retry.position = Vector2(315, 420); retry.size = Vector2(300, 60); retry.pressed.connect(_retry_dice_god_with_royal_fragment); overlay.add_child(retry)
	var give_up := Button.new(); give_up.text = "放弃重战"; give_up.position = Vector2(665, 420); give_up.size = Vector2(300, 60); give_up.pressed.connect(func(): overlay.queue_free(); _finalize_run_death()); overlay.add_child(give_up)

func _retry_dice_god_with_royal_fragment() -> void:
	if not GameState.consume_royal_fragment_retry():
		_finalize_run_death()
		return
	get_tree().change_scene_to_file("res://scenes/gameflow/RunManager.tscn")

func _show_death_screen() -> void:
	var overlay: Control = Control.new()
	overlay.name = "DeathOverlay"
	overlay.position = Vector2(0, 0)
	overlay.size = Vector2(1280, 720)
	add_child(overlay)
	var bg: ColorRect = ColorRect.new()
	bg.anchors_preset = 15; bg.anchor_right = 1.0; bg.anchor_bottom = 1.0
	bg.color = Color(0.02, 0.05, 0.12)
	overlay.add_child(bg)

	# Blue-screen title
	var title := Label.new()
	title.text = "CRITICAL_PROCESS_DIED"
	title.position = Vector2(290, 80); title.size = Vector2(700, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.2, 0.5, 0.98))
	title.add_theme_font_size_override("font_size", 32)
	overlay.add_child(title)

	var sub := Label.new()
	sub.text = "LOADING MEMORY FRAGMENTS..."
	sub.position = Vector2(290, 130); sub.size = Vector2(700, 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	sub.add_theme_font_size_override("font_size", 14)
	overlay.add_child(sub)

	# Stats panel
	var stage_names: Array[String] = ["破烂后院", "地下赌场", "黑帮私局", "终极赌场"]
	var stg: String = stage_names[clamp(GameState.final_stage_reached, 0, 3)]
	var node: int = GameState.final_node_reached + 1
	var def: int = GameState.enemies_defeated_this_run
	var bosses: String = ", ".join(GameState.bosses_defeated) if GameState.bosses_defeated.size() > 0 else "无"
	var rp: int = GameState._run_rust_points

	var stats := RichTextLabel.new()
	stats.bbcode_enabled = true
	stats.text = "[b]本轮战绩[/b]\n\n" \
		+ "到达阶段: [color=#FFD700]%s[/color]\n" % stg \
		+ "到达节点: [color=#c0c0d0]第%d节点[/color]\n" % node \
		+ "击败敌人: [color=#e0a0a0]%d[/color] 个\n" % def \
		+ "击败Boss: [color=#D4A535]%s[/color]\n" % bosses \
		+ "获得锈点: [color=#D4A535]%d[/color]\n" % rp \
		+ "经验: [color=#5cdb9e]+%d XP[/color] (Lv.%d)" % [GameState._run_xp, GameState.player_level]
	stats.position = Vector2(290, 175); stats.size = Vector2(700, 175)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 16)
	overlay.add_child(stats)
	_add_final_dice_panel(overlay, Vector2(290, 345), Vector2(700, 105))

	# XP bar
	var xp_y: float = 465.0
	var xp_bg := ColorRect.new()
	xp_bg.position = Vector2(340, xp_y); xp_bg.size = Vector2(600, 10)
	xp_bg.color = Color(0.08, 0.08, 0.14)
	overlay.add_child(xp_bg)
	var xp_pct: float = clampf(float(GameState.player_xp) / GameState.xp_for_next_level(), 0.0, 1.0)
	var xp_fill := ColorRect.new()
	xp_fill.position = Vector2(340, xp_y); xp_fill.size = Vector2(600 * xp_pct, 10)
	xp_fill.color = Color(0.35, 0.6, 0.8)
	overlay.add_child(xp_fill)
	var xp_lbl := Label.new()
	var pending: int = GameState._pending_xp
	var xp_text: String = "Lv.%d  %d / %d XP" % [GameState.player_level, GameState.player_xp, GameState.xp_for_next_level()]
	if pending > 0:
		xp_text += "   (当局 +%d 待结算)" % pending
	xp_lbl.text = xp_text
	xp_lbl.position = Vector2(340, xp_y + 14); xp_lbl.size = Vector2(600, 18)
	xp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_lbl.add_theme_font_size_override("font_size", 11)
	xp_lbl.add_theme_color_override("font_color", Color(0.4, 0.5, 0.6))
	overlay.add_child(xp_lbl)

	var btn_retry: ColorRect = _make_btn_at(overlay, Vector2(340, 520), Vector2(280, 50), "重新挑战", Color(0.36, 0.79, 0.65), true,
		func():
			overlay.queue_free()
			_check_and_show_unlocks(func():
				GameState.setup_new_run()
				get_tree().change_scene_to_file("res://scenes/gameflow/RunManager.tscn")
			)
	)
	var btn_menu: ColorRect = _make_btn_at(overlay, Vector2(660, 520), Vector2(280, 50), "返回主菜单", Color(0.5, 0.5, 0.5), true,
		func():
			overlay.queue_free()
			_check_and_show_unlocks(func():
				get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
			)
	)

func _show_victory_screen(has_elite: bool = false) -> void:
	var overlay: Control = Control.new()
	overlay.name = "VictoryOverlay"
	overlay.position = Vector2(0, 0)
	overlay.size = Vector2(1280, 720)
	add_child(overlay)
	var bg: ColorRect = ColorRect.new()
	bg.anchors_preset = 15; bg.anchor_right = 1.0; bg.anchor_bottom = 1.0
	bg.color = Color(0, 0, 0, 0.7)
	overlay.add_child(bg)

	var title := Label.new()
	title.text = "胜 利"
	title.position = Vector2(290, 60); title.size = Vector2(700, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.98, 0.78, 0.29))
	title.add_theme_font_size_override("font_size", 48)
	overlay.add_child(title)

	var stage_names: Array[String] = ["破烂后院", "地下赌场", "黑帮私局", "终极赌场"]
	var sname: String = stage_names[clamp(GameState.current_stage, 0, 3)]
	var pts_earned: int = 2 if _is_boss_match else 1
	var rust_info := RichTextLabel.new()
	rust_info.bbcode_enabled = true
	rust_info.text = "击破 [color=#FFD700]%s[/color]\n获得 [color=#D4A535]%d 锈蚀点[/color]  累计: %d" % [sname, pts_earned, GameState.rust_points]
	rust_info.position = Vector2(290, 148); rust_info.size = Vector2(700, 36)
	rust_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rust_info.add_theme_font_size_override("font_size", 16)
	overlay.add_child(rust_info)
	_add_final_dice_panel(overlay, Vector2(290, 350), Vector2(700, 150))

	# XP bar
	var xp_y: float = 200.0
	var xp_bg := ColorRect.new()
	xp_bg.position = Vector2(340, xp_y); xp_bg.size = Vector2(600, 10)
	xp_bg.color = Color(0.08, 0.08, 0.14)
	overlay.add_child(xp_bg)
	var xp_pct: float = clampf(float(GameState.player_xp) / GameState.xp_for_next_level(), 0.0, 1.0)
	var xp_fill := ColorRect.new()
	xp_fill.position = Vector2(340, xp_y); xp_fill.size = Vector2(600 * xp_pct, 10)
	xp_fill.color = Color(0.35, 0.6, 0.8)
	overlay.add_child(xp_fill)
	var xp_lbl := Label.new()
	var pending: int = GameState._pending_xp
	var xp_text: String = "Lv.%d  %d / %d XP" % [GameState.player_level, GameState.player_xp, GameState.xp_for_next_level()]
	if pending > 0:
		xp_text += "   (当局 +%d 待结算)" % pending
	xp_lbl.text = xp_text
	xp_lbl.position = Vector2(340, xp_y + 14); xp_lbl.size = Vector2(600, 18)
	xp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_lbl.add_theme_font_size_override("font_size", 11)
	xp_lbl.add_theme_color_override("font_color", Color(0.4, 0.5, 0.6))
	overlay.add_child(xp_lbl)

	var gold_amount: int = 0
	# Gold is awarded once by GameFlow when the node completes.
	var claimed: Dictionary = {"item": false, "gold": true}

	var cbs: Dictionary = {"item": Callable(), "gold": Callable(), "advance": Callable()}
	cbs["advance"] = func():
		overlay.queue_free()
		_check_and_show_unlocks(func(): EventBus.node_completed.emit(""))
	cbs["item"] = func():
		if claimed["item"]: return
		claimed["item"] = true
		_show_item_pick_inline(overlay, gold_amount, claimed, cbs["gold"], cbs["item"], cbs["advance"])
	cbs["gold"] = func():
		return

	_build_victory_buttons(overlay, claimed, cbs["item"], cbs["gold"], cbs["advance"], has_elite)

func _build_victory_buttons(overlay: Control, claimed: Dictionary, claim_item: Callable, claim_gold: Callable, do_advance: Callable, has_elite: bool) -> void:
	for c in overlay.get_children():
		if c is ColorRect and "PickCard" in str(c.name): c.queue_free()
		var n: String = c.name
		if n.begins_with("VBtn"): c.queue_free()

	if not claimed["item"] and has_elite:
		_make_btn_at(overlay, Vector2(340, 200), Vector2(600, 64), "领取道具 (三选一)", Color(0.75, 0.45, 0.85), true,
			func(): claim_item.call()
		).name = "VBtn1"
	if not claimed["gold"]:
		_make_btn_at(overlay, Vector2(340, 290 if (has_elite and not claimed["item"]) else 200), Vector2(600, 64), "领取金币 +%d" % ((GameState.current_stage + 1) * 25), Color(0.98, 0.78, 0.29), true,
			func(): claim_gold.call()
		).name = "VBtn2"
		_make_btn_at(overlay, Vector2(340, 380 if (has_elite and not claimed["item"]) else 290), Vector2(600, 64), "跳过奖励", Color(0.4, 0.4, 0.4), true,
			func(): do_advance.call()
		).name = "VBtn3"
	else:
		_make_btn_at(overlay, Vector2(340, 250), Vector2(600, 80), "下一关", Color(0.36, 0.79, 0.65), true,
			func(): do_advance.call()
		).name = "VBtnNext"

func _rebuild_victory_buttons(overlay: Control, claimed: Dictionary, do_advance: Callable, claim_gold: Callable = Callable()) -> void:
	_build_victory_buttons(overlay, claimed, Callable(), claim_gold, do_advance, false)

func _show_item_pick_inline(parent_overlay: Control, gold_amount: int, claimed: Dictionary, claim_gold: Callable, claim_item: Callable, do_advance: Callable) -> void:
	for c in parent_overlay.get_children():
		var n: String = c.name
		if n.begins_with("VBtn"): c.queue_free()
		elif n.begins_with("Pick"): c.queue_free()
	var candidates: Array = ItemData.get_random_shop_items(3)
	for i in range(min(3, candidates.size())):
		var item: ItemData = candidates[i]
		var x: float = 160 + i * 330
		var card_bg := ColorRect.new()
		card_bg.name = "PickCard"; card_bg.color = Color(0.15, 0.15, 0.2, 0.9)
		card_bg.position = Vector2(x, 180); card_bg.size = Vector2(300, 340)
		parent_overlay.add_child(card_bg)
		var name_lbl := Label.new()
		name_lbl.name = "PickLbl"
		name_lbl.text = item.get("item_name") if item.get("item_name") else item.get("card_name")
		name_lbl.position = Vector2(x + 10, 190); name_lbl.size = Vector2(280, 40)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_color_override("font_color", item.get_rarity_color())
		name_lbl.add_theme_font_size_override("font_size", 20)
		parent_overlay.add_child(name_lbl)
		var rarity_lbl := Label.new()
		rarity_lbl.name = "PickLbl"
		rarity_lbl.text = item.get_rarity_name()
		rarity_lbl.position = Vector2(x + 10, 230); rarity_lbl.size = Vector2(280, 30)
		rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rarity_lbl.add_theme_color_override("font_color", item.get_rarity_color())
		rarity_lbl.add_theme_font_size_override("font_size", 14)
		parent_overlay.add_child(rarity_lbl)
		var desc_lbl := Label.new()
		desc_lbl.name = "PickLbl"
		desc_lbl.text = item.get("description") if item.get("description") else item.get("card_description")
		desc_lbl.position = Vector2(x + 10, 270); desc_lbl.size = Vector2(280, 200)
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		desc_lbl.add_theme_font_size_override("font_size", 14)
		parent_overlay.add_child(desc_lbl)
		_make_btn_at(parent_overlay, Vector2(x + 40, 480), Vector2(220, 40), "拾取", item.get_rarity_color(), true,
			func():
				GameState.add_consumable_item(item.item_id)
				EventBus.item_used.emit(item.item_id)
				_clear_pick_children(parent_overlay)
				_build_victory_buttons(parent_overlay, claimed, claim_item, claim_gold, do_advance, true)
		)

func _clear_pick_children(overlay: Control) -> void:
	for c in overlay.get_children():
		var n: String = c.name
		if n.begins_with("Pick"): c.queue_free()
		elif n.begins_with("VBtn"): c.queue_free()


func _build_pause_menu() -> void:
	_pause_overlay = Control.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.position = Vector2(0, 0)
	_pause_overlay.size = Vector2(1280, 720)
	_pause_overlay.visible = false
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_pause_overlay)

	# Dim background
	var dim: ColorRect = ColorRect.new()
	dim.position = Vector2(0, 0)
	dim.size = Vector2(1280, 720)
	dim.color = Color(0, 0, 0, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.add_child(dim)

	# Menu card (taller for 4 buttons)
	var cy: int = 200
	var ch: int = 340
	var card: ColorRect = ColorRect.new()
	card.position = Vector2(440, cy)
	card.size = Vector2(400, ch)
	card.color = Color(0.1, 0.1, 0.12, 1)
	_pause_overlay.add_child(card)
	_add_border(card, 400, ch, Color(0.98, 0.78, 0.29, 1), 2)

	# Title
	var title: Label = Label.new()
	title.text = "暂 停"
	title.position = Vector2(440, cy + 16)
	title.size = Vector2(400, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.98, 0.78, 0.29, 1))
	_pause_overlay.add_child(title)

	var btn_y: int = cy + 70
	var btn_gap: int = 56

	# 1. 继续游戏
	_add_pause_btn(btn_y, "继续游戏", Color(0.36, 0.74, 0.95), func():
		_hide_pause_menu())
	btn_y += btn_gap

	# 2. 设置 (placeholder)
	_add_pause_btn(btn_y, "设  置", Color(0.5, 0.5, 0.55), func():
		if status_label: status_label.text = "设置功能尚未开放")
	btn_y += btn_gap

	# 3. 暂退游戏
	_add_pause_btn(btn_y, "暂退游戏", Color(0.8, 0.65, 0.25), func():
		var virus: int = game_ctrl.player_virus if game_ctrl else 0
		var disabled_items: Array = game_ctrl.get_temporarily_disabled_player_items() if game_ctrl and game_ctrl.has_method("get_temporarily_disabled_player_items") else []
		var restart_modifiers: Dictionary = game_ctrl.get_battle_restart_modifiers() if game_ctrl and game_ctrl.has_method("get_battle_restart_modifiers") else {}
		GameState.save_run(virus, disabled_items, restart_modifiers)
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn"))
	btn_y += btn_gap

	# 4. 放弃游戏
	_add_pause_btn(btn_y, "放弃游戏", Color(0.94, 0.4, 0.4), func():
		GameState._clear_save()
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn"))
	btn_y += btn_gap

	# Hint
	var hint: Label = Label.new()
	hint.text = "按 ESC 继续 / 鼠标点击按钮"
	hint.position = Vector2(440, cy + ch - 28)
	hint.size = Vector2(400, 22)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	_pause_overlay.add_child(hint)

func _add_pause_btn(y: int, text: String, col: Color, cb: Callable) -> void:
	var btn: ColorRect = ColorRect.new()
	btn.position = Vector2(490, y)
	btn.size = Vector2(300, 48)
	btn.color = col
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_overlay.add_child(btn)
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.position = Vector2(0, 0)
	lbl.size = Vector2(300, 48)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_child(lbl)
	btn.mouse_entered.connect(func(): btn.color = col.lightened(0.15))
	btn.mouse_exited.connect(func(): btn.color = col)
	btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			cb.call()
	)

func _show_pause_menu() -> void:
	if not _pause_overlay:
		return
	_pause_overlay.visible = true
	_pause_visible = true
	# Pause the game by stopping processing
	if game_ctrl and game_ctrl.has_method("set_physics_process"):
		game_ctrl.set_physics_process(false)

func _hide_pause_menu() -> void:
	if not _pause_overlay:
		return
	_pause_overlay.visible = false
	_pause_visible = false
	if game_ctrl and game_ctrl.has_method("set_physics_process"):
		game_ctrl.set_physics_process(true)

func _on_return_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _on_challenge_pressed() -> void:
	if not game_ctrl.player_challenge():
		return
	for c in [game_ctrl.ai_controller_1, game_ctrl.ai_controller_2, game_ctrl.ai_controller_3]:
		if c and c.has_method("on_player_action"):
			c.on_player_action("challenge")

func _on_bid_pressed() -> void:
	if not game_ctrl.player_bid(_bid_count, _bid_value):
		_select_legal_bid()
		_refresh_adjust_labels()
		return
	for c in [game_ctrl.ai_controller_1, game_ctrl.ai_controller_2, game_ctrl.ai_controller_3]:
		if c and c.has_method("on_player_action"):
			c.on_player_action("raise")

## Use a consumable item by id — dispatches to game_ctrl effects
func _use_consumable_item(item_id: String) -> void:
	if _item_locked: return
	_item_locked = true
	var item_data: ItemData = GameState.get_item_info(item_id)
	if not item_data:
		_item_locked = false; return
	# Only usable during player's turn
	if not game_ctrl or game_ctrl.current_player != "player" or not game_ctrl.game_active:
		if status_label:
			status_label.text = "只能在你的回合使用道具"
			await get_tree().create_timer(1.2).timeout
			if status_label: status_label.text = ""
		_item_locked = false; return

	match item_id:
		"reroll_stone", "freeze_die":
			_enter_selection_mode(item_id)
			return  # Don't consume yet — wait for confirm
		"fate_die":
			_enter_selection_mode(item_id)
			return
		"full_reroll":
			game_ctrl.reroll_player_dice(false)
			_update_dice_display()
			GameState.use_consumable(item_id)
			if status_label: status_label.text = ""
			 # fall through to unlock _item_locked
		"flip_die":
			_enter_selection_mode(item_id)
			return
			GameState.use_consumable(item_id)
		"silent_turn":
			game_ctrl.skip_player_turn()
			GameState.use_consumable(item_id)
		"see_dark":
			_enter_peek_mode(item_id)
			return
		"emergency_restart":
			# Big/Small judge: select opponent, show size labels
			_enter_peek_mode(item_id)
			return
		"heat_vision", "borrow_die", "sabotage":
			_enter_peek_mode(item_id)
			return
		"split_die":
			_enter_selection_mode(item_id)
			return
		"clone_die":
			# Must have a pair — check before entering selection
			var pair_indices: Array[int] = game_ctrl.get_player_paired_dice()
			if pair_indices.size() == 0:
				if status_label:
					status_label.text = "没有对子，无法克隆"
					await get_tree().create_timer(1.2).timeout
					if status_label: status_label.text = "轮到你了"
				_item_locked = false
				return
			_enter_selection_mode(item_id)
			return
		"extra_die", "copy_die":
			game_ctrl.player_cup.add_die()
			GameState.use_consumable(item_id)
			_update_dice_display()
			_log_event("加骰: 本场对局增加1颗骰子")
			if status_label: status_label.text = "本场对局增加1颗骰子"
		"purge_chip":
			GameState.clear_assimilation()
			if game_ctrl:
				game_ctrl.player_virus = 0
			GameState.use_consumable(item_id)
			EventBus.hint_show.emit("净化芯片: 清除半同化", 3.0, Color(0.36, 0.79, 0.65))
			_refresh_virus()
			_log_event("净化芯片: 病毒已清除")
			if status_label: status_label.text = "病毒已清除!"
		"gambler_hunch":
			# Show the most common value across all cups
			var best_val: int = _get_most_common_value()
			GameState.use_consumable(item_id)
			_notify_label.text = "赌徒直觉: 全桌最多点数 %d" % best_val
			_log_event("赌徒直觉: 全桌最多点数 %d" % best_val)
			if status_label: status_label.text = "全桌最多点数: %d" % best_val
		"payout":
			game_ctrl.queue_payout_reward(15)
			GameState.use_consumable(item_id)
			if status_label: status_label.text = "胜利后结算 +15 金币"
		"rig_dice":
			# Select 2 dice to set to 1
			_enter_selection_mode(item_id)
			return
		"pair_fix":
			if not game_ctrl.apply_pair_fix():
				if status_label: status_label.text = "已有对子或没有可用骰子"
				_item_locked = false
				return
			GameState.use_consumable(item_id)
			_update_dice_display()
		"royal_pardon":
			if status_label: status_label.text = "国王赦免会在致死时自动消耗"
			_item_locked = false
			return
		_:
			GameState.use_consumable(item_id)
			if status_label:
				status_label.text = "使用了 " + item_data.item_name
				await get_tree().create_timer(1.0).timeout
				if status_label: status_label.text = "轮到你了"
	# Clear hover description since the used item is no longer there
	if _notify_label and _notify_label.text.begins_with("["):
		_notify_label.text = ""
	_refresh_item_display()
	_item_locked = false
	# 镜面技师复制道具
	if item_id != "" and game_ctrl and game_ctrl.has_method("mirror_item"):
		game_ctrl.mirror_item(item_id)

## Refresh left panel item labels after use/buy
## Refresh left dock item icons
const ITEM_EMOJI: Dictionary = {
	"reroll_stone": "-1", "freeze_die": "-7", "split_die": "+1",
	"full_reroll": "-5", "clone_die": "+2", "flip_die": "+3",
	"see_dark": "-8", "heat_vision": "-2",
	"emergency_restart": "+4", "silent_turn": "-3", "fate_die": "+5", "extra_die": "+6"
}
## Short Chinese labels shown below each item slot
const ITEM_NAMES: Dictionary = {
	"reroll_stone": "重摇", "freeze_die": "定格", "split_die": "裂变",
	"full_reroll": "全重摇", "clone_die": "克隆", "flip_die": "翻骰",
	"see_dark": "透屏", "heat_vision": "热感",
	"silent_turn": "静默", "fate_die": "命运", "extra_die": "加骰",
	"purge_chip": "净化", "gambler_hunch": "直觉",
	"pair_fix": "保底对", "royal_pardon": "赦免", "borrow_die": "借骰",
	"payout": "清算", "rig_dice": "虚张", "sabotage": "超频",
	}
func _refresh_item_display() -> void:
	for i in range(_consumable_labels.size()):
		var cl: Label = _consumable_labels[i]
		var nl: Label = _consumable_name_labels[i] if i < _consumable_name_labels.size() else null
		if not cl: continue
		var ibg: ColorRect = _item_bgs[i] if i < _item_bgs.size() else null
		if i < GameState.consumable_items.size():
			var item_data: ItemData = GameState.get_item_info(GameState.consumable_items[i])
			if item_data:
				cl.text = str(i + 1)
				cl.add_theme_color_override("font_color", item_data.get_rarity_color())
				if nl:
					var nm: String = ITEM_NAMES.get(item_data.item_id, item_data.item_name.left(4))
					nl.text = nm
					nl.add_theme_color_override("font_color", item_data.get_rarity_color())
				if ibg:
					ibg.modulate = Color(1, 1, 1, 1)
					ibg.mouse_filter = Control.MOUSE_FILTER_STOP
			else:
				cl.text = "-"
				cl.add_theme_color_override("font_color", Color(0.25, 0.25, 0.25))
				if nl: nl.text = ""
		else:
			cl.text = "-"
			cl.add_theme_color_override("font_color", Color(0.25, 0.25, 0.25))
			if nl: nl.text = ""
			if ibg: ibg.modulate = Color(1, 1, 1, 0.3)
	# Update dock count
	for child in get_children():
		if child is ColorRect:
			for gc in child.get_children():
				if gc is Label and gc.name == "DockCount":
					gc.text = str(GameState.consumable_items.size())
					break


func _on_world_event(_node_type: String = "") -> void:
	# Update notification from GameState
	if _notify_label and GameState.event_notification.length() > 0:
		_notify_label.text = GameState.event_notification

func _clear_event_notify(_stage: int = 0) -> void:
	GameState.event_notification = ""
	if _notify_label:
		_notify_label.text = ""

func _refresh_points(_amt: int = 0) -> void:
	if points_label:
		points_label.text = "金币 %d" % GameState.gold

# --- item selection mode (e.g. reroll_stone) ---

func _enter_selection_mode(item_id: String) -> void:
	_selecting_mode = true
	_selection_mode_type = item_id  # "reroll_stone" → reroll, "flip_die" → flip
	_active_item_id = item_id
	# Show hint in status bar
	if status_label:
		var hints: Dictionary = {
			"reroll_stone": "点击骰子选择要重摇的，绿色=已选",
			"flip_die": "点击一颗骰子直接翻转",
			"split_die": "点击一颗 >=4 的骰子裂变",
			"clone_die": "点击有对子的骰子克隆",
			"freeze_die": "选一颗骰子，下轮锁定该点数",
			"fate_die": "选一颗骰子，连续3轮固定为当前点数",
			"rig_dice": "选两颗骰子改为1点，绿色=已选",
		}
		status_label.text = hints.get(item_id, "选择一颗骰子")
	var total: int = max(game_ctrl.player_cup.get_values().size(), _die_labels.size())
	_selected_dice.clear()
	for i in range(total):
		_selected_dice.append(false)
	_update_dice_display()
	# Show confirm / cancel buttons
	_show_select_buttons()

func _exit_selection_mode() -> void:
	_selecting_mode = false
	_selection_mode_type = ""
	_active_item_id = ""
	_selected_dice.clear()
	_item_locked = false
	_update_dice_display()
	_hide_select_buttons()
	_refresh_item_display()

func _on_select_confirm() -> void:
	var indices: Array[int] = []
	for i in range(_selected_dice.size()):
		if _selected_dice[i]:
			indices.append(i)
	if _selection_mode_type == "rig_dice" and indices.size() != 2:
		if status_label: status_label.text = "必须选择两颗骰子"
		return
	if indices.size() > 0 and game_ctrl:
		var mirrored_item: String = _selection_mode_type
		if _selection_mode_type == "reroll_stone":
			game_ctrl.reroll_selected_dice(indices)
		elif _selection_mode_type == "split_die":
			game_ctrl.split_player_die(indices[0])
		elif _selection_mode_type == "rig_dice":
			# Set selected dice to 1
			for idx in indices:
				game_ctrl.set_player_die_value(idx, 1)
		game_ctrl.mirror_item(mirrored_item, {"index": indices[0], "indices": indices})
	GameState.use_consumable(_active_item_id)
	_update_dice_display()
	_exit_selection_mode()
	_refresh_item_display()

func _on_select_cancel() -> void:
	# Item was never consumed — just exit selection mode
	_exit_selection_mode()

func _update_die_highlight(idx: int) -> void:
	if idx >= _die_labels.size(): return
	var lbl: Label = _die_labels[idx] as Label
	var box: Node = lbl.get_parent() if lbl else null
	if not box: return
	if _selecting_mode and idx < _selected_dice.size():
		box.color = Color(0.36, 0.79, 0.65) if _selected_dice[idx] else Color(1, 1, 1)

func _show_select_buttons() -> void:
	if _selection_mode_type == "reroll_stone":
		_select_confirm_btn = _make_btn_at(self, Vector2(380, 640), Vector2(120, 44), "确认重摇", Color(0.11, 0.62, 0.46), true, _on_select_confirm)
		_select_cancel_btn = _make_btn_at(self, Vector2(510, 640), Vector2(120, 44), "取消", Color(0.5, 0.5, 0.5), true, _on_select_cancel)
	elif _selection_mode_type == "rig_dice":
		_select_confirm_btn = _make_btn_at(self, Vector2(380, 640), Vector2(120, 44), "确认为1", Color(0.11, 0.62, 0.46), true, _on_select_confirm)
		_select_cancel_btn = _make_btn_at(self, Vector2(510, 640), Vector2(120, 44), "取消 (道具退回)", Color(0.5, 0.5, 0.5), true, _on_select_cancel)
	elif _selection_mode_type == "split_die":
		_select_cancel_btn = _make_btn_at(self, Vector2(440, 640), Vector2(160, 44), "取消 (道具退回)", Color(0.5, 0.5, 0.5), true, _on_select_cancel)
	else:
		# flip, clone_die — only cancel, no confirm (single-click use)
		_select_cancel_btn = _make_btn_at(self, Vector2(440, 640), Vector2(160, 44), "取消 (道具退回)", Color(0.5, 0.5, 0.5), true, _on_select_cancel)

func _hide_select_buttons() -> void:
	if _select_confirm_btn: _select_confirm_btn.queue_free(); _select_confirm_btn = null
	if _select_cancel_btn: _select_cancel_btn.queue_free(); _select_cancel_btn = null

# --- Peek mode (透屏: select opponent → select position → reveal) ---

func _enter_peek_mode(item_id: String) -> void:
	_selecting_mode = true
	_selection_mode_type = item_id
	_active_item_id = item_id
	_peek_phase = "opponent"
	_peek_opponent = ""
	if status_label: status_label.text = "选择要偷看的对手"
	# Show opponent buttons over the avatar panels
	_show_peek_buttons()
	# Show cancel button
	_select_cancel_btn = _make_btn_at(self, Vector2(460, 640), Vector2(160, 44), "取消 (道具退回)", Color(0.5, 0.5, 0.5), true, _on_peek_cancel)

func _show_peek_buttons() -> void:
	var names: Array = game_ctrl.get_all_ai_names() if game_ctrl else []
	var ai1_name: String = names[0] if names.size() > 0 else "路人A"
	var ai2_name: String = names[1] if names.size() > 1 else "路人B"
	var ai3_name: String = names[2] if names.size() > 2 else "路人C"
	if game_ctrl.ai1_virus < game_ctrl.AI_MAX_VIRUS:
		_peek_btn1 = _make_btn_at(self, Vector2(330, 180), Vector2(160, 50), "看 " + ai1_name, Color(0.36, 0.79, 0.65), true, func(): _on_peek_opponent("ai1"))
	if game_ctrl.ai2_virus < game_ctrl.AI_MAX_VIRUS:
		_peek_btn2 = _make_btn_at(self, Vector2(800, 180), Vector2(160, 50), "看 " + ai2_name, Color(0.36, 0.79, 0.65), true, func(): _on_peek_opponent("ai2"))
	if game_ctrl.ai_controller_3 and game_ctrl.ai3_virus < game_ctrl.AI_MAX_VIRUS:
		_peek_btn3 = _make_btn_at(self, Vector2(1010, 180), Vector2(160, 50), "看 " + ai3_name, Color(0.36, 0.79, 0.65), true, func(): _on_peek_opponent("ai3"))

func _on_peek_opponent(ai_id: String) -> void:
	_peek_opponent = ai_id
	if _peek_btn1: _peek_btn1.queue_free(); _peek_btn1 = null
	if _peek_btn2: _peek_btn2.queue_free(); _peek_btn2 = null
	if _peek_btn3: _peek_btn3.queue_free(); _peek_btn3 = null
	# Size-reading items resolve immediately after choosing a target.
	if _selection_mode_type == "emergency_restart" or _selection_mode_type == "heat_vision":
		_on_peek_all_dice(ai_id)
		return
	if _selection_mode_type == "sabotage":
		if not game_ctrl.sabotage_enemy_dice(ai_id):
			if status_label: status_label.text = "对手仅剩1颗骰子，无法使用算力超频"
			_exit_peek_mode()
			_item_locked = false
			return
		GameState.use_consumable(_active_item_id)
		game_ctrl.mirror_item("sabotage")
		if _notify_label: _notify_label.text = "%s 有2颗骰子已变为①" % game_ctrl.get_ai_name_for_id(ai_id)
		_exit_peek_mode()
		_update_dice_display()
		return
	_peek_phase = "position"
	if status_label: status_label.text = "选择骰子位置 (1-5)"
	# Show dice as "?" for clicking
	_update_dice_display()

## heat_vision: instantly show all opponents' dice as red/blue blocks
func _show_all_opponents_heat_vision() -> void:
	if not game_ctrl: return
	var parts: Array[String] = []
	var log_parts: Array[String] = []
	var names: Array = game_ctrl.get_all_ai_names()
	if game_ctrl.ai1_virus < game_ctrl.AI_MAX_VIRUS:
		var v1: Array = game_ctrl.get_ai_dice_values(0)
		var n1: String = names[0] if names.size() > 0 else "AI1"
		parts.append("[color=#FF5555]" + n1 + ":[/color]\n" + _heat_vision_blocks(v1))
		log_parts.append("%s: %s" % [n1, _heat_vision_blocks(v1)])
	if game_ctrl.ai2_virus < game_ctrl.AI_MAX_VIRUS:
		var v2: Array = game_ctrl.get_ai_dice_values(1)
		var n2: String = names[1] if names.size() > 1 else "AI2"
		parts.append("[color=#FF5555]" + n2 + ":[/color]\n" + _heat_vision_blocks(v2))
		log_parts.append("%s: %s" % [n2, _heat_vision_blocks(v2)])
	if game_ctrl.ai3_virus < game_ctrl.AI_MAX_VIRUS:
		var v3: Array = game_ctrl.get_ai_dice_values(2)
		var n3: String = names[2] if names.size() > 2 else "AI3"
		parts.append("[color=#FF5555]" + n3 + ":[/color]\n" + _heat_vision_blocks(v3))
		log_parts.append("%s: %s" % [n3, _heat_vision_blocks(v3)])
	if _notify_label:
		_notify_label.bbcode_enabled = true
		_notify_label.text = "热感视觉:\n" + "\n".join(parts)
		_notify_label.add_theme_font_size_override("normal_font_size", 13)
	if status_label: status_label.text = "轮到你了"
	_log_event("热感视觉: " + ", ".join(log_parts))

func _heat_vision_blocks(cup_vals: Array) -> String:
	var blocks: Array[String] = []
	for i in range(cup_vals.size()):
		var v: int = cup_vals[i] as int
		if v <= 3:
			blocks.append("[color=#378ADD]■[/color]")
		else:
			blocks.append("[color=#E24B4A]■[/color]")
	return " ".join(blocks)

## emergency_restart: show opponent dice as colored blocks (red=big, blue=small)
func _on_peek_all_dice(ai_id: String) -> void:
	var ai_idx: int = int(ai_id.trim_prefix("ai")) - 1
	var cup_vals: Array = game_ctrl.get_ai_dice_values(ai_idx)
	var names: Array = game_ctrl.get_all_ai_names()
	var ai_name: String = names[ai_idx] if ai_idx >= 0 and ai_idx < names.size() else ai_id
	var blocks: Array[String] = []
	var small_cnt: int = 0; var big_cnt: int = 0
	for i in range(cup_vals.size()):
		var v: int = cup_vals[i] as int
		if v <= 3:
			blocks.append("[color=#378ADD]■[/color]")
			small_cnt += 1
		else:
			blocks.append("[color=#E24B4A]■[/color]")
			big_cnt += 1
	if _notify_label:
		_notify_label.text = "%s:\n%s\n[color=#378ADD]小x%d[/color]  [color=#E24B4A]大x%d[/color]" % [ai_name, " ".join(blocks), small_cnt, big_cnt]
	GameState.use_consumable(_active_item_id)
	_exit_peek_mode()

func _on_peek_position(idx: int) -> void:
	if _peek_phase != "position": return
	var val: int = game_ctrl.peek_ai_die(_peek_opponent, idx)
	var ai_idx: int = int(_peek_opponent.trim_prefix("ai")) - 1
	var names: Array = game_ctrl.get_all_ai_names()
	var ai_name: String = names[ai_idx] if ai_idx >= 0 and ai_idx < names.size() else _peek_opponent
	# Show result in dice result area
	if _notify_label:
		_notify_label.text = "透屏:\n%s 第%d颗 = %d\n(此信息仅保留本轮)" % [ai_name, idx + 1, val]
	GameState.use_consumable(_active_item_id)
	_exit_peek_mode()

## borrow_die: copy opponent die value to player's die
func _on_borrow_die(idx: int) -> void:
	if _peek_phase != "position": return
	if not game_ctrl.borrow_visible_die(_peek_opponent, idx):
		if status_label: status_label.text = "该骰子不可见，请选择可见骰子"
		return
	_update_dice_display()
	GameState.use_consumable(_active_item_id)
	game_ctrl.mirror_item("borrow_die")
	_exit_peek_mode()

func _on_peek_cancel() -> void:
	# Item was never consumed — just exit peek mode
	_exit_peek_mode()

func _exit_peek_mode() -> void:
	_selecting_mode = false
	_selection_mode_type = ""
	_active_item_id = ""
	_peek_phase = ""
	_peek_opponent = ""
	if _peek_btn1: _peek_btn1.queue_free(); _peek_btn1 = null
	if _peek_btn2: _peek_btn2.queue_free(); _peek_btn2 = null
	if _peek_btn3: _peek_btn3.queue_free(); _peek_btn3 = null
	if _select_cancel_btn: _select_cancel_btn.queue_free(); _select_cancel_btn = null
	_update_dice_display()
	_refresh_item_display()
	_item_locked = false

func _rebuild_consumable_section() -> void:
	# Minimal: just refresh item display
	# For now, full rebuild is safest
	# (items slot data is re-read from GameState each _build_all_ui call)
	_update_dice_display()

## Boss skill effect — display in notify area
func _on_boss_skill_effect(effect: String, detail: String) -> void:
	if _notify_label:
		_notify_label.text = "[Boss] " + detail
	_log_event("[Boss] " + detail)
	if effect == "swap":
		_update_dice_display()

## 显示卡牌技能触发的提示
func _on_card_skill_triggered(card_id: String, skill_name: String, target: String) -> void:
	if not _notify_label: return
	if GameState.mark_tutorial_topic("enemy_skill"):
		EventBus.tutorial_hint_show.emit("卡牌技能会改变基础规则。点击对手卡牌可以再次查看技能说明。", 7.0)
	var card_display: String = card_id
	match card_id:
		"jack_crt": card_display = "瘸腿老杰克"
		"rust_warrior": card_display = "锈铁战士"
		"battery_kid": card_display = "电池小子"
		"signal_noise": card_display = "信号噪音"
		"chamberlain": card_display = "侍从长"
		"recycler": card_display = "回收商"
		"mirror_tech": card_display = "镜面技师"
		"casino_owner": card_display = "赌场主"
		"prophet": card_display = "算法先知"
		"abyss": card_display = "深渊"
	_notify_label.text = "[%s] %s → %s" % [card_display, skill_name, target]
	_hint_history.append(_notify_label.text)

## 显示通用提示（来自 EventBus.hint_show）
func _on_hint_show(message: String, duration: float, color: Color) -> void:
	if not _notify_label: return
	_notify_label.text = message
	_notify_label.add_theme_color_override("default_color", color)
	_hint_history.append(message)
	_history_index = _hint_history.size() - 1

func _on_tutorial_hint_show(message: String, duration: float) -> void:
	if not _tutorial_bar or not _tutorial_label: return
	if message not in _tutorial_history:
		_tutorial_history.append(message)
	_refresh_tutorial_review()
	if _tutorial_tween and _tutorial_tween.is_valid():
		_tutorial_tween.kill()
	_tutorial_bar.modulate.a = 1.0
	_tutorial_bar.visible = true
	_tutorial_label.text = message
	if message.begins_with("先看自己的骰子"):
		_set_tutorial_focus("dice")
	elif message.begins_with("很好"):
		_set_tutorial_focus("observe")
	elif message.begins_with("质疑成功"):
		_set_tutorial_focus("")
	_tutorial_tween = create_tween()
	_tutorial_tween.tween_interval(duration)
	_tutorial_tween.tween_property(_tutorial_bar, "modulate:a", 0.0, 0.35)
	_tutorial_tween.tween_callback(func(): _tutorial_bar.visible = false)

func _set_tutorial_focus(mode: String) -> void:
	for node in _tutorial_focus_nodes:
		if is_instance_valid(node): node.modulate = Color.WHITE
	_tutorial_focus_nodes.clear()
	match mode:
		"dice":
			for box in _die_boxes:
				if box.visible: _tutorial_focus_nodes.append(box)
		"bid":
			_tutorial_focus_nodes.append_array([_btn_count_minus, _btn_count_plus, _btn_value_minus, _btn_value_plus, _btn_bid])
		"challenge":
			_tutorial_focus_nodes.append(_btn_challenge)
		"observe":
			pass
	for node in _tutorial_focus_nodes:
		if is_instance_valid(node): node.modulate = Color(1.0, 0.9, 0.48, 1.0)

func _build_tutorial_review_panel() -> void:
	_tutorial_review_panel = ColorRect.new()
	_tutorial_review_panel.name = "TutorialReviewPanel"
	_tutorial_review_panel.position = Vector2(170, 80)
	_tutorial_review_panel.size = Vector2(940, 560)
	_tutorial_review_panel.color = Color(0.025, 0.045, 0.055, 0.98)
	_tutorial_review_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_tutorial_review_panel.z_index = 350
	_tutorial_review_panel.visible = false
	add_child(_tutorial_review_panel)
	_add_border(_tutorial_review_panel, 940, 560, Color(0.36, 0.79, 0.65), 3)
	var title := Label.new()
	title.text = "教程回顾"
	title.position = Vector2(30, 20)
	title.size = Vector2(880, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color(0.78, 1.0, 0.9))
	_tutorial_review_panel.add_child(title)
	_tutorial_review_text = RichTextLabel.new()
	_tutorial_review_text.bbcode_enabled = true
	_tutorial_review_text.position = Vector2(60, 82)
	_tutorial_review_text.size = Vector2(820, 390)
	_tutorial_review_text.add_theme_font_size_override("normal_font_size", 16)
	_tutorial_review_text.add_theme_color_override("default_color", Color(0.86, 0.9, 0.9))
	_tutorial_review_panel.add_child(_tutorial_review_text)
	var close := Button.new()
	close.text = "关闭并继续"
	close.position = Vector2(350, 492)
	close.size = Vector2(240, 44)
	close.pressed.connect(_toggle_tutorial_review)
	_tutorial_review_panel.add_child(close)
	_refresh_tutorial_review()

func _refresh_tutorial_review() -> void:
	if not _tutorial_review_text: return
	var text: String = "[b]基础规则[/b]\n①可以代替其他点数；有人叫①后，本轮①不再万能。\n每轮最低起叫为存活人数＋1。后续必须增加数量，或数量相同提高点数。\n质疑成功：被质疑者失败；质疑失败：质疑者失败。\n"
	if _tutorial_history.is_empty():
		text += "\n[b]本场教学记录[/b]\n尚未出现新的教学提示。"
	else:
		text += "\n[b]本场教学记录[/b]\n"
		for i in range(_tutorial_history.size()):
			text += "%d. %s\n" % [i + 1, _tutorial_history[i]]
	_tutorial_review_text.text = text

func _toggle_tutorial_review() -> void:
	if not _tutorial_review_panel: return
	_refresh_tutorial_review()
	_tutorial_review_panel.visible = not _tutorial_review_panel.visible

func _on_hint_clicked(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed): return
	if _hint_history.is_empty(): return
	_show_history_overlay()

func _show_opponent_skill(ai_idx: int) -> void:
	if not game_ctrl: return
	var card: Resource = game_ctrl.get_ai_card(ai_idx)
	if not card: return
	# Remove old skill popup
	for child in get_children():
		if child is Control and child.name == "SkillPopup":
			child.queue_free(); break
	var popup := Control.new()
	popup.name = "SkillPopup"
	popup.position = Vector2(350, 160)
	popup.size = Vector2(580, 200)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.position = Vector2(0, 0); bg.size = Vector2(580, 200)
	bg.color = Color(0.04, 0.04, 0.08, 0.95)
	popup.add_child(bg)
	var acc: Color = card.get_rarity_color()
	var nm := Label.new()
	nm.text = card.card_name; nm.position = Vector2(16, 12)
	nm.size = Vector2(548, 28); nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.add_theme_font_size_override("font_size", 16)
	nm.add_theme_color_override("font_color", acc)
	popup.add_child(nm)
	var sk := Label.new()
	sk.text = "技能：「%s」" % card.skill_name; sk.position = Vector2(16, 52)
	sk.size = Vector2(548, 24); sk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sk.add_theme_font_size_override("font_size", 14)
	sk.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	popup.add_child(sk)
	var sd := Label.new()
	sd.text = card.skill_desc; sd.position = Vector2(16, 90)
	sd.size = Vector2(548, 66); sd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sd.add_theme_font_size_override("font_size", 13)
	sd.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8))
	popup.add_child(sd)
	var close := Button.new()
	close.text = "关闭"; close.position = Vector2(210, 164); close.size = Vector2(160, 30)
	close.add_theme_font_size_override("font_size", 12)
	close.pressed.connect(func(): popup.queue_free())
	popup.add_child(close)
	add_child(popup)

func _show_history_overlay() -> void:
	for child in get_children():
		if child is Control and child.name == "HistoryOverlay":
			child.queue_free(); return

	var wrapper := Control.new()
	wrapper.name = "HistoryOverlay"
	wrapper.position = Vector2.ZERO
	wrapper.size = Vector2(1280, 720)

	var dim := ColorRect.new()
	dim.anchor_right = 1.0; dim.anchor_bottom = 1.0
	dim.color = Color(0, 0, 0, 0.4)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: wrapper.queue_free()
	)
	wrapper.add_child(dim)

	var overlay := Control.new()
	overlay.position = Vector2(120, 60)  # History
	overlay.size = Vector2(1040, 600)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var obg := ColorRect.new()
	obg.position = Vector2(0, 0); obg.size = Vector2(1040, 600)
	obg.color = Color(0.04, 0.04, 0.06, 0.95)
	overlay.add_child(obg)
	var title := Label.new()
	title.text = "—— 对局日志 ——"; title.position = Vector2(0, 8)
	title.size = Vector2(1040, 24); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	overlay.add_child(title)
	var list := RichTextLabel.new()
	list.position = Vector2(16, 40); list.size = Vector2(1008, 500)
	list.bbcode_enabled = true
	list.scroll_following = true
	list.add_theme_font_size_override("normal_font_size", 12)
	list.add_theme_color_override("default_color", Color(0.75, 0.8, 0.9))
	var text: String = ""
	for i in range(_hint_history.size()):
		text += "[%d] %s\n" % [i + 1, _hint_history[i]]
	list.text = text
	overlay.add_child(list)
	var close := Button.new()
	close.text = "关闭"; close.position = Vector2(440, 552); close.size = Vector2(160, 36)
	close.add_theme_font_size_override("font_size", 13)
	close.pressed.connect(func(): wrapper.queue_free())
	overlay.add_child(close)
	wrapper.add_child(overlay)
	add_child(wrapper)

func _refresh_virus(_target: String = "") -> void:
	var cnt: int = game_ctrl.player_virus if game_ctrl else 0
	var dead: Color = Color(0.85, 0.18, 0.18)
	var dark: Color = Color(0.06, 0.06, 0.06)
	for i in range(2):
		for child in get_children():
			if child is ColorRect and child.name == "VirusSquare" + str(i):
				child.color = dead if cnt >= i + 1 else dark
				break

func _on_half_assimilated() -> void:
	_refresh_virus()
	call_deferred("_show_assimilation_choice")

func _show_assimilation_choice() -> void:
	if GameState.assimilation_count != 1 or not GameState.assimilation_curse.is_empty(): return
	if GameState.mark_tutorial_topic("assimilation_choice"):
		EventBus.tutorial_hint_show.emit("半同化不会立即结束本盘。选择一项带有代价的诅咒能力，它会持续到净化。", 8.0)
	if find_child("AssimilationChoiceOverlay", false, false): return
	var overlay := ColorRect.new()
	overlay.name = "AssimilationChoiceOverlay"
	overlay.position = Vector2.ZERO; overlay.size = Vector2(1280, 720)
	overlay.color = Color(0.08, 0.01, 0.08, 0.96)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 600
	add_child(overlay)
	var title := Label.new()
	title.text = "半同化：选择一种诅咒能力"
	title.position = Vector2(260, 80); title.size = Vector2(760, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.85, 0.45, 0.95))
	overlay.add_child(title)
	var choices: Array[Dictionary] = [
		{"id": "double_wild", "name": "双重万能", "desc": "③也可作万能骰，但你不能叫①或③"},
		{"id": "growth_cost", "name": "增殖代价", "desc": "每轮+1骰；随机一颗①变为②～⑥"},
		{"id": "devour_challenge", "name": "吞噬质疑", "desc": "质疑成功吞1骰；质疑失败立即完全同化"},
	]
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var button := Button.new()
		button.text = "%s\n%s" % [choice.name, choice.desc]
		button.position = Vector2(155 + i * 335, 250); button.size = Vector2(300, 130)
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(func(curse_id: String = choice.id):
			if GameState.choose_assimilation_curse(curse_id):
				EventBus.hint_show.emit("半同化能力已选择：%s" % choice.name, 4.0, Color(0.85, 0.45, 0.95))
			overlay.queue_free())
		overlay.add_child(button)

func set_infection_notice(virus_count: int) -> void:
	if status_label:
		if virus_count < 2:
			status_label.text = "你被感染了! (剩余 %d 次机会)" % (2 - virus_count)
		else:
			status_label.text = "你死机了... 蓝屏"
	_refresh_virus()

func _show_actions(v: bool) -> void:
	if _btn_bid:
		_btn_bid.visible = v
	if not game_ctrl:
		return
	if _btn_challenge:
		_btn_challenge.visible = v and game_ctrl.current_bid_count > 0 and game_ctrl.last_bidder != "player"

func _update_dice_display() -> void:
	if not game_ctrl:
		return
	# Peek position phase: show AI dice positions as "?"
	if _peek_phase == "position" and _peek_opponent != "":
		var ai_idx: int = int(_peek_opponent.trim_prefix("ai")) - 1
		var ai_count: int = game_ctrl.get_ai_dice_values(ai_idx).size()
		for i: int in range(_die_labels.size()):
			var lbl: Label = _die_labels[i] as Label
			if not lbl: continue
			var box: Node = lbl.get_parent()
			if i < ai_count:
				if box: box.visible = true
				lbl.text = "?"
				lbl.add_theme_color_override("font_color", Color(0.36, 0.79, 0.65))
				if box: (box as ColorRect).color = Color(0.36, 0.79, 0.65)
			else:
				if box: box.visible = false
		return
	var values: Array = game_ctrl.player_cup.get_values()
	var total: int = values.size()
	for i: int in range(_die_labels.size()):
		var lbl: Label = _die_labels[i] as Label
		if not lbl: continue
		# Show/hide based on actual dice count
		var box: Node = lbl.get_parent()
		var val: int = -1  # default for hidden dice
		if i < total:
			if box: box.visible = true
			val = values[i]
			lbl.text = str(val) if val >= 1 else "?"

			if box: (box as ColorRect).color = Color(1, 1, 1)  # reset before overrides
			if val == 1:
				lbl.add_theme_color_override("font_color", Color(0.33, 0.29, 0.72))
			elif val == -1:
				lbl.add_theme_color_override("font_color", Color(0.36, 0.79, 0.65))
				lbl.text = "?"
			else:
				lbl.add_theme_color_override("font_color", Color(0.17, 0.17, 0.17))
		else:
			if box: box.visible = false
		# Selection highlight
		if _selecting_mode and i < _selected_dice.size():
			if _selection_mode_type == "split_die":
				if box: (box as ColorRect).color = Color(0.36, 0.79, 0.65) if (val >= 4) else Color(0.5, 0.15, 0.15)
				if lbl: lbl.modulate = Color(1, 1, 1) if (val >= 4) else Color(0.5, 0.5, 0.5)
			elif _selection_mode_type == "clone_die":
				# Only paired dice are highlighted green (clickable), rest grey-red
				var paired: Array[int] = game_ctrl.get_player_paired_dice()
				if box: (box as ColorRect).color = Color(0.36, 0.79, 0.65) if (i in paired) else Color(0.5, 0.15, 0.15)
				if lbl: lbl.modulate = Color(1, 1, 1) if (i in paired) else Color(0.5, 0.5, 0.5)
			elif _selection_mode_type == "freeze_die":
				# Any die can be selected — all green
				if box: (box as ColorRect).color = Color(0.36, 0.79, 0.65)
			else:
				if box: (box as ColorRect).color = Color(0.36, 0.79, 0.65) if _selected_dice[i] else Color(1, 1, 1)


## Right-click: single click = history, 2s hold = rules
var _right_held: bool = false
var _right_hold_timer: float = 0.0

func _process(delta: float) -> void:
	if _right_held:
		_right_hold_timer += delta
		if _right_hold_timer >= 2.0:
			_right_held = false
			_right_hold_timer = 0.0
			_show_rules_panel()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_right_held = true
			_right_hold_timer = 0.0
		else:
			if _right_held and _right_hold_timer < 2.0:
				_show_history_overlay()
			_right_held = false
			_right_hold_timer = 0.0

func _show_rules_panel() -> void:
	for child in get_children():
		if child is Control and child.name == "RulesPanel":
			child.queue_free()
			return

	var wrapper := Control.new()
	wrapper.name = "RulesPanel"
	wrapper.position = Vector2.ZERO
	wrapper.size = Vector2(1280, 720)

	var dim := ColorRect.new()
	dim.anchor_right = 1.0; dim.anchor_bottom = 1.0
	dim.color = Color(0, 0, 0, 0.4)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: wrapper.queue_free()
	)
	wrapper.add_child(dim)

	var panel := ColorRect.new()
	panel.position = Vector2(240, 60)  # Rules
	panel.size = Vector2(800, 600)
	panel.color = Color(0.05, 0.05, 0.08, 0.95)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	wrapper.add_child(panel)

	var rules: Array[String] = [
		"===== 大话骰规则 =====",
		"（长按右键2秒打开/关闭此提示栏。单击右键查看技能历史。）",
		"",
		"叫牌：选择 [数量] 个 [点数]，叫出你认为全桌加起来至少有的数量。",
		"  例: 叫 4个3 表示全桌至少有 4 颗点数为 3 的骰子。",
		"",
		"加注：必须比上家 [数量] 大，或 [数量] 相同但 [点数] 更高。",
		"  例: 上家叫 3个4，你可以叫 4个3 或 3个5。",
		"",
		"质疑：觉得上家叫错了？点击 [质疑] 开牌定胜负。",
		"  叫牌正确=质疑者感染。叫牌错误=叫牌者感染。",
		"",
		"① 是万能骰：① 可作为任意点数匹配，直到有人叫过 ①。",
		"",
		"道具：左侧道具栏可在自己回合点击使用。",
		"",
		"对手技能：每个对手卡牌上有特殊技能描述。",
	]
	var y := 16.0
	for line in rules:
		var l := Label.new()
		l.text = line
		l.position = Vector2(24, y); l.size = Vector2(752, 22)
		l.add_theme_font_size_override("font_size", 13 if line.begins_with("  ") else 14)
		var is_header: bool = line.begins_with("====")
		l.add_theme_color_override("font_color", Color(0.91, 0.773, 0.416) if is_header else Color(0.75, 0.75, 0.78))
		panel.add_child(l)
		y += 22
	add_child(wrapper)

## Three-phase dice animation: shake → scatter → gather → reveal
func _play_dice_animation() -> void:
	if _die_boxes.size() == 0 or _die_target_positions.size() == 0 or _anim_playing:
		return
	_anim_playing = true
	var active_boxes: Array[ColorRect] = []
	var active_targets: Array[Vector2] = []
	for i: int in range(5):
		if i < _die_boxes.size():
			active_boxes.append(_die_boxes[i])
			active_targets.append(_die_target_positions[i])
	if active_boxes.size() == 0:
		return

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# Hide values during animation
	for b: ColorRect in active_boxes:
		b.visible = true
		if b.get_child_count() > 0:
			var lbl := b.get_child(0) as Label
			if lbl:
				lbl.text = "?"
				lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

	# Phase 1: Shake (0.25s) — vibrate each die in place
	var last_shake_tween: Tween = null
	for b: ColorRect in active_boxes:
		var orig := b.position
		var bt := create_tween()
		last_shake_tween = bt
		for _s: int in range(6):
			var sx: float = orig.x + rng.randf_range(-8.0, 8.0)
			var sy: float = orig.y + rng.randf_range(-5.0, 5.0)
			bt.tween_property(b, "position", Vector2(sx, sy), 0.035)
		bt.tween_property(b, "position", orig, 0.04)
	if last_shake_tween:
		await last_shake_tween.finished

	# Brief pause
	await get_tree().create_timer(0.05).timeout

	# Phase 2: Scatter (0.2s) — fly to random positions in dice area
	var scatter_tween := create_tween()
	scatter_tween.set_parallel(true)
	var scatter_positions: Array[Vector2] = []
	for b: ColorRect in active_boxes:
		var sx: float = b.position.x + rng.randf_range(-80.0, 80.0)
		var sy: float = b.position.y + rng.randf_range(-25.0, 25.0)
		scatter_positions.append(Vector2(sx, sy))
		scatter_tween.tween_property(b, "position", Vector2(sx, sy), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await scatter_tween.finished

	# Brief pause at scattered positions
	await get_tree().create_timer(0.08).timeout

	# Phase 3: Gather (0.45s) — fly to final row + reveal values
	var gather_tween := create_tween()
	gather_tween.set_parallel(true)
	for _k: int in range(active_boxes.size()):
		gather_tween.tween_property(active_boxes[_k], "position", active_targets[_k], 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await gather_tween.finished

	# Reveal
	_update_dice_display()
	_anim_playing = false


## 赌徒直觉: find the most common value across all cups
func _get_most_common_value() -> int:
	if not game_ctrl: return 1
	var best_val: int = 1
	var best_cnt: int = 0
	for v in range(1, 7):
		var cnt: int = 0
		var p_vals: Array = game_ctrl.player_cup.get_values()
		for val in p_vals:
			if val >= 1 and val == v: cnt += 1
		if game_ctrl.ai1_virus < game_ctrl.AI_MAX_VIRUS:
			for val in game_ctrl.ai_cup_1.get_values():
				if val >= 1 and val == v: cnt += 1
		if game_ctrl.ai2_virus < game_ctrl.AI_MAX_VIRUS:
			for val in game_ctrl.ai_cup_2.get_values():
				if val >= 1 and val == v: cnt += 1
		if game_ctrl.ai3_virus < game_ctrl.AI_MAX_VIRUS:
			for val in game_ctrl.ai_cup_3.get_values():
				if val >= 1 and val == v: cnt += 1
		if cnt > best_cnt:
			best_cnt = cnt; best_val = v
	return best_val

func _on_discard_prompt(new_item_id: String) -> void:
	var items: Array[String] = GameState.consumable_items.duplicate()
	if items.size() == 0: return
	var wrapper := Control.new()
	wrapper.name = "DiscardWrapper"
	wrapper.position = Vector2.ZERO; wrapper.size = Vector2(1280, 720)
	add_child(wrapper)
	var dim := ColorRect.new()
	dim.anchor_right = 1.0; dim.anchor_bottom = 1.0
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(dim)
	var popup := Control.new()
	popup.name = "DiscardPopup"
	popup.position = Vector2(200, 160)
	popup.size = Vector2(880, 400)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.position = Vector2(0, 0); bg.size = popup.size
	bg.color = Color(0.04, 0.04, 0.08, 0.95)
	popup.add_child(bg)
	var info := ItemData.get_by_id(new_item_id)
	var title := Label.new()
	title.text = "道具栏满 (6/6) — 获得「%s」· 选一个替换" % (info.item_name if info else new_item_id)
	title.position = Vector2(0, 8)
	title.size = Vector2(880, 28); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	popup.add_child(title)
	for i in range(items.size()):
		var item_info: ItemData = GameState.get_item_info(items[i])
		var btn := Button.new()
		btn.text = "替换 %s" % (item_info.item_name if item_info else items[i])
		btn.position = Vector2(60, 50 + i * 38)
		btn.size = Vector2(760, 32)
		btn.add_theme_font_size_override("font_size", 12)
		var idx: int = i
		btn.pressed.connect(func():
			GameState.force_swap_consumable(new_item_id, idx)
			wrapper.queue_free()
			EventBus.discard_resolved.emit())
		popup.add_child(btn)
	var cancel := Button.new()
	cancel.text = "放弃新道具"; cancel.position = Vector2(360, 360)
	cancel.size = Vector2(160, 30)
	cancel.add_theme_font_size_override("font_size", 12)
	cancel.pressed.connect(func():
		wrapper.queue_free()
		EventBus.discard_resolved.emit())
	popup.add_child(cancel)
	wrapper.add_child(popup)

## Check for new unlocks earned this run. If any, show popup first, then call [code]on_done[/code].
func _check_and_show_unlocks(on_done: Callable) -> void:
	var unlocks: Dictionary = GameState.pop_new_unlocks()
	if unlocks.is_empty():
		on_done.call()
		return
	_show_unlock_popup(unlocks, on_done)

func _show_unlock_popup(unlocks: Dictionary, on_done: Callable) -> void:
	var overlay := Control.new()
	overlay.name = "UnlockPopup"
	overlay.position = Vector2(0, 0)
	overlay.size = Vector2(1280, 720)
	add_child(overlay)

	var dim := ColorRect.new()
	dim.anchor_right = 1.0; dim.anchor_bottom = 1.0
	dim.color = Color(0.02, 0.02, 0.06, 0.92)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	var title := Label.new()
	title.text = "解锁新奖励!"
	title.position = Vector2(290, 50); title.size = Vector2(700, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.98, 0.78, 0.29))
	overlay.add_child(title)

	var note := Label.new()
	note.text = "新奖励已加入卡池/道具池 · 下局生效"
	note.position = Vector2(290, 96); note.size = Vector2(700, 24)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color(0.5, 0.7, 0.95))
	overlay.add_child(note)

	var y: float = 130.0
	var sorted: Array = unlocks.keys()
	sorted.sort()
	for lv in sorted:
		var names: Array = unlocks[lv]
		# Level header
		var lh := Label.new()
		lh.text = "—— Lv.%d ——" % lv
		lh.position = Vector2(290, y); lh.size = Vector2(700, 26)
		lh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lh.add_theme_font_size_override("font_size", 16)
		lh.add_theme_color_override("font_color", Color(0.5, 0.7, 0.98))
		overlay.add_child(lh)
		y += 32
		# Item/card names
		for nm: String in names:
			var nl := Label.new()
			nl.text = "  " + nm
			nl.position = Vector2(340, y); nl.size = Vector2(600, 22)
			nl.add_theme_font_size_override("font_size", 15)
			nl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
			overlay.add_child(nl)
			y += 26
		y += 10

	# XP bar
	var xp_bar := ColorRect.new()
	xp_bar.position = Vector2(290, y); xp_bar.size = Vector2(700, 12)
	xp_bar.color = Color(0.08, 0.08, 0.14)
	overlay.add_child(xp_bar)
	var pct: float = clampf(float(GameState.player_xp) / GameState.xp_for_next_level(), 0.0, 1.0)
	var filled := ColorRect.new()
	filled.position = Vector2(290, y); filled.size = Vector2(700 * pct, 12)
	filled.color = Color(0.35, 0.6, 0.8)
	overlay.add_child(filled)
	var xp_text := Label.new()
	xp_text.text = "Lv.%d  %d / %d XP" % [GameState.player_level, GameState.player_xp, GameState.xp_for_next_level()]
	xp_text.position = Vector2(290, y + 16); xp_text.size = Vector2(700, 20)
	xp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_text.add_theme_font_size_override("font_size", 11)
	xp_text.add_theme_color_override("font_color", Color(0.4, 0.5, 0.6))
	overlay.add_child(xp_text)
	y += 52

	var btn := Button.new()
	btn.text = "确认"
	btn.position = Vector2(490, y); btn.size = Vector2(300, 44)
	btn.flat = true
	var bs := StyleBoxFlat.new(); bs.bg_color = Color(0.15, 0.22, 0.15)
	btn.add_theme_stylebox_override("normal", bs)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	btn.pressed.connect(func():
		overlay.queue_free()
		on_done.call()
	)
	overlay.add_child(btn)
