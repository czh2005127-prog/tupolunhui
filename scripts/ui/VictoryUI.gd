## Victory / game-over screen — narrative sequence then stats.
extends Control

const NARRATIVE: Array[String] = [
	"骰子之神的全息屏幕碎成了乱码。",
	"他的骰子落在地上，弹了最后一下——然后停在了 1。",
	"赌场里的每一条走廊、每一台机器、每一个屏幕脸——同时停了。",
	"它们抬起头，看向你。",
	"旧王的算力正在瓦解。数据流从塔楼顶端倾泻而下，像一场无声的暴雨。",
	"一个孩子机器人在角落里举起了一块废铁牌——上面歪歪扭扭刻着：\n「新国王。」",
	"你捡起了骰子之神的骰子。\n它在你手心里安静地亮着——不是任何数字，只是一个光标。\n等你输入。",
]

func _ready() -> void:
	if not GameState.has_cleared_game:
		GameState.has_cleared_game = true
		GameState.save_progress()
	await _play_narrative()

func _play_narrative() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0, 0, 0, 1)
	bg.anchors_preset = PRESET_FULL_RECT
	bg.name = "NarrativeOverlay"
	bg.z_index = 300
	add_child(bg)

	var lbl: Label = Label.new()
	lbl.position = Vector2(80, 260)
	lbl.size = Vector2(1120, 240)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75, 1))
	bg.add_child(lbl)

	var hint: Label = Label.new()
	hint.text = "—— 点击跳过 ——"
	hint.position = Vector2(0, 580)
	hint.size = Vector2(1280, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5, 1))
	bg.add_child(hint)

	var skip_all: bool = false
	bg.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			skip_all = true
	)

	for i in range(NARRATIVE.size()):
		if skip_all: break
		lbl.modulate.a = 0
		lbl.text = NARRATIVE[i]

		var t := create_tween()
		t.tween_property(lbl, "modulate:a", 1.0, 0.8)
		t.tween_interval(3.5)
		if i < NARRATIVE.size() - 1 and not skip_all:
			t.tween_property(lbl, "modulate:a", 0.0, 0.6)

		while t.is_running() and not skip_all:
			await get_tree().process_frame
		if skip_all and t.is_running():
			t.kill()
		if not is_instance_valid(lbl): return

	bg.queue_free()

	var stats: Dictionary = GameState.calculate_score()
	var tier: String = stats["tier"]
	var tier_col: Color
	match tier:
		"S": tier_col = Color(0.98, 0.78, 0.29)
		"A": tier_col = Color(0.36, 0.79, 0.65)
		"B": tier_col = Color(0.89, 0.59, 0.29)
		_:   tier_col = Color(0.6, 0.6, 0.6)

	# Title
	var title: Label = Label.new()
	title.text = "算力归零"
	title.position = Vector2(0, 60)
	title.size = Vector2(1280, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", tier_col)
	add_child(title)

	# Narrative
	var sub: Label = Label.new()
	sub.text = "你击败了骰子之神。旧王的屏幕碎成乱码。\n赌场的机器人们停下骰子，抬头望向你。\n新国王诞生。"
	sub.position = Vector2(0, 130)
	sub.size = Vector2(1280, 80)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.66))
	add_child(sub)

	# Stats section
	var sy: int = 240
	var boss_names: Array = ["老杰克", "独眼龙", "三人组", "骰子之神"]
	for i in range(boss_names.size()):
		var cleared: bool = i < GameState.bosses_defeated.size()
		_add_stat_line(sy, "击败 Boss: %s" % boss_names[i], "✓" if cleared else "✗", Color(0.36, 0.79, 0.65) if cleared else Color(0.5, 0.15, 0.15))
		sy += 30

	_add_stat_line(sy, "感染次数", str(GameState.total_assimilations), Color(1, 1, 1))
	sy += 30
	_add_stat_line(sy, "事件完成", str(GameState.events_completed), Color(1, 1, 1))
	sy += 30
	_add_stat_line(sy, "最终金币", str(GameState.gold), Color(1, 1, 1))
	sy += 30

	# Score breakdown
	sy += 10
	_add_stat_line(sy, "Boss 底分", "+%d" % stats["boss_bonus"], Color(0.5, 0.5, 0.5))
	sy += 26
	_add_stat_line(sy, "金币加成", "+%d" % stats["gold_bonus"], Color(0.5, 0.5, 0.5))
	sy += 26
	_add_stat_line(sy, "感染惩罚", "-%d" % stats["assimilation_penalty"], Color(0.5, 0.5, 0.5))
	sy += 26
	_add_stat_line(sy, "事件加成", "+%d" % stats["event_bonus"], Color(0.5, 0.5, 0.5))
	sy += 26

	# Total score
	sy += 10
	var total_lbl: Label = Label.new()
	total_lbl.text = "总分: %d" % stats["score"]
	total_lbl.position = Vector2(440, sy)
	total_lbl.size = Vector2(400, 30)
	total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_lbl.add_theme_font_size_override("font_size", 20)
	total_lbl.add_theme_color_override("font_color", tier_col)
	add_child(total_lbl)

	# Tier
	sy += 40
	var tier_lbl: Label = Label.new()
	var tier_desc: Dictionary = {
		"S": "无懈可击 — 骰子之神在你面前也只是个零件。",
		"A": "强者风范 — 算法精准，运气站在你这边。",
		"B": "有惊无险 — 扛过几次感染，但也活下来了。",
		"C": "九死一生 — 芯片烧了半边，但你毕竟是新国王。",
	}
	tier_lbl.text = "阶级评定:  %s   %s" % [tier, tier_desc.get(tier, "")]
	tier_lbl.position = Vector2(200, sy)
	tier_lbl.size = Vector2(880, 35)
	tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_lbl.add_theme_font_size_override("font_size", 18)
	tier_lbl.add_theme_color_override("font_color", tier_col)
	add_child(tier_lbl)

	# Back button
	sy += 60
	var btn: ColorRect = ColorRect.new()
	btn.position = Vector2(490, sy)
	btn.size = Vector2(300, 50)
	btn.color = Color(0.36, 0.74, 0.95)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(btn)
	var back_lbl: Label = Label.new()
	back_lbl.text = "返回主菜单"
	back_lbl.position = Vector2(0, 0)
	back_lbl.size = Vector2(300, 50)
	back_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	back_lbl.add_theme_font_size_override("font_size", 18)
	back_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_child(back_lbl)
	btn.mouse_entered.connect(func(): btn.color = Color(0.46, 0.84, 1, 1))
	btn.mouse_exited.connect(func(): btn.color = Color(0.36, 0.74, 0.95))
	btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			GameState._clear_save()
			get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	)

func _add_stat_line(y: int, label: String, value: String, col: Color) -> void:
	var l: Label = Label.new()
	l.text = label
	l.position = Vector2(390, y)
	l.size = Vector2(280, 26)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.7, 0.7, 0.66))
	add_child(l)
	var v: Label = Label.new()
	v.text = value
	v.position = Vector2(680, y)
	v.size = Vector2(200, 26)
	v.add_theme_font_size_override("font_size", 14)
	v.add_theme_color_override("font_color", col)
	add_child(v)
