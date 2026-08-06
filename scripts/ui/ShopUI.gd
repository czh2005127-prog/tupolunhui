extends Control

const PlayerCardRef := preload("res://scripts/resources/PlayerCardData.gd")

var _flow: Node
var _page := "packs"
var _pack_stock: Array[Dictionary] = []
var _single_stock: Array[Dictionary] = []
var _refresh_counts := {"packs":0,"singles":0}
var _gamble_plays := 0
var _free_refresh_available:=false
var _content: GridContainer
var _gold_label: Label
var _status: Label
var _tabs: HBoxContainer

func set_parent_flow(flow:Node)->void:_flow=flow

func _ready()->void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_free_refresh_available=bool(GameState.next_battle_modifiers.get("free_shop_refresh",false)) or "prep_free_refresh" in GameState.purchased_tech_nodes
	_generate_stocks();_build()
	EventBus.shop_entered.emit()

func _generate_stocks()->void:
	_generate_pack_stock();_generate_single_stock()

func _generate_pack_stock()->void:
	_pack_stock=[_make_pack("普通卡包",28,"normal"),_make_pack("高级卡包",45,"advanced"),_make_pack("禁忌混合包",34,"forbidden")]
	var advanced_chance: float = float([0.2,0.3,0.4,0.5][clampi(GameState.current_stage,0,3)])
	for _i in range(3):
		var advanced: bool = randf() < advanced_chance
		_pack_stock.append(_make_pack("高级卡包" if advanced else "普通卡包",45 if advanced else 28,"advanced" if advanced else "normal"))
	_pack_stock.shuffle()

func _generate_single_stock()->void:
	_single_stock.clear()
	var all:=PlayerCardRef.get_all_cards();all.shuffle()
	for i in range(6):
		var card:PlayerCardData=all[i];_single_stock.append({"kind":"single","name":card.card_name,"price":[8,20,48][int(card.rarity)],"card_id":card.card_id,"sold":false})

func _make_pack(name:String,price:int,grade:String)->Dictionary:
	var cards:Array[String]=[];var count:=2 if grade=="forbidden" else 6
	var themes:=["骰子","骰型","点数","倍率","防护","牌库","金币"]
	var theme:String="混合" if grade=="forbidden" else str(themes[randi()%themes.size()])
	for _i in range(count):
		var roll:=randf();var rarity:=0
		if grade=="normal":rarity=2 if roll>=0.98 else (1 if roll>=0.82 else 0)
		elif grade=="advanced":rarity=2 if roll>=0.85 else (1 if roll>=0.35 else 0)
		else:rarity=2 if roll>=0.85 else 1
		var pool:Array=PlayerCardRef.get_pool(rarity);var themed:Array=[]
		if theme!="混合" and randf()<0.8:
			for card in pool:
				if card.category==theme:themed.append(card)
		if not themed.is_empty():pool=themed
		cards.append(pool[randi()%pool.size()].card_id)
	return {"kind":"pack","grade":grade,"name":"%s·%s"%[theme,name] if theme!="混合" else name,"price":price,"cards":cards,"sold":false}

func _build()->void:
	for child in get_children():child.queue_free()
	var bg:=ColorRect.new();bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);bg.color=Color(0.035,0.026,0.02);add_child(bg)
	var title:=_label("木盒商店",32,Color(0.96,0.76,0.31));title.position=Vector2(40,24);title.size=Vector2(350,48);add_child(title)
	_gold_label=_label("金币：%d"%GameState.gold,23,Color(0.95,0.78,0.3));_gold_label.position=Vector2(995,30);_gold_label.size=Vector2(230,38);_gold_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;add_child(_gold_label)
	_tabs=HBoxContainer.new();_tabs.position=Vector2(40,92);_tabs.size=Vector2(500,52);_tabs.add_theme_constant_override("separation",12);add_child(_tabs)
	var pack_btn:=Button.new();pack_btn.text="卡包";pack_btn.custom_minimum_size=Vector2(180,48);pack_btn.pressed.connect(func():_page="packs";_draw_stock());_tabs.add_child(pack_btn)
	var single_btn:=Button.new();single_btn.text="单卡";single_btn.custom_minimum_size=Vector2(180,48);single_btn.pressed.connect(func():_page="singles";_draw_stock());_tabs.add_child(single_btn)
	_content=GridContainer.new();_content.columns=3;_content.position=Vector2(40,165);_content.size=Vector2(1200,400);_content.add_theme_constant_override("h_separation",18);_content.add_theme_constant_override("v_separation",18);add_child(_content)
	var refresh:=Button.new();refresh.position=Vector2(40,610);refresh.size=Vector2(210,52);refresh.pressed.connect(_refresh_page);add_child(refresh);refresh.name="RefreshButton"
	var gamble:=Button.new();gamble.text="店内骰桌";gamble.position=Vector2(285,610);gamble.size=Vector2(210,52);gamble.pressed.connect(_open_gamble);add_child(gamble)
	var leave:=Button.new();leave.text="离开商店";leave.position=Vector2(1010,610);leave.size=Vector2(220,52);leave.pressed.connect(_leave);add_child(leave)
	_status=_label("行前可以保留金币，也可以现在补强牌库。",16,Color(0.7,0.72,0.75));_status.position=Vector2(530,620);_status.size=Vector2(450,35);add_child(_status)
	_draw_stock()

func _draw_stock()->void:
	for child in _content.get_children():child.queue_free()
	var stock:=_pack_stock if _page=="packs" else _single_stock
	for i in range(stock.size()):
		var item:Dictionary=stock[i];var panel:=PanelContainer.new();panel.custom_minimum_size=Vector2(380,185);_content.add_child(panel)
		var box:=VBoxContainer.new();box.add_theme_constant_override("separation",8);panel.add_child(box)
		var name:=_label(str(item.name),21,Color(0.93,0.8,0.47));name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;box.add_child(name)
		if item.kind=="pack":box.add_child(_label("内含%d张牌 · 允许重复"%item.cards.size(),15,Color(0.74,0.75,0.77)))
		else:
			var card:=PlayerCardRef.get_by_id(str(item.card_id));var desc:=_label(card.description,14,card.get_rarity_color());desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;desc.custom_minimum_size=Vector2(340,60);box.add_child(desc)
		var price:=_effective_price(int(item.price));var buy:=Button.new();buy.text="已售罄" if bool(item.sold) else "购买 · %d金币"%price;buy.disabled=bool(item.sold) or GameState.gold<price;buy.custom_minimum_size=Vector2(340,44);buy.pressed.connect(_buy.bind(i));box.add_child(buy)
	var refresh:Button=get_node("RefreshButton");var refresh_price:=0 if _free_refresh_available else _refresh_cost();refresh.text="刷新本页 · %d金币"%refresh_price;refresh.disabled=GameState.gold<refresh_price

func _buy(index:int)->void:
	var stock:=_pack_stock if _page=="packs" else _single_stock
	if index<0 or index>=stock.size():return
	var item:Dictionary=stock[index]
	if bool(item.sold) or not GameState.spend_gold(_effective_price(int(item.price))):return
	item.sold=true;stock[index]=item
	if item.kind=="pack":
		_status.text="打开%s：%s"%[item.name,", ".join(_names_for_ids(item.cards))]
		for id in item.cards:await _acquire_card(str(id))
	else:await _acquire_card(str(item.card_id));_status.text="获得单卡【%s】"%item.name
	_gold_label.text="金币：%d"%GameState.gold;_draw_stock();GameState.save_run()

func _acquire_card(id:String)->void:
	if GameState.add_player_card(id):return
	var resolved:=[false]
	var layer:=CanvasLayer.new();layer.layer=300;add_child(layer);var dim:=ColorRect.new();dim.color=Color(0,0,0,0.94);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(dim)
	var title:=_label("牌库已满：选择一张替换为【%s】"%PlayerCardRef.get_by_id(id).card_name,24,Color(1,0.73,0.25));title.position=Vector2(180,65);title.size=Vector2(920,45);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;dim.add_child(title)
	var scroll:=ScrollContainer.new();scroll.position=Vector2(120,130);scroll.size=Vector2(1040,430);dim.add_child(scroll);var grid:=GridContainer.new();grid.columns=5;scroll.add_child(grid)
	for i in range(GameState.player_deck.size()):
		var old:=PlayerCardRef.get_by_id(GameState.player_deck[i]);var b:=Button.new();b.text="%s\n%s"%[old.card_name,old.get_rarity_name()];b.custom_minimum_size=Vector2(190,80);b.pressed.connect(func(index:int=i):GameState.player_deck[index]=id;layer.queue_free();resolved[0]=true);grid.add_child(b)
	var discard:=Button.new();discard.text="丢弃新卡";discard.position=Vector2(510,595);discard.size=Vector2(260,50);discard.pressed.connect(func():layer.queue_free();resolved[0]=true);dim.add_child(discard)
	while not resolved[0]:await get_tree().process_frame

func _refresh_page()->void:
	var cost:=0 if _free_refresh_available else _refresh_cost();if not GameState.spend_gold(cost):return
	_free_refresh_available=false
	_refresh_counts[_page]=int(_refresh_counts[_page])+1
	if _page=="packs":_generate_pack_stock()
	else:
		_generate_single_stock()
	_gold_label.text="金币：%d"%GameState.gold;_draw_stock()

func _refresh_cost()->int:
	var n:=int(_refresh_counts[_page]);return [5,10,15,20][n] if n<4 else 20+(n-3)*5

func _effective_price(base:int)->int:
	var multiplier:=1.2 if "greedy_box" in GameState.active_forbidden_rules else 1.0
	multiplier+=float(GameState.next_battle_modifiers.get("shop_price_bonus",0))/100.0
	return ceili(base*multiplier)

func _open_gamble()->void:
	if _gamble_plays>=2:_status.text="本商店已经玩过两次。";return
	var cost:=5 if _gamble_plays==0 else 10
	if GameState.gold<cost:_status.text="金币不足。";return
	GameState.spend_gold(cost);_gamble_plays+=1
	var layer:=CanvasLayer.new();layer.layer=250;add_child(layer);var dim:=ColorRect.new();dim.color=Color(0,0,0,0.9);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(dim)
	var text:=_label("投入%d金币：选择玩法"%cost,26,Color(0.94,0.76,0.3));text.position=Vector2(390,180);text.size=Vector2(500,50);text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;dim.add_child(text)
	var big:=Button.new();big.text="猜大（④⑤⑥）· 返还125%";big.position=Vector2(300,300);big.size=Vector2(300,60);big.pressed.connect(_resolve_gamble.bind(layer,cost,"big",0));dim.add_child(big)
	var small:=Button.new();small.text="猜小（①②③）· 返还125%";small.position=Vector2(680,300);small.size=Vector2(300,60);small.pressed.connect(_resolve_gamble.bind(layer,cost,"small",0));dim.add_child(small)
	for face in range(1,7):var b:=Button.new();b.text=str(face);b.position=Vector2(330+(face-1)*105,410);b.size=Vector2(82,54);b.pressed.connect(_resolve_gamble.bind(layer,cost,"exact",face));dim.add_child(b)

func _resolve_gamble(layer:CanvasLayer,cost:int,mode:String,guess:int)->void:
	var value:=randi_range(1,6);var won:=(mode=="big" and value>=4) or (mode=="small" and value<=3) or (mode=="exact" and value==guess)
	var payout:=ceili(cost*(1.5 if mode=="exact" else 1.25)) if won else 0
	if payout>0:GameState.add_gold(payout)
	_status.text="骰出%d：%s"%[value,"赢得%d金币"%payout if won else "投入未返还"]
	layer.queue_free();_gold_label.text="金币：%d"%GameState.gold;_draw_stock();GameState.save_run()

func _leave()->void:GameState.save_run();EventBus.shop_exited.emit();queue_free()
func _names_for_ids(ids:Array)->Array[String]:
	var result:Array[String]=[]
	for id in ids:
		result.append(PlayerCardRef.get_by_id(str(id)).card_name)
	return result
func _label(text:String,size_value:int,color:Color)->Label:var l:=Label.new();l.text=text;l.add_theme_font_size_override("font_size",size_value);l.add_theme_color_override("font_color",color);return l
