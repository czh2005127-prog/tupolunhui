extends Control

const PlayerCardRef := preload("res://scripts/resources/PlayerCardData.gd")
const BossFragmentRef := preload("res://scripts/resources/BossFragmentData.gd")
const CardPoolRef := preload("res://scripts/cards/CardPool.gd")
const DieWidgetRef := preload("res://scripts/ui/components/CombatDieWidget.gd")
const PhysicalDiceBoardRef := preload("res://scripts/ui/components/PhysicalDiceBoard.gd")
const CardFaceViewRef := preload("res://scripts/ui/components/CardFaceView.gd")
const BATTLE_BACKGROUND: Texture2D = preload("res://assets/ui/battle/background.png")
const SCORE_PANEL_TEXTURE: Texture2D = preload("res://assets/ui/battle/score_panel.png")
const TOTAL_SCORE_TEXTURE: Texture2D = preload("res://assets/ui/battle/total_score_bar.png")
const BASE_SCORE_TEXTURE: Texture2D = preload("res://assets/ui/battle/base_score_bar.png")
const MULTIPLIER_TEXTURE: Texture2D = preload("res://assets/ui/battle/multiplier_bar.png")
const DRAW_PILE_TEXTURE: Texture2D = preload("res://assets/ui/battle/draw_pile_button.png")
const DISCARD_PILE_TEXTURE: Texture2D = preload("res://assets/ui/battle/discard_pile_button.png")
const OPPONENT_PANEL_TEXTURE: Texture2D = preload("res://assets/ui/battle/opponent_panel.png")
const DICE_BORDER_TEXTURE: Texture2D = preload("res://assets/ui/battle/dice_border.png")
const CONFIRM_TEXTURE: Texture2D = preload("res://assets/ui/battle/confirm_button.png")
const NOTIFICATION_TEXTURE: Texture2D = preload("res://assets/ui/battle/notification_bar.png")
const BATTLE_STATUS_TEXTURE: Texture2D = preload("res://assets/ui/battle/battle_status_bar.png")
const SETTINGS_TEXTURE: Texture2D = preload("res://assets/ui/battle/settings_button.png")
const HEALTH_TEXTURE: Texture2D = preload("res://assets/ui/battle/health_bar.png")
const GOLD_TEXTURE: Texture2D = preload("res://assets/ui/battle/gold_bar.png")
const FRAGMENT_SLOT_LEFT_TEXTURE: Texture2D = preload("res://assets/ui/battle/fragment_slot_left.png")
const FRAGMENT_SLOT_RIGHT_TEXTURE: Texture2D = preload("res://assets/ui/battle/fragment_slot_right.png")
const ENEMY_SPEECH_TEXTURE: Texture2D = preload("res://assets/ui/battle/enemy_speech_bubble.png")
const EFFECTS_BAR_TEXTURE: Texture2D = preload("res://assets/ui/battle/effects_bar.png")
const ITEM_DETAIL_TEXTURE: Texture2D = preload("res://assets/ui/battle/item_detail_panel.png")
const RETAIN_MARKER_TEXTURE: Texture2D = preload("res://assets/ui/battle/retain_marker.png")
const BATTLE_RESULT_TEXTURE: Texture2D = preload("res://assets/ui/battle/battle_result_panel.png")
const RESULT_CONFIRM_TEXTURE: Texture2D = preload("res://assets/ui/battle/result_confirm_button.png")
const REWARD_GOLD_TEXTURE: Texture2D = preload("res://assets/ui/battle/reward_gold_icon.png")
const REWARD_RUST_TEXTURE: Texture2D = preload("res://assets/ui/battle/reward_rust_icon.png")
const ROUND_BANNER_TEXTURE: Texture2D = preload("res://assets/ui/battle/round_banner.png")
const EFFECT_ICON_TEXTURES: Array[Texture2D] = [
	preload("res://assets/ui/battle/effect_icon_01.png"),
	preload("res://assets/ui/battle/effect_icon_02.png"),
	preload("res://assets/ui/battle/effect_icon_03.png"),
	preload("res://assets/ui/battle/effect_icon_04.png"),
	preload("res://assets/ui/battle/effect_icon_05.png"),
	preload("res://assets/ui/battle/effect_icon_06.png"),
	preload("res://assets/ui/battle/effect_icon_07.png"),
	preload("res://assets/ui/battle/effect_icon_08.png"),
	preload("res://assets/ui/battle/effect_icon_09.png"),
	preload("res://assets/ui/battle/effect_icon_10.png"),
]

const BOARD_SIZE := Vector2(1280, 720)
const GOLD := Color("efbd55")
const PAPER := Color("dfd4ba")
const MUTED := Color("958d7c")
const RED := Color("e65a55")
const CYAN := Color("66c8c0")

var _game: DiceGame
var _flow: Node
var _cards: Array = []
var _is_boss := false
var _stage_index := 0
var _pending_hand_index := -1
var _latest_state: Dictionary = {}
var _log_entries: Array[String] = []

var _board: Control
var _score_label: Label
var _formula_label: Label
var _breakdown_label: Label
var _multiplier_label: Label
var _status_label: Label
var _enemy_row: Control
var _dice_row: Control
var _physical_dice_board: PhysicalDiceBoard
var _dice_hitboxes: Control
var _hand_area: Control
var _draw_pile_label: Label
var _discard_pile_label: Label
var _log_label: RichTextLabel
var _confirm_button: Button
var _fragment_row: Control
var _health_label: Label
var _gold_label: Label
var _settings_layer: CanvasLayer
var _toast_panel: Panel
var _toast_label: Label
var _enemy_speech_panel: TextureRect
var _enemy_speech_label: Label
var _enemy_speech_panels: Array[TextureRect] = []
var _enemy_speech_labels: Array[Label] = []
var _enemy_speech_tokens: Array[int] = [0, 0, 0]
var _enemy_speech_tweens: Array = [null, null, null]
var _enemy_countdown_snapshot: Array[Dictionary] = []
var _card_hold_generation := 0
var _card_hold_tokens: Dictionary = {}
var _long_pressed_cards: Dictionary = {}
var _effects_row: Control
var _target_cursor: Control
var _previous_hand_ids: Array[String] = []
var _previous_dice: Array = []
var _previous_round := 0
var _previous_total := 0
var _round_banner: TextureRect
var _round_banner_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_center_board)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and _pending_hand_index >= 0:
		_cancel_die_targeting()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _long_pressed_cards.is_empty():
		call_deferred("_clear_all_long_presses")

func _process(_delta: float) -> void:
	if is_instance_valid(_target_cursor):
		_target_cursor.position = get_viewport().get_mouse_position() - _board.global_position + Vector2(12, 12)

func setup_with_flow(_stage_data: Resource, flow: Node, cards: Variant = null) -> void:
	_flow = flow
	_cards = cards if cards is Array else []
	_stage_index = clampi(GameState.current_stage, 0, 3)
	_is_boss = _cards.size() >= 3 or (flow != null and flow.get("_is_boss_node") == true)
	_build_ui()
	_game = get_node_or_null("DiceGame") as DiceGame
	if _game == null:
		_game = DiceGame.new()
		_game.name = "DiceGame"
		add_child(_game)
	_game.state_changed.connect(_on_state_changed)
	_game.message_posted.connect(_on_message)
	_game.battle_finished.connect(_on_battle_finished)
	var normal_index := 0
	if flow != null and flow.has_method("get_current_normal_battle_index"):
		normal_index = flow.get_current_normal_battle_index()
	_game.configure(_stage_index, _cards, _is_boss, normal_index)

func _build_ui() -> void:
	for child in get_children():
		if child.name != "DiceGame":
			child.queue_free()
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("090807")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	_board = Control.new()
	_board.name = "BattleBoard"
	_board.size = BOARD_SIZE
	add_child(_board)
	_center_board()
	_build_table_background()

	var status_bar := _texture_rect(BATTLE_STATUS_TEXTURE, Vector2(479, 0), Vector2(422, 38), 20)
	_status_label = _label("准备战斗", 14, PAPER)
	_status_label.position = Vector2(12, 3)
	_status_label.size = Vector2(398, 31)
	_status_label.z_index = 1
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_bar.add_child(_status_label)

	var score_panel := _texture_rect(SCORE_PANEL_TEXTURE, Vector2(25, 27.6), Vector2(454, 309), 20)
	score_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var score_hitbox := Button.new()
	score_hitbox.name = "ScoreRulesHitbox"
	score_hitbox.position = Vector2.ZERO
	score_hitbox.size = score_panel.size
	score_hitbox.flat = true
	score_hitbox.tooltip_text = "查看骰型与计分规则"
	score_hitbox.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	score_hitbox.pressed.connect(_show_score_guide)
	score_panel.add_child(score_hitbox)
	_score_label = _label("0 / 0", 22, GOLD)
	_score_label.name = "TargetScoreLabel"
	_score_label.position = Vector2(118, 4)
	_score_label.size = Vector2(216, 52)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_score_label.z_index = 1
	score_panel.add_child(_score_label)
	var total_bar := _texture_rect(TOTAL_SCORE_TEXTURE, Vector2(77, 104.6), Vector2(350, 78), 30)
	_formula_label = _label("0", 24, PAPER)
	_formula_label.name = "TotalScoreLabel"
	_formula_label.position = Vector2(70, 12)
	_formula_label.size = Vector2(270, 54)
	_formula_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_formula_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	total_bar.add_child(_formula_label)
	var base_box := _texture_rect(BASE_SCORE_TEXTURE, Vector2(77, 216.6), Vector2(147, 56), 30)
	_breakdown_label = _label("0", 22, PAPER)
	_breakdown_label.position = Vector2.ZERO
	_breakdown_label.size = base_box.size
	_breakdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_breakdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	base_box.add_child(_breakdown_label)
	var mult_box := _texture_rect(MULTIPLIER_TEXTURE, Vector2(280, 216.6), Vector2(147, 56), 30)
	_multiplier_label = _label("× 1", 22, GOLD)
	_multiplier_label.name = "MultiplierLabel"
	_multiplier_label.size = mult_box.size
	_multiplier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_multiplier_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mult_box.add_child(_multiplier_label)

	_texture_rect(OPPONENT_PANEL_TEXTURE, Vector2(476, 34.6), Vector2(773, 275), 20)
	_enemy_row = Control.new()
	_enemy_row.position = Vector2.ZERO
	_enemy_row.size = BOARD_SIZE
	_enemy_row.z_index = 40
	_board.add_child(_enemy_row)

	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled = true
	_log_label.visible = false
	_log_label.position = Vector2.ZERO
	_log_label.size = Vector2.ONE
	_log_label.scroll_active = false
	_log_label.add_theme_font_size_override("normal_font_size", 13)
	_board.add_child(_log_label)

	_texture_rect(DICE_BORDER_TEXTURE, Vector2(662, 336.6), Vector2(594, 354), 20)
	_dice_row = Control.new()
	_dice_row.position = Vector2(680, 352.6)
	_dice_row.size = Vector2(558, 322)
	_dice_row.z_index = 31
	_board.add_child(_dice_row)
	_physical_dice_board = PhysicalDiceBoardRef.new() as PhysicalDiceBoard
	_physical_dice_board.name = "PhysicalDiceBoard"
	_physical_dice_board.position = Vector2.ZERO
	_physical_dice_board.size = _dice_row.size
	_physical_dice_board.z_index = 0
	_dice_row.add_child(_physical_dice_board)
	_dice_hitboxes = Control.new()
	_dice_hitboxes.name = "DiceHitboxes"
	_dice_hitboxes.size = _dice_row.size
	_dice_hitboxes.z_index = 2
	_dice_row.add_child(_dice_hitboxes)

	_texture_rect(EFFECTS_BAR_TEXTURE, Vector2(508, 269.6), Vector2(454, 67), 30)
	_effects_row = Control.new()
	_effects_row.name = "ActiveEffectsRow"
	_effects_row.position = Vector2(520, 281.6)
	_effects_row.size = Vector2(430, 44)
	_effects_row.z_index = 40
	_board.add_child(_effects_row)

	_hand_area = Control.new()
	_hand_area.position = Vector2(167, 431)
	_hand_area.size = Vector2(373, 155)
	_hand_area.z_index = 31
	_board.add_child(_hand_area)
	_build_pile_button(DRAW_PILE_TEXTURE, Vector2(599, 608.6), Vector2(48, 52), "牌库", _show_draw_pile)
	_build_pile_button(DISCARD_PILE_TEXTURE, Vector2(29, 608.6), Vector2(48, 52), "弃牌堆", _show_discard_pile)
	_draw_pile_label = _build_pile_count_label(Vector2(593, 622.6), "牌库数量")
	_discard_pile_label = _build_pile_count_label(Vector2(23, 622.6), "弃牌堆数量")

	var health_bar := _texture_rect(HEALTH_TEXTURE, Vector2(968, 269.6), Vector2(120, 56), 30)
	_health_label = _label("2", 18, PAPER)
	_health_label.position = Vector2(45, 8)
	_health_label.size = Vector2(67, 40)
	_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	health_bar.add_child(_health_label)
	var gold_bar := _texture_rect(GOLD_TEXTURE, Vector2(1088, 269.6), Vector2(120, 56), 30)
	_gold_label = _label("0", 18, GOLD)
	_gold_label.position = Vector2(45, 8)
	_gold_label.size = Vector2(67, 40)
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gold_bar.add_child(_gold_label)

	_fragment_row = Control.new()
	_fragment_row.position = Vector2(528, 328.6)
	_fragment_row.size = Vector2(112, 67)
	_fragment_row.z_index = 35
	_texture_rect(FRAGMENT_SLOT_LEFT_TEXTURE, Vector2(528, 328.6), Vector2(59, 67), 20)
	_texture_rect(FRAGMENT_SLOT_RIGHT_TEXTURE, Vector2(581, 328.6), Vector2(59, 67), 20)
	_board.add_child(_fragment_row)
	_confirm_button = _texture_button(CONFIRM_TEXTURE, Vector2(217, 626.6), Vector2(241, 68), 20)
	_confirm_button.tooltip_text = "确认本轮计分"
	_confirm_button.pressed.connect(_on_confirm)
	var settings_button := _texture_button(SETTINGS_TEXTURE, Vector2(1236, 5.6), Vector2(41, 38), 20)
	settings_button.name = "BattleSettingsButton"
	settings_button.tooltip_text = "暂停与设置"
	settings_button.pressed.connect(_show_pause_settings)

	_build_overlay_widgets()
	_build_round_banner()
	_rebuild_fragments()

func _build_table_background() -> void:
	_texture_rect(BATTLE_BACKGROUND, Vector2.ZERO, BOARD_SIZE, 0)

func _build_overlay_widgets() -> void:
	_toast_panel = Panel.new()
	_toast_panel.position = Vector2(25, 336.6)
	_toast_panel.size = Vector2(454, 52)
	_toast_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_toast_panel.z_index = 120
	_board.add_child(_toast_panel)
	var toast_art := TextureRect.new()
	toast_art.texture = NOTIFICATION_TEXTURE
	toast_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toast_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	toast_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	toast_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_child(toast_art)
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label = _label("", 14, PAPER)
	_toast_label.position = Vector2(20, 7)
	_toast_label.size = Vector2(414, 36)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.z_index = 1
	_toast_panel.add_child(_toast_label)
	_toast_panel.visible = true

	_enemy_speech_panels.clear()
	_enemy_speech_labels.clear()
	_enemy_countdown_snapshot.clear()
	for index in range(3):
		var speech_panel := TextureRect.new()
		speech_panel.name = "EnemySpeechBubble%d" % index
		speech_panel.texture = ENEMY_SPEECH_TEXTURE
		speech_panel.size = Vector2(114, 93)
		speech_panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		speech_panel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		speech_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		speech_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		speech_panel.z_index = 130
		speech_panel.visible = false
		_board.add_child(speech_panel)
		var speech_label := _label("", 10, Color("30271f"))
		speech_label.position = Vector2(9, 7)
		speech_label.size = Vector2(96, 66)
		speech_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		speech_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		speech_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		speech_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		speech_panel.add_child(speech_label)
		_enemy_speech_panels.append(speech_panel)
		_enemy_speech_labels.append(speech_label)
	_enemy_speech_panel = _enemy_speech_panels[0]
	_enemy_speech_label = _enemy_speech_labels[0]

func _build_round_banner() -> void:
	_round_banner = _texture_rect(ROUND_BANNER_TEXTURE, Vector2(440, 300), Vector2(400, 80), 150)
	_round_banner.name = "RoundBanner"
	_round_banner.visible = false
	_round_banner_label = _label("", 30, GOLD)
	_round_banner_label.position = Vector2(24, 10)
	_round_banner_label.size = Vector2(352, 60)
	_round_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_round_banner.add_child(_round_banner_label)

func _show_round_banner(round_number: int, max_rounds: int, phase: int) -> void:
	if not is_instance_valid(_round_banner):
		return
	var shown := "第 %d 轮" % round_number
	if round_number >= max_rounds:
		shown = "最后一轮"
	if phase > 1 and round_number <= 1:
		shown = "Boss 第二阶段"
	_round_banner_label.text = shown
	_round_banner.visible = true
	_round_banner.modulate = Color(1, 1, 1, 0)
	_round_banner.scale = Vector2(0.92, 0.92)
	_round_banner.pivot_offset = _round_banner.size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_round_banner, "modulate:a", 1.0, 0.12)
	tween.tween_property(_round_banner, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(0.6)
	tween.tween_property(_round_banner, "modulate:a", 0.0, 0.22)
	tween.finished.connect(func():
		if is_instance_valid(_round_banner):
			_round_banner.visible = false
	)

func _center_board() -> void:
	if _board == null:
		return
	_board.position = (size - BOARD_SIZE) * 0.5

func _on_state_changed(state: Dictionary) -> void:
	var old_round := _previous_round
	var old_total := _previous_total
	var old_dice := _previous_dice.duplicate(true)
	var old_hand_ids := _previous_hand_ids.duplicate()
	_latest_state = state
	var phase_text := " · 第%d阶段" % int(state.phase) if int(state.phase) > 1 else ""
	_status_label.text = "第%d层 · %s%s　　第 %d / %d 轮" % [
		_stage_index + 1,
		"Boss战" if _is_boss else "普通战",
		phase_text,
		int(state.round),
		int(state.max_rounds),
	]
	_score_label.text = "目标 %d" % int(state.target)
	var preview: Dictionary = state.preview
	var final_factor := int(preview.get("final_factor", 1))
	_formula_label.text = "%d" % int(state.total)
	_breakdown_label.text = "%d" % int(preview.get("base", 0))
	_multiplier_label.text = "× %d%s" % [int(preview.get("multiplier", 1)), " ×%d" % final_factor if final_factor > 1 else ""]
	if int(state.total) > old_total:
		_animate_score_gain(int(state.total) - old_total)
	_gold_label.text = "%d" % int(state.get("gold", GameState.gold))
	_health_label.text = "%d" % maxi(0, GameState.MAX_ASSIMILATION - GameState.assimilation_count)
	var pattern_names: Array[String] = []
	for pattern in preview.get("patterns", []):
		pattern_names.append(str(pattern.get("name", "骰型")))
	_draw_pile_label.text = "%d" % int(state.draw_count)
	_discard_pile_label.text = "%d" % int(state.discard_count)
	var pile_summary := "抽牌堆 %d · 弃牌堆 %d · 封存 %d · 手牌 %d/%d" % [int(state.draw_count), int(state.discard_count), int(state.exhaust_count), state.hand.size(), int(state.hand_limit)]
	_draw_pile_label.tooltip_text = pile_summary
	_discard_pile_label.tooltip_text = pile_summary
	_confirm_button.disabled = bool(state.over)
	_rebuild_enemies(state.enemies)
	_update_enemy_countdown_bubbles(state.enemies, bool(state.over))
	_rebuild_effects(state.get("effects", []))
	_rebuild_dice(state.dice, old_dice, int(state.round) != old_round)
	_rebuild_hand(state.hand, state.retained, old_hand_ids)
	if int(state.round) != old_round and int(state.round) > 0 and not bool(state.over):
		_show_round_banner(int(state.round), int(state.max_rounds), int(state.phase))
	_previous_round = int(state.round)
	_previous_total = int(state.total)
	_previous_dice = state.dice.duplicate(true)
	_previous_hand_ids.clear()
	for entry in state.hand:
		_previous_hand_ids.append(str(entry.get("id", "")))

func _animate_score_gain(gained: int) -> void:
	for label in [_breakdown_label, _multiplier_label, _formula_label]:
		label.pivot_offset = label.size * 0.5
		label.scale = Vector2.ONE
	var tween := create_tween()
	tween.tween_property(_breakdown_label, "scale", Vector2(1.18, 1.18), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_breakdown_label, "scale", Vector2.ONE, 0.1)
	tween.tween_property(_multiplier_label, "scale", Vector2(1.18, 1.18), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_multiplier_label, "scale", Vector2.ONE, 0.1)
	tween.tween_property(_formula_label, "scale", Vector2(1.25, 1.25), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_formula_label, "scale", Vector2.ONE, 0.12)
	_show_toast("本轮 +%d 分" % gained, GOLD)

func _rebuild_enemies(enemies: Array) -> void:
	_clear(_enemy_row)
	for index in range(enemies.size()):
		var enemy: Dictionary = enemies[index]
		var current: Dictionary = enemy.current
		var face_button := Button.new()
		face_button.position = _enemy_card_position(index, enemies.size())
		face_button.size = Vector2(107, 155)
		face_button.flat = true
		face_button.tooltip_text = "左键查看技能详情；右键查看台词与倒计时"
		face_button.pressed.connect(_show_enemy_details.bind(index))
		face_button.gui_input.connect(_on_enemy_card_gui_input.bind(index))
		_enemy_row.add_child(face_button)
		var card_resource: Resource = _game.opponents[index] as Resource if _game != null and index < _game.opponents.size() else null
		if card_resource != null:
			var face_view := CardFaceViewRef.new() as CardFaceView
			var next: Dictionary = enemy.next
			face_view.setup_opponent(card_resource, "%s\n下个:%s" % [current.get("name", "技能"), next.get("name", "未知")], false, 10)
			face_button.add_child(face_view)

func _on_enemy_card_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_show_enemy_speech(index)

func _show_enemy_speech(index: int) -> void:
	var enemies: Array = _latest_state.get("enemies", [])
	if index < 0 or index >= enemies.size():
		return
	var enemy: Dictionary = enemies[index]
	_show_enemy_bubble(index, "%s\n倒计时：%d" % [_enemy_banter(str(enemy.get("card_id", ""))), int(enemy.get("timer", 0))], 5.0, 0.8)

func _show_enemy_bubble(index: int, text_value: String, duration: float, fade_duration: float) -> void:
	if index < 0 or index >= _enemy_speech_panels.size():
		return
	var panel := _enemy_speech_panels[index]
	var label := _enemy_speech_labels[index]
	var enemy_count := (_latest_state.get("enemies", []) as Array).size()
	panel.position = _enemy_card_position(index, enemy_count) + Vector2(97, -45)
	label.text = text_value
	label.add_theme_font_size_override("font_size", 30 if text_value.is_valid_int() else 10)
	label.add_theme_color_override("font_color", RED if text_value == "1" else Color("30271f"))
	panel.modulate = Color.WHITE
	panel.visible = true
	if text_value.is_valid_int():
		label.pivot_offset = label.size * 0.5
		label.scale = Vector2(1.4, 1.4)
		var pulse := create_tween()
		pulse.tween_property(label, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		for offset in [4.0, -4.0, 3.0, -3.0, 0.0]:
			pulse.tween_property(label, "position:x", 9.0 + offset, 0.045)
	_enemy_speech_tokens[index] += 1
	var token := _enemy_speech_tokens[index]
	var previous_tween: Tween = _enemy_speech_tweens[index] as Tween
	if previous_tween != null and previous_tween.is_valid():
		previous_tween.kill()
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		if not is_instance_valid(panel) or token != _enemy_speech_tokens[index]:
			return
		if fade_duration <= 0.0:
			panel.visible = false
			return
		var fade := create_tween()
		_enemy_speech_tweens[index] = fade
		fade.tween_property(panel, "modulate:a", 0.0, fade_duration)
		fade.finished.connect(func() -> void:
			if is_instance_valid(panel) and token == _enemy_speech_tokens[index]:
				panel.visible = false
		)
	)

func _update_enemy_countdown_bubbles(enemies: Array, battle_over: bool) -> void:
	if not _enemy_countdown_snapshot.is_empty() and not battle_over:
		for index in range(mini(enemies.size(), _enemy_countdown_snapshot.size())):
			var enemy: Dictionary = enemies[index]
			var previous: Dictionary = _enemy_countdown_snapshot[index]
			var same_card := str(enemy.get("card_id", "")) == str(previous.get("card_id", ""))
			var timer_decreased := int(enemy.get("timer", 0)) < int(previous.get("timer", 0))
			var skill_changed := int(enemy.get("skill_index", 0)) != int(previous.get("skill_index", 0))
			if same_card and (timer_decreased or skill_changed):
				_show_enemy_bubble(index, str(int(enemy.get("timer", 0))), 3.0, 0.0)
	_enemy_countdown_snapshot.clear()
	for enemy in enemies:
		_enemy_countdown_snapshot.append({
			"card_id": str(enemy.get("card_id", "")),
			"timer": int(enemy.get("timer", 0)),
			"skill_index": int(enemy.get("skill_index", 0)),
		})

func _enemy_card_position(index: int, enemy_count: int) -> Vector2:
	if enemy_count >= 3:
		var boss_positions := [Vector2(570, 89.6), Vector2(802, 89.6), Vector2(1035, 89.6)]
		return boss_positions[index] if index < boss_positions.size() else Vector2(570 + index * 232, 89.6)
	if enemy_count == 2:
		return [Vector2(682, 89.6), Vector2(937, 89.6)][index]
	return Vector2(802, 89.6)

func _enemy_banter(card_id: String) -> String:
	var lines := {
		"jack_crt": "别眨眼，我都看着呢。",
		"rust_warrior": "你的骰子，经得住锈吗？",
		"battery_kid": "电量够，再陪你一轮。",
		"signal_noise": "听见了吗？只剩杂音。",
		"cyclops_lcd": "被我盯上的点数跑不了。",
		"two_face": "你猜，我现在是哪一面？",
		"chamberlain": "请先接受军械检查。",
		"recycler": "别浪费，输掉的都归我。",
		"lucky_one": "运气也会挑主人。",
		"referee": "规矩由我宣读，也由我执行。",
		"mirror_tech": "你做得到，我也做得到。",
		"table_ghost": "空位？我替你坐下。",
		"alliance_oled": "这张桌上没有秘密。",
		"casino_owner": "灯灭以后，才是真正的赌局。",
		"prophet": "这一步，我已经算过了。",
		"dealer": "筹码落桌，就没有反悔。",
		"dice_god": "继续。让我看看你的极限。",
		"unknown_mirror": "你看见的，正是你自己。",
		"unknown_chaos": "别相信刚才发生的一切。",
		"unknown_abyss": "再靠近一点。",
	}
	return str(lines.get(card_id, "又来一个……希望这次靠谱。"))

func _rebuild_dice(dice: Array, old_dice: Array = [], animate_roll: bool = false) -> void:
	if not is_instance_valid(_dice_hitboxes):
		return
	_clear(_dice_hitboxes)
	var columns := 8
	var step := Vector2(67, 68)
	var rows := ceili(float(dice.size()) / float(columns))
	var start_y := maxf(0.0, (_dice_row.size.y - float(rows) * step.y) * 0.5)
	var display_order: Array[int] = []
	for index in range(dice.size()):
		display_order.append(index)
	display_order.sort_custom(func(a: int, b: int) -> bool:
		var a_hidden := bool((dice[a] as Dictionary).get("hidden", false))
		var b_hidden := bool((dice[b] as Dictionary).get("hidden", false))
		if a_hidden != b_hidden:
			return not a_hidden
		return int((dice[a] as Dictionary).get("value", 0)) < int((dice[b] as Dictionary).get("value", 0))
	)
	var sorted_dice: Array = []
	var any_changed := old_dice.size() != dice.size()
	for original_index in display_order:
		sorted_dice.append((dice[original_index] as Dictionary).duplicate(true))
		if original_index >= old_dice.size() or int((old_dice[original_index] as Dictionary).get("value", -1)) != int((dice[original_index] as Dictionary).get("value", -1)):
			any_changed = true
	_physical_dice_board.set_dice(sorted_dice, animate_roll or any_changed)
	for display_index in range(display_order.size()):
		var index := display_order[display_index]
		var widget := DieWidgetRef.new() as CombatDieWidget
		var legal_target := _pending_hand_index >= 0 and is_instance_valid(_game) and _game.is_die_target_legal(_pending_hand_index, index)
		widget.setup(index, dice[index], legal_target, false)
		var row := floori(float(display_index) / float(columns))
		var column := display_index % columns
		var count_this_row := mini(columns, dice.size() - row * columns)
		var row_width := float(count_this_row) * step.x - 3.0
		var target_position := Vector2(maxf(0.0, (_dice_row.size.x - row_width) * 0.5) + column * step.x, start_y + row * step.y)
		widget.position = target_position
		widget.pressed.connect(_on_die_clicked)
		_dice_hitboxes.add_child(widget)

func _rebuild_hand(cards: Array, retained: Array, old_hand_ids: Array[String] = []) -> void:
	_clear(_hand_area)
	if cards.is_empty():
		var empty := _label("本轮没有可用手牌", 16, MUTED)
		empty.position = Vector2(0, 62)
		empty.size = Vector2(373, 32)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hand_area.add_child(empty)
		return
	var card_size := Vector2(107, 155)
	var available := _hand_area.size.x
	var step := card_size.x + 8.0
	if cards.size() > 1:
		step = minf(step, (available - card_size.x) / float(cards.size() - 1))
	var total_width := card_size.x + step * float(cards.size() - 1)
	var start_x := (available - total_width) * 0.5
	var old_counts: Dictionary = {}
	for card_id in old_hand_ids:
		old_counts[card_id] = int(old_counts.get(card_id, 0)) + 1
	for index in range(cards.size()):
		var entry: Dictionary = cards[index]
		var card: PlayerCardData = PlayerCardRef.get_by_id(str(entry.id))
		if card == null:
			continue
		var button := Button.new()
		var target_position := Vector2(start_x + step * index, 5 + absf(float(index) - (cards.size() - 1) * 0.5) * 1.4)
		if index in retained:
			target_position.y -= 10.0
		button.position = target_position
		button.size = card_size
		button.pivot_offset = Vector2(card_size.x * 0.5, card_size.y)
		button.rotation_degrees = (float(index) - (cards.size() - 1) * 0.5) * 1.25
		button.z_index = index
		button.text = ""
		var border := card.get_rarity_color()
		var fill := Color("332b25") if not bool(entry.get("blocked", false)) else Color("211f20")
		button.add_theme_stylebox_override("normal", _style(fill, border.darkened(0.25), 2, 8))
		button.add_theme_stylebox_override("hover", _style(fill.lightened(0.1), border, 3, 8))
		button.add_theme_stylebox_override("pressed", _style(fill.darkened(0.08), GOLD, 3, 8))
		button.tooltip_text = "左键短按使用；左键长按保留；右键查看详情。\n每成功使用一张牌，所有敌人的倒计时推进1。"
		var face_view := CardFaceViewRef.new() as CardFaceView
		face_view.setup_player(card, false)
		if bool(entry.get("blocked", false)):
			face_view.add_state_overlay(Color(0.08, 0.08, 0.09, 0.62))
		if index in retained:
			face_view.add_state_overlay(Color(0.25, 0.82, 0.64, 0.18))
		button.add_child(face_view)
		if index in retained:
			var retain_marker := TextureRect.new()
			retain_marker.texture = RETAIN_MARKER_TEXTURE
			retain_marker.position = Vector2(6, 6)
			retain_marker.size = Vector2(24, 24)
			retain_marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			retain_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
			retain_marker.z_index = 4
			button.add_child(retain_marker)
		button.pressed.connect(_on_card_clicked.bind(index))
		button.gui_input.connect(_on_card_gui_input.bind(index))
		_hand_area.add_child(button)
		var card_id := str(entry.get("id", ""))
		var is_new := int(old_counts.get(card_id, 0)) <= 0
		if not is_new:
			old_counts[card_id] = int(old_counts[card_id]) - 1
		elif not old_hand_ids.is_empty():
			button.position = Vector2(599, 608.6) - _hand_area.position
			button.scale = Vector2(0.25, 0.25)
			var draw_tween := create_tween().set_parallel(true)
			draw_tween.tween_interval(float(index) * 0.08)
			draw_tween.tween_property(button, "position", target_position, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			draw_tween.tween_property(button, "scale", Vector2(1.1, 1.1), 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			draw_tween.chain().tween_property(button, "scale", Vector2.ONE, 0.08)

func _rebuild_effects(effects: Array) -> void:
	if not is_instance_valid(_effects_row):
		return
	_clear(_effects_row)
	var grouped_by_category: Dictionary = {}
	for raw_effect in effects:
		var raw: Dictionary = raw_effect
		var category := clampi(int(raw.get("category", 1)), 1, EFFECT_ICON_TEXTURES.size())
		if not grouped_by_category.has(category):
			grouped_by_category[category] = raw.duplicate(true)
			grouped_by_category[category]["stack_count"] = 1
		else:
			var grouped: Dictionary = grouped_by_category[category]
			grouped.stack_count = int(grouped.get("stack_count", 1)) + 1
			grouped.name = "%s / %s" % [grouped.get("name", "效果"), raw.get("name", "效果")]
			grouped.description = "%s\n%s" % [grouped.get("description", ""), raw.get("description", "")]
			if int(grouped.get("remaining", -1)) >= 0 and int(raw.get("remaining", -1)) >= 0:
				grouped.remaining = maxi(int(grouped.remaining), int(raw.remaining))
			else:
				grouped.remaining = -1
			grouped_by_category[category] = grouped
	var grouped_effects: Array = grouped_by_category.values()
	grouped_effects.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("category", 1)) < int(b.get("category", 1)))
	var shown_count := mini(9, grouped_effects.size())
	for index in range(shown_count):
		var effect: Dictionary = grouped_effects[index]
		var button := TextureButton.new()
		button.name = "ActiveEffect%d" % index
		button.position = Vector2(index * 48, 0)
		button.size = Vector2(44, 44)
		var category := clampi(int(effect.get("category", 1)), 1, EFFECT_ICON_TEXTURES.size())
		button.texture_normal = EFFECT_ICON_TEXTURES[category - 1]
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.tooltip_text = "%s：%s" % [effect.get("name", "效果"), effect.get("description", "")]
		button.pressed.connect(_show_effect_details.bind(effect))
		_effects_row.add_child(button)
		var badge := _label("", 11, PAPER)
		badge.position = Vector2(23, 25)
		badge.size = Vector2(19, 17)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_color_override("font_outline_color", Color.BLACK)
		badge.add_theme_constant_override("outline_size", 3)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if index == 8 and grouped_effects.size() > 9:
			badge.text = "+%d" % (grouped_effects.size() - 8)
		else:
			var remaining := int(effect.get("remaining", -1))
			badge.text = "∞" if remaining < 0 else str(remaining)
		button.add_child(badge)

func _show_effect_details(effect: Dictionary) -> void:
	_show_text_modal(str(effect.get("name", "效果详情")), "[font_size=20][color=#dfd4ba]%s[/color][/font_size]\n\n来源：%s\n剩余：%s" % [effect.get("description", ""), effect.get("source", "未知"), "本场" if int(effect.get("remaining", -1)) < 0 else "%d次" % int(effect.get("remaining", 0))])

func _rebuild_fragments() -> void:
	_clear(_fragment_row)
	for index in range(mini(2, GameState.boss_fragments.size())):
		var fragment_id: String = str(GameState.boss_fragments[index])
		var full_name: String = BossFragmentRef.get_fragment_name(fragment_id)
		var fragment_button := _mini_badge(full_name.left(2), Color("3c3044"), Color("cf9de0"))
		fragment_button.position = Vector2(index * 53 + 6, 8)
		fragment_button.size = Vector2(47, 51)
		fragment_button.custom_minimum_size = Vector2.ZERO
		fragment_button.tooltip_text = BossFragmentRef.get_fragment_desc(fragment_id)
		fragment_button.pressed.connect(_on_fragment_pressed.bind(fragment_id))
		_fragment_row.add_child(fragment_button)

func _on_card_clicked(index: int) -> void:
	if bool(_long_pressed_cards.get(index, false)):
		_long_pressed_cards.erase(index)
		return
	if index < 0 or index >= _latest_state.get("hand", []).size():
		return
	var card := PlayerCardRef.get_by_id(str(_latest_state.hand[index].id))
	var result := _game.request_use_card(index)
	if bool(result.get("needs_target", false)):
		_pending_hand_index = index
		_show_toast("选择骰子，完成【%s】" % card.card_name, CYAN)
		_start_die_targeting(card)
		_rebuild_dice(_latest_state.dice, _latest_state.dice)
	elif not bool(result.get("ok", false)):
		_on_message(str(result.get("error", "无法使用")), Color("e96565"))
	else:
		_animate_card_use(card)

func _on_die_clicked(index: int) -> void:
	if _pending_hand_index < 0:
		return
	if not _game.is_die_target_legal(_pending_hand_index, index):
		_show_toast("这颗骰子不是合法目标", RED)
		return
	var card: PlayerCardData = null
	if _pending_hand_index < _latest_state.get("hand", []).size():
		card = PlayerCardRef.get_by_id(str(_latest_state.hand[_pending_hand_index].id))
	var result := _game.request_use_card(_pending_hand_index, index)
	_clear_target_cursor()
	_pending_hand_index = -1
	if not bool(result.get("ok", false)):
		_on_message(str(result.get("error", "无法使用")), Color("e96565"))
	elif card != null:
		_animate_card_use(card)

func _animate_card_use(card: PlayerCardData) -> void:
	var flying := CardFaceViewRef.new() as CardFaceView
	flying.setup_player(card, false)
	flying.position = Vector2(350, 425)
	flying.pivot_offset = Vector2(53.5, 77.5)
	flying.z_index = 170
	flying.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_child(flying)
	var persistent := card.effect in ["fate_lock", "battle_gold_engine", "winner_take_all"]
	var target := Vector2(520, 281.6) if persistent else Vector2(29, 608.6)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(flying, "position", Vector2(586, 280), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(flying, "scale", Vector2(1.12, 1.12), 0.18)
	tween.set_parallel(false)
	tween.tween_interval(0.08)
	tween.set_parallel(true)
	tween.tween_property(flying, "position", target, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(flying, "scale", Vector2(0.22, 0.22), 0.24)
	tween.tween_property(flying, "modulate:a", 0.0, 0.24)
	tween.finished.connect(flying.queue_free)

func _start_die_targeting(card: PlayerCardData) -> void:
	_clear_target_cursor()
	_target_cursor = CardFaceViewRef.new() as CardFaceView
	_target_cursor.name = "TargetCardCursor"
	_target_cursor.setup_player(card, false)
	_target_cursor.scale = Vector2(0.38, 0.38)
	_target_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_cursor.z_index = 180
	_board.add_child(_target_cursor)

func _clear_target_cursor() -> void:
	if is_instance_valid(_target_cursor):
		_target_cursor.queue_free()
	_target_cursor = null

func _cancel_die_targeting() -> void:
	_pending_hand_index = -1
	_clear_target_cursor()
	if not _latest_state.is_empty():
		_rebuild_dice(_latest_state.get("dice", []), _latest_state.get("dice", []))
	_show_toast("已取消选择", MUTED)

func _on_card_gui_input(event: InputEvent, index: int) -> void:

	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
		_show_player_card_details(index)
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.pressed:
		_start_card_hold(index)
	else:
		_card_hold_tokens.erase(index)
		if bool(_long_pressed_cards.get(index, false)):
			call_deferred("_clear_long_press_deferred", index)

func _start_card_hold(index: int) -> void:
	_card_hold_generation += 1
	var token := _card_hold_generation
	_card_hold_tokens[index] = token
	get_tree().create_timer(0.6).timeout.connect(_complete_card_hold.bind(index, token))

func _complete_card_hold(index: int, token: int) -> void:
	if int(_card_hold_tokens.get(index, -1)) != token:
		return
	_card_hold_tokens.erase(index)
	if index < 0 or index >= _latest_state.get("hand", []).size():
		return
	_long_pressed_cards[index] = true
	_game.toggle_retain(index)
	var retained_now := index in _game.retained_indices
	_show_toast("已保留该道具" if retained_now else "已取消保留", CYAN)

func _clear_long_press_deferred(index: int) -> void:
	_long_pressed_cards.erase(index)

func _clear_all_long_presses() -> void:
	_long_pressed_cards.clear()

func _show_player_card_details(index: int) -> void:
	var hand: Array = _latest_state.get("hand", [])
	if index < 0 or index >= hand.size():
		return
	var entry: Dictionary = hand[index]
	var card: PlayerCardData = PlayerCardRef.get_by_id(str(entry.get("id", "")))
	if card == null:
		return
	var content := "[font_size=26][color=#%s]%s[/color][/font_size]\n\n[color=#9e9585]%s · %s[/color]\n\n%s\n\n[color=#66c8c0]左键短按使用；长按0.6秒保留。[/color]" % [card.get_rarity_color().to_html(false), card.card_name, card.category, card.get_rarity_name(), card.description]
	_show_item_detail(card, content)

func _show_item_detail(card: PlayerCardData, content: String) -> void:
	var layer := CanvasLayer.new()
	layer.name = "ItemDetailLayer"
	layer.layer = 800
	add_child(layer)
	var dim_button := Button.new()
	dim_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim_button.modulate = Color(0, 0, 0, 0.82)
	dim_button.flat = true
	dim_button.pressed.connect(layer.queue_free)
	layer.add_child(dim_button)
	var selected_card := CardFaceViewRef.new() as CardFaceView
	selected_card.position = Vector2(412, 282.5)
	selected_card.z_index = 6
	selected_card.setup_player(card, false)
	layer.add_child(selected_card)
	var panel := TextureRect.new()
	panel.name = "ItemDetailPanel"
	panel.texture = ITEM_DETAIL_TEXTURE
	panel.position = Vector2(535, 235)
	panel.size = Vector2(420, 250)
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	panel.z_index = 5
	layer.add_child(panel)
	var detail := RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.position = Vector2(34, 34)
	detail.size = Vector2(352, 182)
	detail.text = content
	detail.scroll_active = true
	detail.add_theme_font_size_override("normal_font_size", 14)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(detail)

func _on_confirm() -> void:
	_clear_target_cursor()
	_pending_hand_index = -1
	_game.confirm_score()

func _show_pause_settings() -> void:
	if is_instance_valid(_settings_layer):
		return
	get_tree().paused = true
	_settings_layer = CanvasLayer.new()
	_settings_layer.layer = 900
	_settings_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_settings_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.84)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_layer.add_child(dim)
	var panel := _panel(Vector2(430, 190), Vector2(420, 340), Color("171411"), Color("8a6738"), 2, dim)
	var title := _label("游戏暂停", 30, GOLD)
	title.position = Vector2(30, 38)
	title.size = Vector2(360, 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	var hint := _label("当前战斗状态已经保存。", 15, MUTED)
	hint.position = Vector2(30, 98)
	hint.size = Vector2(360, 32)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(hint)
	var resume := _button("继续游戏", Vector2(90, 164), Vector2(240, 52), Color("684b29"))
	resume.pressed.connect(_close_pause_settings)
	panel.add_child(resume)
	var main_menu := _button("返回主菜单", Vector2(90, 236), Vector2(240, 52), Color("3d3026"))
	main_menu.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	)
	panel.add_child(main_menu)

func _close_pause_settings() -> void:
	get_tree().paused = false
	if is_instance_valid(_settings_layer):
		_settings_layer.queue_free()
	_settings_layer = null

func _on_fragment_pressed(fragment_id: String) -> void:
	var result := _game.use_fragment(fragment_id, 0)
	if not bool(result.get("ok", false)):
		_on_message(str(result.get("error", "当前无法使用")), Color("e96565"))

func _on_message(message: String, color: Color) -> void:
	var bbcode := "[color=#%s]%s[/color]" % [color.to_html(false), message]
	_log_entries.append(bbcode)
	if _log_entries.size() > 80:
		_log_entries.pop_front()
	_log_label.text = "\n".join(_log_entries.slice(maxi(0, _log_entries.size() - 4)))
	_log_label.scroll_to_line(_log_label.get_line_count())
	_show_toast(message, color)

func _show_toast(message: String, color: Color) -> void:
	_toast_label.text = message
	_toast_label.add_theme_color_override("font_color", color)
	_toast_panel.visible = true
	var token := Time.get_ticks_msec()
	_toast_panel.set_meta("token", token)
	get_tree().create_timer(2.6).timeout.connect(func():
		if is_instance_valid(_toast_panel) and int(_toast_panel.get_meta("token", 0)) == token:
			_toast_label.text = ""
	)

func _show_enemy_details(index: int) -> void:
	var enemies: Array = _latest_state.get("enemies", [])
	if index < 0 or index >= enemies.size():
		return
	var enemy: Dictionary = enemies[index]
	var lines: Array[String] = ["[font_size=25][color=#%s]%s[/color][/font_size]" % [enemy.color.to_html(false), enemy.name], ""]
	var skills: Array = enemy.get("skills", [])
	for skill_index in range(skills.size()):
		var skill: Dictionary = skills[skill_index]
		var marker := "▶ " if skill_index == int(enemy.get("skill_index", 0)) else ""
		lines.append("%s[color=#e6bc6a]%s[/color] · %s%d" % [marker, skill.get("name", "技能"), "持续" if skill.get("kind", "trigger") == "continuous" else "触发", int(skill.get("countdown", 0))])
		lines.append(str(skill.get("desc", "")))
		lines.append("")
	var current: Dictionary = enemy.get("current", {})
	var target_noun := _enemy_target_noun(str(current.get("effect", "")))
	lines.append("[color=#e65a55]当前【%s】预计影响 %d %s[/color]" % [current.get("name", "技能"), int(enemy.ratio_count), target_noun])
	lines.append("[color=#9e9585]原始比例 %s；具体数量按技能生效时的合法目标向下取整。[/color]" % enemy.get("ratio", ""))
	_show_text_modal("对手档案", "\n".join(lines))

func _enemy_target_noun(effect: String) -> String:
	if effect in ["block_category", "discard_high_card", "block_repeat_name", "block_persistent", "limit_card_names", "seal_hand", "haunt_hand", "bottom_high_card", "shuffle_high_hand", "cover_hand", "remove_high_card", "pair_hand", "rotate_card_effects", "used_to_bottom", "rust_used_cards"]:
		return "张手牌"
	if effect in ["seal_discard", "seal_voluntary_discard", "remove_draw_cards"]:
		return "张牌"
	return "颗骰子"

func _show_score_guide() -> void:
	var preview: Dictionary = _latest_state.get("preview", {})
	var lines: Array[String] = [
		"[font_size=25][color=#efbd55]基础点数 × 倍率[/color][/font_size]",
		"基础点数 = 参与计分骰子的点数之和 + 卡牌点数",
		"倍率初始为 1；骰型倍率与卡牌倍率相加，最终乘算最后结算。",
		"",
		"[color=#66c8c0]骰型倍率[/color]",
		"对子 +1　　三条 +3　　四条 +6　　五条 +10　　六条 +15",
		"三连顺 +2　四连顺 +4　五连顺 +7　六连顺 +11",
		"",
		"[color=#66c8c0]当前系统采用的最高分拆分[/color]",
	]
	var patterns: Array = preview.get("patterns", [])
	if patterns.is_empty():
		lines.append("暂无骰型，仅使用初始倍率。")
	else:
		for pattern in patterns:
			var detail := "点数%s" % str(pattern.get("faces", [])) if pattern.get("type", "") == "straight" else "%d点 × %d颗" % [int(pattern.get("face", 0)), int(pattern.get("length", 0))]
			lines.append("• %s　%s　+%d倍率" % [pattern.get("name", "骰型"), detail, int(pattern.get("mult", 0))])
	lines.append("\n[color=#8f887b]同一颗骰子不会重复计入多个骰型；系统自动选择最终得分最高的合法拆分。[/color]")
	_show_text_modal("骰型与计分规则", "\n".join(lines))

func _show_score_details() -> void:
	var preview: Dictionary = _latest_state.get("preview", {})
	var lines: Array[String] = ["[font_size=25][color=#efbd55]本轮预计 %d 分[/color][/font_size]" % int(preview.get("score", 0)), "", "基础点数：[color=#dfd4ba]%d[/color]" % int(preview.get("base", 0)), "最终倍率：[color=#dfd4ba]%d[/color]" % int(preview.get("multiplier", 1))]
	if int(preview.get("final_factor", 1)) > 1:
		lines.append("最终乘算：[color=#dfd4ba]×%d[/color]" % int(preview.final_factor))
	lines.append("")
	var patterns: Array = preview.get("patterns", [])
	if patterns.is_empty():
		lines.append("本轮没有组成骰型，只有初始1倍倍率。")
	else:
		lines.append("[color=#66c8c0]系统采用的最高分拆分[/color]")
		for pattern in patterns:
			var detail := "点数%s" % str(pattern.get("faces", [])) if pattern.get("type", "") == "straight" else "%d点 × %d颗" % [int(pattern.get("face", 0)), int(pattern.get("length", 0))]
			lines.append("• %s　%s　+%d倍率" % [pattern.get("name", "骰型"), detail, int(pattern.get("mult", 0))])
	lines.append("\n[color=#8f887b]同一颗骰子不会重复计入多个骰型；系统会自动选择最终得分最高的合法拆分。[/color]")
	_show_text_modal("骰型拆分", "\n".join(lines))

func _show_score_rules() -> void:
	_show_text_modal("计分规则", "[font_size=25][color=#efbd55]基础点数 × 倍率[/color][/font_size]\n\n基础点数 = 参与计分骰子的点数之和 + 卡牌点数\n倍率初始为1，骰型与卡牌倍率相加；最终×N最后结算。\n\n对子 +1　　三条 +3　　四条 +6\n五条 +10　 六条 +15\n\n三连顺 +2　四连顺 +4\n五连顺 +7　六连顺 +11\n\n[color=#8f887b]所有结果均为整数，没有分数与倍率上限。[/color]")

func _show_full_log() -> void:
	var content := "\n".join(_log_entries)
	if content.is_empty():
		content = "[color=#8f887b]还没有战斗记录。[/color]"
	_show_text_modal("完整日志", content)

func _show_draw_pile() -> void:
	_show_card_pile("抽牌堆", _game.draw_pile if _game != null else [])

func _show_discard_pile() -> void:
	_show_card_pile("弃牌堆", _game.discard_pile if _game != null else [])

func _show_card_pile(title_text: String, ids: Array) -> void:
	var counts: Dictionary = {}
	for card_id in ids:
		counts[str(card_id)] = int(counts.get(str(card_id), 0)) + 1
	var lines: Array[String] = []
	for card_id in counts:
		var card: PlayerCardData = PlayerCardRef.get_by_id(str(card_id))
		var shown_name := card.card_name if card != null else str(card_id)
		lines.append("%s × %d" % [shown_name, int(counts[card_id])])
	lines.sort()
	_show_text_modal(title_text, "\n".join(lines) if not lines.is_empty() else "[color=#8f887b]这里暂时是空的。[/color]")

func _show_text_modal(title_text: String, content: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 800
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var panel := _panel(Vector2(270, 82), Vector2(740, 556), Color("171411"), Color("8a6738"), 2, dim)
	_add_section_title(panel, title_text, "DETAIL", GOLD)
	var scroll := RichTextLabel.new()
	scroll.bbcode_enabled = true
	scroll.position = Vector2(34, 52)
	scroll.size = Vector2(672, 430)
	scroll.text = content
	scroll.scroll_active = true
	scroll.add_theme_font_size_override("normal_font_size", 16)
	panel.add_child(scroll)
	var close := _button("关闭", Vector2(270, 496), Vector2(200, 42), Color("684b29"))
	close.pressed.connect(layer.queue_free)
	panel.add_child(close)

func _on_battle_finished(victory: bool, rounds: int) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1000
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.92)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var panel := TextureRect.new()
	panel.name = "BattleResultPanel"
	panel.texture = BATTLE_RESULT_TEXTURE
	panel.position = Vector2(330, 145)
	panel.size = Vector2(620, 430)
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dim.add_child(panel)
	var title := _label("胜利" if victory else "完全同化", 44, GOLD if victory else RED)
	title.position = Vector2(20, 30)
	title.size = Vector2(580, 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	var final_state: Dictionary = _game.get_view_state() if is_instance_valid(_game) else _latest_state
	var result_text := "累计得分 %d / %d\n使用 %d 个计分轮" % [int(final_state.get("total", 0)), int(final_state.get("target", 0)), rounds] if victory else "本盘挑战结束。\n已获得的永久锈点与科技解锁会保留。"
	var description := _label(result_text, 20, PAPER)
	description.position = Vector2(55, 112)
	description.size = Vector2(510, 90)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(description)
	if victory:
		var multiplier: float = float([2.0, 1.75, 1.5, 1.25, 1.0][clampi(rounds - 1, 0, 4)]) if rounds <= 5 else 0.8
		var reward_gold := floori(CardPoolRef.get_battle_gold(_stage_index, _is_boss) * multiplier)
		var gold_icon := TextureRect.new()
		gold_icon.texture = REWARD_GOLD_TEXTURE
		gold_icon.position = Vector2(95, 269)
		gold_icon.size = Vector2(32, 32)
		panel.add_child(gold_icon)
		var gold_reward_label := _label("+%d" % reward_gold, 18, GOLD)
		gold_reward_label.position = Vector2(132, 267)
		gold_reward_label.size = Vector2(90, 36)
		panel.add_child(gold_reward_label)
		if _is_boss and _stage_index not in GameState.boss_rust_awarded_this_run:
			var rust_icon := TextureRect.new()
			rust_icon.texture = REWARD_RUST_TEXTURE
			rust_icon.position = Vector2(305, 269)
			rust_icon.size = Vector2(32, 32)
			panel.add_child(rust_icon)
			var rust_reward_label := _label("+1", 18, CYAN)
			rust_reward_label.position = Vector2(342, 267)
			rust_reward_label.size = Vector2(80, 36)
			panel.add_child(rust_reward_label)
	var button := TextureButton.new()
	button.name = "BattleResultConfirmButton"
	button.texture_normal = RESULT_CONFIRM_TEXTURE
	button.position = Vector2(520, 500)
	button.size = Vector2(240, 60)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.z_index = 6
	dim.add_child(button)
	var button_label := _label("领取奖励" if victory else "结束挑战", 20, PAPER)
	button_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(button_label)
	button.pressed.connect(func():
		if victory:
			EventBus.node_completed.emit("boss" if _is_boss else "battle")
		elif _flow and _flow.has_method("handle_event_death"):
			_flow.handle_event_death()
		else:
			get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
		queue_free()
	)

func _panel(position_value: Vector2, size_value: Vector2, fill: Color, border: Color, width: int, parent: Control = null) -> Panel:
	var panel := Panel.new()
	panel.position = position_value
	panel.size = size_value
	panel.add_theme_stylebox_override("panel", _style(fill, border, width, 7))
	var actual_parent: Control = _board if parent == null else parent
	actual_parent.add_child(panel)
	return panel

func _style(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box

func _add_section_title(panel: Control, title_text: String, caption: String, color: Color) -> void:
	var title := _label(title_text, 15, color)
	title.position = Vector2(12, 4)
	title.size = Vector2(230, 26)
	panel.add_child(title)
	var tag := _label(caption, 10, MUTED)
	tag.position = Vector2(panel.size.x - 152, 7)
	tag.size = Vector2(134, 20)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(tag)

func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _inline_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := _label(text_value, font_size, color)
	label.custom_minimum_size = Vector2(0, 20)
	return label

func _button(text_value: String, position_value: Vector2, size_value: Vector2, fill: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = position_value
	button.size = size_value
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_stylebox_override("normal", _style(fill, fill.lightened(0.18), 1, 6))
	button.add_theme_stylebox_override("hover", _style(fill.lightened(0.12), GOLD, 2, 6))
	button.add_theme_stylebox_override("pressed", _style(fill.darkened(0.1), GOLD, 2, 6))
	button.add_theme_stylebox_override("disabled", _style(Color("282522"), Color("3a3733"), 1, 6))
	return button

func _mini_badge(text_value: String, fill: Color, color: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(58, 26)
	button.flat = false
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", color)
	button.add_theme_stylebox_override("normal", _style(fill, fill.lightened(0.15), 1, 4))
	button.add_theme_stylebox_override("hover", _style(fill.lightened(0.12), color, 1, 4))
	return button

func _texture_rect(texture: Texture2D, position_value: Vector2, size_value: Vector2, layer: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.position = position_value
	rect.size = size_value
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.z_index = layer
	_board.add_child(rect)
	return rect

func _texture_button(texture: Texture2D, position_value: Vector2, size_value: Vector2, layer: int) -> Button:
	var button := Button.new()
	button.position = position_value
	button.size = size_value
	button.icon = texture
	button.expand_icon = true
	button.flat = true
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.z_index = layer
	_board.add_child(button)
	return button

func _build_pile_button(texture: Texture2D, position_value: Vector2, size_value: Vector2, tooltip: String, callback: Callable) -> void:
	var button := _texture_button(texture, position_value, size_value, 20)
	button.tooltip_text = tooltip
	button.pressed.connect(callback)

func _build_pile_count_label(position_value: Vector2, tooltip: String) -> Label:
	var label := _label("0", 13, PAPER)
	label.position = position_value
	label.size = Vector2(60, 24)
	label.z_index = 34
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.tooltip_text = tooltip
	_board.add_child(label)
	return label

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
