extends Control

const PlayerCardRef:=preload("res://scripts/resources/PlayerCardData.gd")
var _flow:Node
var _event:Dictionary={}

func set_parent_flow(flow:Node)->void:_flow=flow
func _ready()->void:set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);_pick_event();_build()

func _pick_event()->void:
	var pool:Array[Dictionary]=[
		{"id":"scrap","title":"废弃零件堆","story":"生锈的零件中夹着几张尚未失去温度的牌。","a":"拿走10金币","b":"从3张普通牌中选1张"},
		{"id":"black_market","title":"黑市贩子","story":"蒙面贩子把三张蓝光卡推到桌边。","a":"支付12金币选1张稀有牌","b":"拿走8金币","stage":1},
		{"id":"rust_furnace","title":"锈蚀熔炉","story":"炉火能烧掉累赘，也能把凡铁熔成另一种形状。","a":"支付8金币，移除至多2张牌","b":"将1张普通牌随机转成稀有牌"},
		{"id":"wild_die","title":"失控骰子","story":"一颗骰子撞击盒壁，像在寻找出口。","a":"下一战+1骰，敌人倒计时-1","b":"拿走14金币"},
		{"id":"memory","title":"记忆残片","story":"前一位挑战者把最后一个念头压进了卡面。","a":"选择1张牌进入下一战初始手牌","b":"下一商店首次刷新免费"},
		{"id":"clock","title":"故障时钟","story":"两根指针分别指向谨慎与贪婪。","a":"敌人倒计时+1，初始手牌5","b":"初始手牌7，敌人倒计时-1"},
		{"id":"crack","title":"裂缝赌局","story":"裂缝另一侧传来金币滚动的声音。","a":"支付10金币，50%获得28","b":"获得6金币"},
		{"id":"forbidden_supply","title":"禁忌补给","story":"紫黑色卡包像心脏一样轻微跳动。","a":"获得禁忌包，下一战手牌上限8","b":"获得15金币","stage":1},
		{"id":"echo_printer","title":"回声打印机","story":"机器愿意复写一张牌，也愿意吞掉一张。","a":"复制1张普通/稀有牌","b":"移除1张牌","stage":1},
		{"id":"archive","title":"破损档案","story":"档案只剩两页还能辨认。","a":"下次抽牌揭示未知卡","b":"下一战显示敌人前三项技能"},
	]
	var available:Array[Dictionary]=[]
	for event in pool:
		if int(event.get("stage",0))<=GameState.current_stage and str(event.id) not in GameState.event_ids_seen_this_run:available.append(event)
	if available.is_empty():available=pool
	_event=available[randi()%available.size()];GameState.event_ids_seen_this_run.append(str(_event.id))

func _build()->void:
	var bg:=ColorRect.new();bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);bg.color=Color(0.025,0.02,0.035);add_child(bg)
	var title:=_label(str(_event.title),36,Color(0.9,0.7,0.3));title.position=Vector2(240,90);title.size=Vector2(800,60);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;add_child(title)
	var story:=_label(str(_event.story),20,Color(0.76,0.74,0.72));story.position=Vector2(250,175);story.size=Vector2(780,90);story.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;story.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(story)
	var a:=Button.new();a.text=str(_event.a);a.position=Vector2(170,340);a.size=Vector2(420,110);a.pressed.connect(_choose.bind(true));add_child(a)
	var b:=Button.new();b.text=str(_event.b);b.position=Vector2(690,340);b.size=Vector2(420,110);b.pressed.connect(_choose.bind(false));add_child(b)

func _choose(first:bool)->void:
	match str(_event.id):
		"scrap":
			if first:GameState.add_gold(10)
			else:await _add_random_card(PlayerCardData.Rarity.COMMON)
		"black_market":
			if first and GameState.spend_gold(12):await _add_random_card(PlayerCardData.Rarity.RARE)
			elif not first:GameState.add_gold(8)
		"rust_furnace":
			if first and GameState.spend_gold(8):_remove_cards(2)
			elif not first:_transform_common()
		"wild_die":
			if first:GameState.next_battle_modifiers.bonus_dice=1;GameState.next_battle_modifiers.enemy_timer_bonus=-1
			else:GameState.add_gold(14)
		"memory":
			if first and not GameState.player_deck.is_empty():GameState.next_battle_modifiers.guaranteed_card=GameState.player_deck[0]
			else:GameState.next_battle_modifiers.free_shop_refresh=true
		"clock":
			if first:GameState.next_battle_modifiers.enemy_timer_bonus=1;GameState.next_battle_modifiers.initial_hand_delta=-1
			else:GameState.next_battle_modifiers.enemy_timer_bonus=-1;GameState.next_battle_modifiers.initial_hand_delta=1
		"crack":
			if first and GameState.spend_gold(10) and randf()<0.5:GameState.add_gold(28)
			elif not first:GameState.add_gold(6)
		"forbidden_supply":
			if first:await _add_random_card(PlayerCardData.Rarity.RARE);await _add_random_card(PlayerCardData.Rarity.RARE);GameState.next_battle_modifiers.hand_limit=8
			else:GameState.add_gold(15)
		"echo_printer":
			if first:
				for id in GameState.player_deck:var c:=PlayerCardRef.get_by_id(id);if c and c.rarity<2:await _acquire_card(id);break
			else:_remove_cards(1)
		"archive":
			if first:GameState.next_battle_modifiers.reveal_unknown=true
			else:GameState.next_battle_modifiers.show_three_intents=true
	GameState.events_completed+=1;GameState.save_run();EventBus.node_completed.emit("event");queue_free()

func _add_random_card(rarity:int)->void:
	var pool:=PlayerCardRef.get_pool(rarity);await _acquire_card(pool[randi()%pool.size()].card_id)
func _acquire_card(card_id:String)->void:
	if GameState.add_player_card(card_id):return
	var resolved:=[false];var layer:=CanvasLayer.new();layer.layer=300;add_child(layer);var dim:=ColorRect.new();dim.color=Color(0,0,0,0.94);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(dim)
	var title:=_label("牌库已满：选择一张替换为【%s】"%PlayerCardRef.get_by_id(card_id).card_name,22,Color(0.95,0.74,0.3));title.position=Vector2(200,80);title.size=Vector2(880,50);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;dim.add_child(title)
	var grid:=GridContainer.new();grid.columns=5;grid.position=Vector2(120,150);dim.add_child(grid)
	for i in range(GameState.player_deck.size()):
		var old:=PlayerCardRef.get_by_id(GameState.player_deck[i]);var button:=Button.new();button.text=old.card_name;button.custom_minimum_size=Vector2(195,62);button.pressed.connect(func(index:int=i):GameState.player_deck[index]=card_id;layer.queue_free();resolved[0]=true);grid.add_child(button)
	var discard:=Button.new();discard.text="丢弃新卡";discard.position=Vector2(510,650);discard.size=Vector2(260,48);discard.pressed.connect(func():layer.queue_free();resolved[0]=true);dim.add_child(discard)
	while not resolved[0]:await get_tree().process_frame
func _remove_cards(count:int)->void:
	for _i in range(mini(count,maxi(0,GameState.player_deck.size()-1))):GameState.player_deck.pop_back()
func _transform_common()->void:
	for i in range(GameState.player_deck.size()):
		var card:=PlayerCardRef.get_by_id(GameState.player_deck[i]);if card and card.rarity==PlayerCardData.Rarity.COMMON:var pool:=PlayerCardRef.get_pool(PlayerCardData.Rarity.RARE);GameState.player_deck[i]=pool[randi()%pool.size()].card_id;return
func _label(text:String,size_value:int,color:Color)->Label:var l:=Label.new();l.text=text;l.add_theme_font_size_override("font_size",size_value);l.add_theme_color_override("font_color",color);return l
