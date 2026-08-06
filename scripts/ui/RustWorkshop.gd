extends Control

const CardDataRef:=preload("res://scripts/resources/CardData.gd")
const PlayerCardRef:=preload("res://scripts/resources/PlayerCardData.gd")
var _content:Control
var _currency:Label
var _tab:="opponents"

const TECH_NODES:Array[Dictionary]=[
	{"id":"prep_gold_1","name":"行前资金Ⅰ","cost":1,"parent":"","desc":"每盘初始金币+5"},
	{"id":"prep_free_refresh","name":"免费刷新","cost":2,"parent":"prep_gold_1","desc":"行前商店首次刷新免费"},
	{"id":"prep_starter_swap","name":"基础替换","cost":3,"parent":"prep_free_refresh","desc":"初始牌组可替换1张基础牌"},
	{"id":"prep_gold_2","name":"行前资金Ⅱ","cost":4,"parent":"prep_starter_swap","desc":"每盘初始金币再+5"},
	{"id":"cards_rare","name":"稀有研究","cost":2,"parent":"","desc":"稀有研究牌加入卡池"},
	{"id":"cards_wealth","name":"财富研究","cost":3,"parent":"cards_rare","desc":"财富牌加入卡池"},
	{"id":"cards_legendary","name":"传说研究","cost":5,"parent":"cards_wealth","desc":"传说研究牌加入卡池"},
	{"id":"cards_forbidden","name":"禁忌扩展","cost":4,"parent":"cards_legendary","desc":"禁忌卡扩展加入卡池"},
	{"id":"archive_common","name":"普通档案","cost":1,"parent":"","desc":"解锁后续普通角色"},
	{"id":"archive_rare","name":"稀有档案","cost":2,"parent":"archive_common","desc":"解锁后续稀有角色"},
	{"id":"archive_epic","name":"史诗档案","cost":3,"parent":"archive_rare","desc":"解锁后续史诗角色"},
	{"id":"archive_legendary","name":"传说档案","cost":4,"parent":"archive_epic","desc":"解锁后续传说角色"},
]

func _ready()->void:set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);_build()

func _build()->void:
	for child in get_children():child.queue_free()
	var bg:=ColorRect.new();bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);bg.color=Color(0.025,0.025,0.045);add_child(bg)
	var title:=_label("锈铁工坊",34,Color(0.93,0.74,0.3));title.position=Vector2(35,22);title.size=Vector2(360,50);add_child(title)
	_currency=_label("锈点 %d　科技点 %d"%[GameState.rust_points,GameState.tech_points],20,Color(0.55,0.85,0.8));_currency.position=Vector2(850,30);_currency.size=Vector2(350,40);_currency.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;add_child(_currency)
	var opp:=Button.new();opp.text="对手强化";opp.position=Vector2(35,88);opp.size=Vector2(180,45);opp.pressed.connect(func():_tab="opponents";_draw_content());add_child(opp)
	var tech:=Button.new();tech.text="科技树";tech.position=Vector2(230,88);tech.size=Vector2(180,45);tech.pressed.connect(func():_tab="tech";_draw_content());add_child(tech)
	var back:=Button.new();back.text="返回";back.position=Vector2(1080,650);back.size=Vector2(160,45);back.pressed.connect(func():get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn"));add_child(back)
	var scroll:=ScrollContainer.new();scroll.position=Vector2(35,150);scroll.size=Vector2(1205,480);add_child(scroll);_content=VBoxContainer.new();_content.custom_minimum_size=Vector2(1170,460);scroll.add_child(_content);_draw_content()

func _draw_content()->void:
	for child in _content.get_children():child.queue_free()
	if _tab=="opponents":_draw_opponents()
	else:_draw_tech()

func _draw_opponents()->void:
	var grid:=GridContainer.new();grid.columns=4;grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",12);_content.add_child(grid)
	for card in CardDataRef.get_all_cards():
		if card.rarity==CardData.Rarity.UNKNOWN:continue
		var level:=GameState.get_card_level(card.card_id);var maximum:=GameState.get_max_level_for_card(card.card_id);var cost:=GameState.get_next_card_level_cost(card.card_id)
		var panel:=PanelContainer.new();panel.custom_minimum_size=Vector2(280,180);grid.add_child(panel);var box:=VBoxContainer.new();panel.add_child(box)
		var name:=_label("%s　%s"%[card.card_name,card.get_rarity_name()],18,card.get_rarity_color());box.add_child(name)
		box.add_child(_label("等级 Lv.%d / Lv.%d"%[level,maximum],16,Color(0.8,0.82,0.85)))
		var desc:=_label(card.skill_desc,12,Color(0.66,0.68,0.72));desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;desc.custom_minimum_size=Vector2(255,70);box.add_child(desc)
		var upgrade:=Button.new();upgrade.text="已满级" if level>=maximum else "强化全部技能 · %d锈点"%cost;upgrade.disabled=level>=maximum or GameState.rust_points<cost;upgrade.pressed.connect(_upgrade.bind(card.card_id));box.add_child(upgrade)

func _upgrade(card_id:String)->void:
	if GameState.upgrade_card(card_id):_refresh_currency();_draw_content()

func _draw_tech()->void:
	var note:=_label("强化一张对手卡可获得1科技点。科技确认后不可退款。",17,Color(0.75,0.77,0.8));_content.add_child(note)
	var grid:=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",18);grid.add_theme_constant_override("v_separation",14);_content.add_child(grid)
	for node in TECH_NODES:
		var owned:bool=str(node.id) in GameState.purchased_tech_nodes;var parent_ok:bool=str(node.parent).is_empty() or str(node.parent) in GameState.purchased_tech_nodes
		var button:=Button.new();button.custom_minimum_size=Vector2(365,92);button.text="%s%s\n%s\n%d科技点"%["✓ " if owned else "",node.name,node.desc,node.cost];button.disabled=owned or not parent_ok or GameState.tech_points<int(node.cost);button.pressed.connect(_buy_tech.bind(node));grid.add_child(button)

func _buy_tech(node:Dictionary)->void:
	if not GameState.purchase_tech(str(node.id),int(node.cost)):return
	if str(node.id)=="cards_rare":
		for card in PlayerCardRef.get_pool(PlayerCardData.Rarity.RARE):if card.card_id not in GameState.unlocked_player_cards:GameState.unlocked_player_cards.append(card.card_id)
	elif str(node.id)=="cards_legendary" or str(node.id)=="cards_forbidden":
		for card in PlayerCardRef.get_pool(PlayerCardData.Rarity.LEGENDARY):if card.card_id not in GameState.unlocked_player_cards:GameState.unlocked_player_cards.append(card.card_id)
	elif str(node.id)=="archive_common":_unlock_opponent("signal_noise")
	elif str(node.id)=="archive_rare":pass # 首版三张稀有角色均为基础解锁
	elif str(node.id)=="archive_epic":_unlock_opponent("mirror_tech");_unlock_opponent("table_ghost")
	elif str(node.id)=="archive_legendary":_unlock_opponent("dealer")
	GameState.save_progress();_refresh_currency();_draw_content()

func _unlock_opponent(card_id:String)->void:
	if card_id not in GameState.unlocked_cards:GameState.unlocked_cards.append(card_id)

func _refresh_currency()->void:_currency.text="锈点 %d　科技点 %d"%[GameState.rust_points,GameState.tech_points]
func _label(text:String,size_value:int,color:Color)->Label:var l:=Label.new();l.text=text;l.add_theme_font_size_override("font_size",size_value);l.add_theme_color_override("font_color",color);return l
