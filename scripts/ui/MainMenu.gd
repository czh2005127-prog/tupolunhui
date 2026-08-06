## Main menu — narrative terminal with card-style dice buttons.
extends Control

const CARD_W := 150
const CARD_H := 200
const CARD_GAP := 48
const DICE_SIZE := 70
const LEFT_X := 72
const CANVAS_W := 1280
const CANVAS_H := 720

var _continue_enabled: bool = false

# ----- Color tokens -----
const COL_BG       := Color(0.0235, 0.0235, 0.0627)
const COL_GOLD     := Color(0.91, 0.773, 0.416)
const COL_GOLD_DIM := Color(0.353, 0.333, 0.251)
const COL_BLUE     := Color(0.408, 0.690, 0.784)
const COL_ORANGE   := Color(0.816, 0.565, 0.376)
const COL_PURPLE   := Color(0.565, 0.533, 0.690)
const COL_CARD_BG  := Color(0.0392, 0.0392, 0.0941)
const COL_CARD_BG2 := Color(0.0549, 0.0549, 0.0941)
const COL_BORDER   := Color(0.1255, 0.1255, 0.2196)
const COL_STATS    := Color(0.1255, 0.1255, 0.2196)
const COL_NARR     := Color(0.251, 0.376, 0.471)
const COL_NARR_DIM := Color(0.251, 0.314, 0.376)

func _ready() -> void:
	GameState.load_progress()
	_continue_enabled = GameState.has_saved_game()
	_build()

func _build() -> void:
	for child: Node in get_children():
		child.queue_free()
	await get_tree().process_frame

	# Full-screen dark bg
	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.anchor_right = 1.0; bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Title — centered at top
	var title := _label("突破轮回", Vector2(0, 60), 52, COL_GOLD)
	title.size = Vector2(CANVAS_W, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	# Four cards centered on canvas midline
	var total_w: int = 4 * CARD_W + 3 * CARD_GAP
	var card_start_x: int = (CANVAS_W - total_w) / 2
	var card_y: int = (CANVAS_H - CARD_H) / 2

	var cards: Array[Dictionary] = [
		{
			"dice": "1", "label": "发起挑战", "sub": "Enter 轮回",
			"accent": COL_GOLD, "cb": _on_new_game, "enabled": true,
		},
		{
			"dice": "2", "label": "继续进修", "sub": "读档续行",
			"accent": COL_BLUE, "cb": _on_continue, "enabled": _continue_enabled,
		},
		{
			"dice": "3", "label": "锈蚀工坊", "sub": "升级卡牌",
			"accent": COL_ORANGE, "cb": _on_rust_workshop,
			"enabled": not _continue_enabled,
		},
		{
			"dice": "4", "label": "设置", "sub": "教程 音效 存档",
			"accent": COL_PURPLE, "cb": _on_settings, "enabled": true,
		},
	]

	for i in range(cards.size()):
		var cd: Dictionary = cards[i]
		var cx: int = card_start_x + i * (CARD_W + CARD_GAP)
		_build_card(cx, card_y, cd)
	if GameState.has_cleared_game:
		var forbidden := Button.new()
		forbidden.text = "禁忌规则 · 已启用%d条" % GameState.selected_forbidden_rules.size()
		forbidden.position = Vector2(500, card_y + CARD_H + 28); forbidden.size = Vector2(280, 42)
		forbidden.pressed.connect(_open_forbidden_rules)
		add_child(forbidden)

func _build_card(x: float, y: float, data: Dictionary) -> void:
	var enabled: bool = data.get("enabled", true)
	var accent: Color = data["accent"]
	var dice: String = data["dice"]
	var label_text: String = data["label"]
	var sub_text: String = data["sub"]

	# Card bg
	var card_bg := ColorRect.new()
	card_bg.position = Vector2(x, y)
	card_bg.size = Vector2(CARD_W, CARD_H)
	card_bg.color = COL_CARD_BG2 if enabled else COL_CARD_BG
	card_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(card_bg)

	# Card border (accent for primary, muted for others)
	var border_alpha: float = 1.0 if dice == "1" else 0.6
	var bcol: Color = accent if enabled else Color(0.08, 0.08, 0.14)
	bcol.a = border_alpha
	var border_style := StyleBoxFlat.new()
	border_style.border_color = bcol
	border_style.border_width_left = 1; border_style.border_width_right = 1
	border_style.border_width_top = 1; border_style.border_width_bottom = 1
	border_style.corner_radius_top_left = 10; border_style.corner_radius_top_right = 10
	border_style.corner_radius_bottom_right = 10; border_style.corner_radius_bottom_left = 10
	card_bg.add_theme_stylebox_override("panel", border_style)

	if enabled:
		card_bg.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				data["cb"].call()
		)

		# Hover feedback
		card_bg.mouse_entered.connect(func():
			card_bg.color = accent.darkened(0.7)
		)
		card_bg.mouse_exited.connect(func():
			card_bg.color = COL_CARD_BG2
		)

	# Dice avatar
	var dice_bg := ColorRect.new()
	var dice_cx: float = x + (CARD_W - DICE_SIZE) / 2.0
	dice_bg.position = Vector2(dice_cx, y + 22)
	dice_bg.size = Vector2(DICE_SIZE, DICE_SIZE)
	dice_bg.color = accent.darkened(0.8)
	dice_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dice_bg)

	var dice_style := StyleBoxFlat.new()
	dice_style.border_color = accent if enabled else Color(0.15, 0.15, 0.2)
	dice_style.border_width_left = 1; dice_style.border_width_right = 1
	dice_style.border_width_top = 1; dice_style.border_width_bottom = 1
	dice_style.corner_radius_top_left = 10; dice_style.corner_radius_top_right = 10
	dice_style.corner_radius_bottom_right = 10; dice_style.corner_radius_bottom_left = 10
	dice_bg.add_theme_stylebox_override("panel", dice_style)

	var dice_lbl := _label("", Vector2(dice_cx, y + 22), 32,
		accent if enabled else Color(0.25, 0.25, 0.35))
	dice_lbl.size = Vector2(DICE_SIZE, DICE_SIZE)
	dice_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dice_lbl.text = dice_emoji(dice)
	add_child(dice_lbl)

	# Card label
	var lbl := _label(label_text, Vector2(x, y + 110), 15,
		accent if (enabled and dice == "1") else (Color(0.416, 0.416, 0.478) if enabled else Color(0.25, 0.25, 0.35)))
	lbl.size = Vector2(CARD_W, 22)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lbl)

	# Subtitle
	var sl := _label(sub_text, Vector2(x, y + 138), 11,
		COL_GOLD_DIM if dice == "1" else Color(0.188, 0.188, 0.251))
	sl.size = Vector2(CARD_W, 18)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sl)

static func dice_emoji(d: String) -> String:
	match d:
		"1": return "\u2460"
		"2": return "\u2461"
		"3": return "\u2462"
		"4": return "\u2463"
		"5": return "\u2464"
		"6": return "\u2465"
	return d

func _label(t: String, p: Vector2, fs: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t; l.position = p
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	return l

# ----- Navigation -----

func _on_new_game() -> void:
	GameState.setup_new_run()
	get_tree().change_scene_to_file("res://scenes/gameflow/RunManager.tscn")

func _on_continue() -> void:
	if not GameState.has_saved_game(): return
	GameState.load_run()
	get_tree().change_scene_to_file("res://scenes/gameflow/RunManager.tscn")

func _on_rust_workshop() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/RustWorkshop.tscn")

func _on_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/Settings.tscn")

func _open_forbidden_rules() -> void:
	var layer := CanvasLayer.new(); layer.layer = 100; add_child(layer)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.88); dim.position = Vector2.ZERO; dim.size = Vector2(CANVAS_W, CANVAS_H); layer.add_child(dim)
	var panel := ColorRect.new(); panel.position = Vector2(150, 55); panel.size = Vector2(980, 610); panel.color = Color(0.04, 0.035, 0.065); layer.add_child(panel)
	var title := _label("禁忌规则　最多选择%d条" % GameState.forbidden_slot_limit, Vector2(0, 18), 28, COL_GOLD); title.size = Vector2(980, 45); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; panel.add_child(title)
	var definitions: Array[Dictionary] = [
		{"id":"greedy_box", "name":"贪婪木盒", "desc":"初始金币+20；商店价格+20%"},
		{"id":"narrow_hand", "name":"狭窄大手", "desc":"每轮补至7张；手牌上限8"},
		{"id":"rush_clock", "name":"急行时钟", "desc":"每轮第一张牌不推进；新轮敌方倒计时-2"},
		{"id":"twin_throw", "name":"双生投掷", "desc":"每场+1骰；随机1骰本轮不能修改"},
		{"id":"overload_circuit", "name":"过载回路", "desc":"第3张普通/稀有牌结算两次；敌方额外推进"},
		{"id":"broken_cycle", "name":"残缺轮回", "desc":"每轮可保留2张；基础补牌降为5"},
		{"id":"closed_prophecy", "name":"封闭预言", "desc":"敌方初始倒计时+2；隐藏后续意图"},
		{"id":"forbidden_face", "name":"禁忌骰面", "desc":"⑥每颗基础点数+2；卡牌不能直接改成⑥"},
	]
	for i in range(definitions.size()):
		var definition: Dictionary = definitions[i]
		var check := CheckButton.new(); check.text = "%s\n%s" % [definition.name, definition.desc]; check.position = Vector2(55 + (i % 2) * 470, 85 + (i / 2) * 105); check.size = Vector2(420, 78); check.button_pressed = definition.id in GameState.selected_forbidden_rules
		check.toggled.connect(func(enabled: bool, rule_id: String = definition.id, button: CheckButton = check):
			if enabled and rule_id not in GameState.selected_forbidden_rules:
				if GameState.selected_forbidden_rules.size() >= GameState.forbidden_slot_limit:
					button.set_pressed_no_signal(false)
					return
				GameState.selected_forbidden_rules.append(rule_id)
			elif not enabled: GameState.selected_forbidden_rules.erase(rule_id)
			GameState.save_progress())
		panel.add_child(check)
	var close := Button.new(); close.text = "确认"; close.position = Vector2(390, 535); close.size = Vector2(200, 48); close.pressed.connect(func(): layer.queue_free(); _build()); panel.add_child(close)
