extends Control

const PlayerCardRef := preload("res://scripts/resources/PlayerCardData.gd")
const BossFragmentRef := preload("res://scripts/resources/BossFragmentData.gd")

var _game: DiceGame
var _flow: Node
var _cards: Array = []
var _is_boss := false
var _stage_index := 0
var _pending_hand_index := -1
var _latest_state: Dictionary = {}
var _score_label: Label
var _preview_label: Label
var _round_label: Label
var _enemy_row: HBoxContainer
var _dice_row: HBoxContainer
var _hand_row: HBoxContainer
var _pile_label: Label
var _log_label: RichTextLabel
var _confirm_button: Button
var _tutorial_panel: PanelContainer
var _fragment_row: HBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func setup_with_flow(stage_data: Resource, flow: Node, cards: Variant = null) -> void:
	_flow = flow
	_cards = cards if cards is Array else []
	_stage_index = clampi(GameState.current_stage, 0, 3)
	_is_boss = _cards.size() >= 3 or (flow != null and flow.get("_is_boss_node") == true)
	_build_ui()
	_game = get_node_or_null("DiceGame") as DiceGame
	if _game == null:
		_game = DiceGame.new(); _game.name = "DiceGame"; add_child(_game)
	_game.state_changed.connect(_on_state_changed)
	_game.message_posted.connect(_on_message)
	_game.battle_finished.connect(_on_battle_finished)
	var normal_index := 0
	if flow != null and flow.has_method("get_current_normal_battle_index"):
		normal_index = flow.get_current_normal_battle_index()
	_game.configure(_stage_index, _cards, _is_boss, normal_index)
	if GameState.tutorial_enabled and not GameState.tutorial_completed:
		_show_tutorial("先看骰子与预计分数。点击卡牌会改变骰子或计分，但每用一张牌都会推进敌方倒计时。")

func _build_ui() -> void:
	for child in get_children():
		if child.name != "DiceGame": child.queue_free()
	var bg := ColorRect.new(); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); bg.color = Color(0.035,0.027,0.022); bg.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(bg)
	var title := _label("突破轮回 · 计分战", 24, Color(0.94,0.76,0.34)); title.position=Vector2(28,14); title.size=Vector2(350,40); add_child(title)
	var score_panel := _panel(Vector2(28,62),Vector2(390,155)); add_child(score_panel)
	_score_label=_label("累计 0 / 0",28,Color(1,0.79,0.25));_score_label.position=Vector2(18,14);_score_label.size=Vector2(350,42);score_panel.add_child(_score_label)
	_preview_label=_label("预计：0 × 1 = 0",20,Color(0.84,0.87,0.9));_preview_label.position=Vector2(18,62);_preview_label.size=Vector2(350,32);score_panel.add_child(_preview_label)
	var rules:=Button.new();rules.text="查看计分规则";rules.position=Vector2(18,105);rules.size=Vector2(160,34);rules.pressed.connect(_show_score_rules);score_panel.add_child(rules)
	_round_label=_label("第1/5轮",18,Color(0.72,0.78,0.84));_round_label.position=Vector2(220,108);_round_label.size=Vector2(145,30);score_panel.add_child(_round_label)
	var enemy_panel:=_panel(Vector2(440,62),Vector2(812,238));add_child(enemy_panel)
	_enemy_row=HBoxContainer.new();_enemy_row.position=Vector2(16,16);_enemy_row.size=Vector2(780,206);_enemy_row.add_theme_constant_override("separation",14);enemy_panel.add_child(_enemy_row)
	var log_panel:=_panel(Vector2(28,230),Vector2(390,180));add_child(log_panel)
	_log_label=RichTextLabel.new();_log_label.bbcode_enabled=true;_log_label.position=Vector2(14,12);_log_label.size=Vector2(362,152);_log_label.fit_content=false;_log_label.scroll_active=true;log_panel.add_child(_log_label)
	var dice_panel:=_panel(Vector2(440,318),Vector2(812,140));add_child(dice_panel)
	_dice_row=HBoxContainer.new();_dice_row.position=Vector2(20,24);_dice_row.size=Vector2(770,94);_dice_row.alignment=BoxContainer.ALIGNMENT_CENTER;_dice_row.add_theme_constant_override("separation",12);dice_panel.add_child(_dice_row)
	var hand_panel:=_panel(Vector2(28,474),Vector2(1010,220));add_child(hand_panel)
	var scroll:=ScrollContainer.new();scroll.position=Vector2(12,12);scroll.size=Vector2(986,176);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;hand_panel.add_child(scroll)
	_hand_row=HBoxContainer.new();_hand_row.custom_minimum_size=Vector2(970,170);_hand_row.add_theme_constant_override("separation",8);scroll.add_child(_hand_row)
	_pile_label=_label("抽牌 0　弃牌 0",16,Color(0.66,0.69,0.73));_pile_label.position=Vector2(16,190);_pile_label.size=Vector2(600,26);hand_panel.add_child(_pile_label)
	_confirm_button=Button.new();_confirm_button.text="确认计分";_confirm_button.position=Vector2(1054,500);_confirm_button.size=Vector2(190,92);_confirm_button.add_theme_font_size_override("font_size",25);_confirm_button.pressed.connect(_on_confirm);add_child(_confirm_button)
	var review:=Button.new();review.text="教程回顾";review.position=Vector2(1054,610);review.size=Vector2(190,46);review.pressed.connect(func():_tutorial_panel.visible=not _tutorial_panel.visible);add_child(review)
	_fragment_row=HBoxContainer.new();_fragment_row.position=Vector2(28,420);_fragment_row.size=Vector2(390,42);_fragment_row.add_theme_constant_override("separation",8);add_child(_fragment_row)
	for fragment_id in GameState.boss_fragments:
		var fragment_button:=Button.new();fragment_button.text=BossFragmentRef.get_fragment_name(fragment_id);fragment_button.custom_minimum_size=Vector2(118,38);fragment_button.pressed.connect(_on_fragment_pressed.bind(fragment_id));_fragment_row.add_child(fragment_button)
	_tutorial_panel=PanelContainer.new();_tutorial_panel.position=Vector2(720,80);_tutorial_panel.size=Vector2(500,210);_tutorial_panel.z_index=300;_tutorial_panel.visible=false;add_child(_tutorial_panel)

func _on_state_changed(state: Dictionary) -> void:
	_latest_state=state
	_score_label.text="累计 %d / %d%s"%[state.total,state.target,"　阶段%d"%state.phase if int(state.phase)>1 else ""]
	var preview:Dictionary=state.preview
	_preview_label.text="预计：%d × %d%s = %d"%[preview.get("base",0),preview.get("multiplier",1)," ×%d"%preview.get("final_factor",1) if int(preview.get("final_factor",1))>1 else "",preview.get("score",0)]
	_round_label.text="第%d / %d轮"%[state.round,state.max_rounds]
	_pile_label.text="抽牌 %d　弃牌 %d　移出 %d　手牌 %d/%d"%[state.draw_count,state.discard_count,state.exhaust_count,state.hand.size(),state.hand_limit]
	_confirm_button.disabled=bool(state.over)
	_rebuild_enemies(state.enemies)
	_rebuild_dice(state.dice)
	_rebuild_hand(state.hand,state.retained)

func _rebuild_enemies(enemies:Array)->void:
	_clear(_enemy_row)
	for enemy in enemies:
		var panel:=PanelContainer.new();panel.custom_minimum_size=Vector2(245,198);_enemy_row.add_child(panel)
		var box:=VBoxContainer.new();box.add_theme_constant_override("separation",5);panel.add_child(box)
		var name:=_label("%s　[%s]"%[enemy.name,enemy.rarity],18,enemy.color);box.add_child(name)
		var current:Dictionary=enemy.current
		var intent_row:=HBoxContainer.new();box.add_child(intent_row)
		intent_row.add_child(_label("当前：%s　"%current.get("name",""),16,Color.WHITE))
		var timer:=_label(str(enemy.timer),18,Color(1,0.3,0.3));timer.tooltip_text="预计影响%d个目标。"%enemy.ratio_count;intent_row.add_child(timer)
		var desc:=_label(str(current.get("desc","")),14,Color(0.82,0.79,0.74));desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;desc.custom_minimum_size=Vector2(220,65);box.add_child(desc)
		var next:Dictionary=enemy.next;box.add_child(_label("下一步：%s（%d）"%[next.get("name",""),next.get("countdown",0)],14,Color(0.56,0.72,0.82)))
		var next_two:Dictionary=enemy.get("next_two",{})
		if not next_two.is_empty():box.add_child(_label("下下步：%s"%next_two.get("name",""),12,Color(0.46,0.62,0.72)))

func _rebuild_dice(dice:Array)->void:
	_clear(_dice_row)
	for i in range(dice.size()):
		var die:Dictionary=dice[i];var b:=Button.new();b.custom_minimum_size=Vector2(70,78);b.text="?" if bool(die.hidden) else str(die.value);b.add_theme_font_size_override("font_size",30)
		if bool(die.locked):b.text+="\n🔒"
		if bool(die.protected):b.text+="\n盾"
		if bool(die.get("player_blocked",false)):b.text+="\n禁"
		b.pressed.connect(_on_die_clicked.bind(i));_dice_row.add_child(b)

func _rebuild_hand(cards:Array,retained:Array)->void:
	_clear(_hand_row)
	for i in range(cards.size()):
		var entry:Dictionary=cards[i];var card:PlayerCardData=PlayerCardRef.get_by_id(str(entry.id));if card==null:continue
		var b:=Button.new();b.custom_minimum_size=Vector2(138,166);b.text="%s\n[%s·%s]\n\n%s%s"%[card.card_name,card.get_rarity_name(),card.category,card.description,"\n【保留】" if i in retained else ""];b.add_theme_font_size_override("font_size",13);b.tooltip_text="左键使用；右键标记本轮保留牌。";b.pressed.connect(_on_card_clicked.bind(i));b.gui_input.connect(_on_card_gui_input.bind(i));_hand_row.add_child(b)

func _on_card_clicked(index:int)->void:
	var result:=_game.request_use_card(index)
	if bool(result.get("needs_target",false)):
		_pending_hand_index=index;_on_message("请选择骰子作为【%s】的目标"%PlayerCardRef.get_by_id(str(_latest_state.hand[index].id)).card_name,Color(0.45,0.8,0.95))
	elif not bool(result.get("ok",false)):_on_message(str(result.get("error","无法使用")),Color(0.95,0.4,0.4))

func _on_die_clicked(index:int)->void:
	if _pending_hand_index<0:return
	var result:=_game.request_use_card(_pending_hand_index,index);_pending_hand_index=-1
	if not bool(result.get("ok",false)):_on_message(str(result.get("error","无法使用")),Color(0.95,0.4,0.4))

func _on_card_gui_input(event:InputEvent,index:int)->void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:_game.toggle_retain(index)

func _on_confirm()->void:_pending_hand_index=-1;_game.confirm_score()
func _on_fragment_pressed(fragment_id:String)->void:
	var result:=_game.use_fragment(fragment_id,0)
	if not bool(result.get("ok",false)):_on_message(str(result.get("error","当前无法使用")),Color(0.95,0.4,0.4))
func _on_message(text:String,color:Color)->void:
	_log_label.append_text("[color=#%s]%s[/color]\n"%[color.to_html(false),text]);_log_label.scroll_to_line(_log_label.get_line_count())

func _on_battle_finished(victory:bool,rounds:int)->void:
	var layer:=CanvasLayer.new();layer.layer=500;add_child(layer)
	var dim:=ColorRect.new();dim.color=Color(0,0,0,0.9);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(dim)
	var panel:=_panel(Vector2(340,165),Vector2(600,390));dim.add_child(panel)
	var title:=_label("胜利" if victory else "完全同化",42,Color(1,0.75,0.22) if victory else Color(0.95,0.25,0.32));title.position=Vector2(20,35);title.size=Vector2(560,60);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;panel.add_child(title)
	var text:=_label("累计得分 %d / %d\n使用 %d 个计分轮"%[_latest_state.total,_latest_state.target,rounds] if victory else "本盘挑战结束。已获得的永久锈点与科技解锁会保留。",20,Color(0.85,0.85,0.82));text.position=Vector2(55,120);text.size=Vector2(490,100);text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;panel.add_child(text)
	var button:=Button.new();button.text="领取奖励" if victory else "返回主菜单";button.position=Vector2(170,275);button.size=Vector2(260,58);button.pressed.connect(func():
		if victory: EventBus.node_completed.emit("boss" if _is_boss else "battle")
		elif _flow and _flow.has_method("handle_event_death"):_flow.handle_event_death()
		else:get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
		queue_free());panel.add_child(button)

func _show_score_rules()->void:
	var layer:=CanvasLayer.new();layer.layer=400;add_child(layer);var dim:=ColorRect.new();dim.color=Color(0,0,0,0.88);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(dim)
	var panel:=_panel(Vector2(250,90),Vector2(780,540));dim.add_child(panel);var text:=_label("计分规则\n\n本轮得分 = 基础点数 × 倍率 × 最终倍率\n基础点数：骰子点数之和 + 卡牌加成\n对子 +1、三条 +3、四条 +6、五条 +10、六条 +15\n三连顺 +2、四连顺 +4、五连顺 +7、六连顺 +11\n\n系统按合法骰型拆分选择最高分方案；同分时选择倍率更高、参与骰子更多的方案。",20,Color(0.9,0.88,0.82));text.position=Vector2(50,40);text.size=Vector2(680,380);text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;panel.add_child(text);var close:=Button.new();close.text="关闭";close.position=Vector2(290,460);close.size=Vector2(200,48);close.pressed.connect(layer.queue_free);panel.add_child(close)

func _show_tutorial(text:String)->void:
	_clear(_tutorial_panel);var label:=_label("教程\n\n"+text+"\n\n右键手牌可标记本轮保留；每轮最多保留1张。",17,Color(0.9,0.88,0.75));label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.custom_minimum_size=Vector2(460,180);_tutorial_panel.add_child(label);_tutorial_panel.visible=true
func _panel(pos:Vector2,size_value:Vector2)->PanelContainer:
	var p:=PanelContainer.new();p.position=pos;p.size=size_value;var box:=StyleBoxFlat.new();box.bg_color=Color(0.08,0.065,0.055,0.96);box.border_color=Color(0.45,0.32,0.18);box.set_border_width_all(2);box.corner_radius_top_left=6;box.corner_radius_top_right=6;box.corner_radius_bottom_left=6;box.corner_radius_bottom_right=6;p.add_theme_stylebox_override("panel",box);return p
func _label(text:String,size_value:int,color:Color)->Label:
	var l:=Label.new();l.text=text;l.add_theme_font_size_override("font_size",size_value);l.add_theme_color_override("font_color",color);return l
func _clear(node:Node)->void:
	for child in node.get_children():child.queue_free()
