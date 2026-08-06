extends Control

signal fragment_choice_resolved
signal contract_choice_resolved

enum NodeType { DICE, EVENT, SHOP, BOSS }
const CardPoolRef := preload("res://scripts/cards/CardPool.gd")
const CardDataRef := preload("res://scripts/resources/CardData.gd")
const BossFragmentRef := preload("res://scripts/resources/BossFragmentData.gd")

var stages: Array[Resource] = []
var current_stage_index := 0
var current_node_index := 0
var nodes_this_stage: Array = []
var _drawn_cards: Array = []
var _is_boss_node := false
var _redraw_used := false
var _shop_is_starting := false
var _hidden_battle := false

func _ready() -> void:
	_build_stages()
	EventBus.node_completed.connect(_on_node_completed)
	EventBus.shop_exited.connect(_on_shop_exited)
	current_stage_index = clampi(GameState.current_stage, 0, 3)
	current_node_index = maxi(0, GameState.current_node_index)
	if not bool(GameState.next_battle_modifiers.get("starting_shop_done", false)):
		_shop_is_starting = true
		GameState.next_battle_modifiers.starting_shop_done = true
		_launch_shop()
	else:
		_enter_stage()

func _build_stages() -> void:
	var StageDataRef := preload("res://scripts/resources/StageData.gd")
	var names := ["破烂后院","地下赌场","黑帮私局","终极赌场"]
	for i in range(4):
		var stage := StageDataRef.new(); stage.stage_name=names[i]; stage.node_count=7; stages.append(stage)

func _enter_stage() -> void:
	if current_stage_index >= 4:
		_finish_run(); return
	GameState.current_stage=current_stage_index
	EventBus.stage_changed.emit(current_stage_index,stages[current_stage_index].stage_name)
	_generate_nodes()
	current_node_index=clampi(current_node_index,0,nodes_this_stage.size()-1)
	GameState.current_node_index=current_node_index
	GameState.save_run()
	_run_node(nodes_this_stage[current_node_index])

func _generate_nodes() -> void:
	var key:=str(current_stage_index)
	if GameState.stage_node_orders.has(key):
		nodes_this_stage.assign(GameState.stage_node_orders[key])
		if _valid_order(nodes_this_stage): return
	var prefix:Array=[NodeType.DICE,NodeType.DICE,NodeType.DICE,NodeType.EVENT,NodeType.EVENT,NodeType.SHOP]
	for _attempt in range(100):
		prefix.shuffle()
		var candidate:=prefix.duplicate();candidate.append(NodeType.BOSS)
		if _valid_order(candidate):nodes_this_stage=candidate;break
	if nodes_this_stage.is_empty():nodes_this_stage=[NodeType.DICE,NodeType.EVENT,NodeType.DICE,NodeType.SHOP,NodeType.EVENT,NodeType.DICE,NodeType.BOSS]
	GameState.stage_node_orders[key]=nodes_this_stage.duplicate()

func _valid_order(order:Array)->bool:
	if order.size()!=7 or order.back()!=NodeType.BOSS:return false
	if order.count(NodeType.DICE)!=3 or order.count(NodeType.EVENT)!=2 or order.count(NodeType.SHOP)!=1:return false
	if order[0]!=NodeType.DICE and order[1]!=NodeType.DICE:return false
	var shop_index:=order.find(NodeType.SHOP)
	var has_battle_before:=false
	for i in range(shop_index):if order[i]==NodeType.DICE:has_battle_before=true
	if not has_battle_before:return false
	for i in range(order.size()-1):if order[i]==NodeType.EVENT and order[i+1]==NodeType.EVENT:return false
	return true

func _run_node(type:int)->void:
	_clear_active_scene()
	match type:
		NodeType.DICE:_launch_battle(false)
		NodeType.BOSS:_launch_battle(true)
		NodeType.SHOP:_launch_shop()
		NodeType.EVENT:_launch_event()

func _launch_battle(boss:bool)->void:
	_is_boss_node=boss;_redraw_used=false
	var pool:Array=CardPoolRef.draw_candidates(current_stage_index)
	var boss_pool:Array=CardPoolRef.get_boss_pool(current_stage_index) if boss else []
	var overlay:=preload("res://scripts/ui/CardDrawUI.gd").new()
	overlay.name="CardDrawUI"
	add_child(overlay)
	overlay.setup(pool,boss_pool,self,boss,2,current_stage_index,true)

func _on_card_redraw_requested()->void:
	if _redraw_used:return
	_redraw_used=true
	var pool:=CardPoolRef.draw_candidates(current_stage_index)
	var boss_pool:=CardPoolRef.get_boss_pool(current_stage_index) if _is_boss_node else []
	var old:=get_node_or_null("CardDrawUI");if old:old.queue_free()
	var overlay:=preload("res://scripts/ui/CardDrawUI.gd").new();overlay.name="CardDrawUI";add_child(overlay);overlay.setup(pool,boss_pool,self,_is_boss_node,2,current_stage_index,false)

func _on_cards_confirmed(cards:Array)->void:
	_drawn_cards=cards.duplicate()
	if _is_boss_node and current_stage_index==3:
		var god:=CardDataRef.get_genesis_pool()[0]
		if _drawn_cards.size()>2:_drawn_cards[2]=god
		else:_drawn_cards.append(god)
		if 0 in GameState.prisoner_accepted_stages and 1 in GameState.prisoner_accepted_stages and GameState.prisoner_breaches<=2:
			_show_royal_reveal();return
	_offer_prisoner_contract()

func _show_royal_reveal()->void:
	var layer:=CanvasLayer.new();layer.layer=350;add_child(layer);var dim:=ColorRect.new();dim.color=Color(0,0,0,0.95);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(dim)
	var text:=Label.new();text.text="无名囚徒摘下兜帽。\n\n‘我曾是这个国度的国王。你守住了前两层的承诺，所以我也会守住我的。’\n\n获得【流亡王印】\n骰子之神第二阶段失败时，可重置该阶段且不增加同化。";text.position=Vector2(260,150);text.size=Vector2(760,300);text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.add_theme_font_size_override("font_size",23);dim.add_child(text)
	var button:=Button.new();button.text="接过王印";button.position=Vector2(490,520);button.size=Vector2(300,58);button.pressed.connect(func():GameState.royal_fragment_available=true;layer.queue_free();_start_selected_battle());dim.add_child(button)

func _offer_prisoner_contract()->void:
	if not GameState.prisoner_can_appear(current_stage_index) or (_is_boss_node and current_stage_index==3):
		_start_selected_battle();return
	GameState.record_prisoner_offer(current_stage_index)
	var contracts:Array[Dictionary]=[
		{"id":"five_twos","title":"五个二","desc":"本场累计让②参与计分至少5颗次","reward":"+14金币","penalty":"下一战初始手牌-1"},
		{"id":"two_patterns","title":"双重结构","desc":"单轮形成至少2种不同骰型","reward":"获得1张随机稀有牌","penalty":"下一战1张初始手牌送至牌库底"},
		{"id":"four_discards","title":"舍弃旧物","desc":"本场主动弃牌至少4张","reward":"下一商店首次刷新免费","penalty":"下一商店价格+15%"},
		{"id":"no_legendary","title":"凡铁之证","desc":"不使用传说牌完成战斗","reward":"+20金币","penalty":"下一战封锁1张初始手牌至计分"},
		{"id":"three_rounds","title":"迅速破局","desc":"3轮内通关","reward":"获得1个普通包","penalty":"下一战敌人初始倒计时-1"},
		{"id":"four_names","title":"多变之手","desc":"单轮使用至少4张不同牌名","reward":"本场额外+1骰","penalty":"下一战基础骰子-1"},
	]
	contracts.shuffle();var c:=contracts[0]
	var layer:=CanvasLayer.new();layer.layer=300;add_child(layer);var dim:=ColorRect.new();dim.color=Color(0,0,0,0.92);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(dim)
	var text:=Label.new();text.text="无名囚徒的契约\n\n%s\n%s\n\n奖励：%s\n违约：%s"%[c.title,c.desc,c.reward,c.penalty];text.position=Vector2(300,130);text.size=Vector2(680,300);text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;text.add_theme_font_size_override("font_size",23);dim.add_child(text)
	var accept:=Button.new();accept.text="接受";accept.position=Vector2(370,500);accept.size=Vector2(220,55);accept.pressed.connect(func():GameState.current_contract=c.duplicate(true);GameState.record_prisoner_acceptance(current_stage_index);layer.queue_free();_start_selected_battle());dim.add_child(accept)
	var decline:=Button.new();decline.text="拒绝";decline.position=Vector2(690,500);decline.size=Vector2(220,55);decline.pressed.connect(func():layer.queue_free();_start_selected_battle());dim.add_child(decline)

func _start_selected_battle()->void:
	GameState.capture_battle_entry(_drawn_cards)
	var path:="res://scenes/gameflow/BossGameScene.tscn" if _is_boss_node else "res://scenes/gameflow/DiceGameScene.tscn"
	var scene:=load(path) as PackedScene;if scene==null:return
	var instance:=scene.instantiate() as Control;add_child(instance);instance.setup_with_flow(stages[current_stage_index],self,_drawn_cards)

func _launch_shop()->void:
	var scene:=load("res://scenes/gameflow/ShopScene.tscn") as PackedScene;var instance:=scene.instantiate() as Control;instance.name="ShopUI";add_child(instance);instance.set_parent_flow(self)

func _launch_event()->void:
	var scene:=load("res://scenes/gameflow/EventScene.tscn") as PackedScene;var instance:=scene.instantiate() as Control;instance.name="EventUI";add_child(instance);instance.set_parent_flow(self)

func _on_node_completed(_type:String)->void:
	if _hidden_battle:
		_hidden_battle=false
		GameState.hidden_king_discovered=true
		GameState.save_progress()
		_show_victory(true)
		return
	var rounds: int = GameState.battle_rounds_used
	var multiplier: float = float([2.0,1.75,1.5,1.25,1.0][clampi(rounds-1,0,4)]) if rounds<=5 else 0.8
	var base: int = CardPoolRef.get_battle_gold(current_stage_index,_is_boss_node)
	GameState.add_gold(floori(base*multiplier))
	if _is_boss_node:
		GameState.award_boss_rust(current_stage_index)
		if not _drawn_cards.is_empty():await _award_fragment(_drawn_cards.back())
	var starting_done: bool = bool(GameState.next_battle_modifiers.get("starting_shop_done", true))
	GameState.next_battle_modifiers.clear()
	GameState.next_battle_modifiers.starting_shop_done = starting_done
	for key in GameState.after_battle_modifiers:GameState.next_battle_modifiers[key]=GameState.after_battle_modifiers[key]
	GameState.after_battle_modifiers.clear()
	GameState.clear_battle_entry();_advance_node()

func _award_fragment(card:CardData)->void:
	if card==null or card.card_id in ["dice_god","card_king"] or not BossFragmentRef.has_definition(card.card_id):return
	var result:=GameState.add_boss_fragment(card.card_id)
	if result=="duplicate":GameState.add_gold(15);return
	if result!="full":return
	var layer:=CanvasLayer.new();layer.layer=450;add_child(layer);var dim:=ColorRect.new();dim.color=Color(0,0,0,0.94);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(dim)
	var title:=Label.new();title.text="碎片已满：%s"%BossFragmentRef.get_fragment_name(card.card_id);title.position=Vector2(260,130);title.size=Vector2(760,50);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",28);dim.add_child(title)
	for i in range(GameState.boss_fragments.size()):
		var old_id:String=GameState.boss_fragments[i];var button:=Button.new();button.text="替换 %s"%BossFragmentRef.get_fragment_name(old_id);button.position=Vector2(250+i*390,300);button.size=Vector2(320,60);button.pressed.connect(func(index:int=i):GameState.replace_boss_fragment(index,card.card_id);layer.queue_free();fragment_choice_resolved.emit());dim.add_child(button)
	var discard:=Button.new();discard.text="丢弃新碎片";discard.position=Vector2(480,420);discard.size=Vector2(320,60);discard.pressed.connect(func():layer.queue_free();fragment_choice_resolved.emit());dim.add_child(discard)
	await fragment_choice_resolved

func _advance_node()->void:
	current_node_index+=1;GameState.current_node_index=current_node_index
	if current_node_index>=nodes_this_stage.size():
		current_stage_index+=1;current_node_index=0;GameState.current_stage=current_stage_index;GameState.current_node_index=0
		_enter_stage()
	else:_run_node(nodes_this_stage[current_node_index])

func _on_shop_exited()->void:
	GameState.next_battle_modifiers.erase("free_shop_refresh")
	GameState.next_battle_modifiers.erase("shop_price_bonus")
	if _shop_is_starting:_shop_is_starting=false;_enter_stage()
	else:_advance_node()

func get_current_normal_battle_index()->int:
	var count:=0
	for i in range(mini(current_node_index,nodes_this_stage.size())):if nodes_this_stage[i]==NodeType.DICE:count+=1
	return clampi(count,0,2)

func _finish_run()->void:
	GameState.add_rust_points(1);GameState.has_cleared_game=true
	if GameState.active_forbidden_rules.size()>=GameState.forbidden_slot_limit and GameState.forbidden_slot_limit<3:GameState.forbidden_slot_limit+=1
	if GameState.active_forbidden_rules.size()>=3:GameState.completed_three_forbidden=true
	GameState.save_progress()
	if _hidden_conditions_met():_launch_hidden_boss()
	else:_show_victory(false)

func _hidden_conditions_met()->bool:
	if not GameState.completed_three_forbidden or GameState.prisoner_breaches>2:return false
	if not (0 in GameState.prisoner_accepted_stages and 1 in GameState.prisoner_accepted_stages):return false
	for card in CardDataRef.get_all_cards():
		if card.rarity==CardData.Rarity.UNKNOWN:continue
		if GameState.get_card_level(card.card_id)<GameState.get_max_level_for_card(card.card_id):return false
	return true

func _launch_hidden_boss()->void:
	_hidden_battle=true;_is_boss_node=true
	var scribe:=CardDataRef.make("royal_scribe","皇家书记官",CardData.Rarity.LEGENDARY,[CardDataRef.s("罪证登记","continuous",4,"protect_high","标记高稀有度手牌与相关骰子。"),CardDataRef.s("封存证物","trigger",3,"discard_high_card","优先封存罪证手牌。")])
	var executioner:=CardDataRef.make("royal_executioner","皇家刽子手",CardData.Rarity.LEGENDARY,[CardDataRef.s("证据锁链","continuous",3,"no_reroll","优先锁定罪证骰。"),CardDataRef.s("皇家行刑","trigger",3,"flip_high","优先翻转罪证骰。")])
	var king:=CardDataRef.make("card_king","卡牌国王",CardData.Rarity.GENESIS,[CardDataRef.s("锈蚀敕令","continuous",5,"rust_used_cards","目标手牌使用后锈蚀占位。"),CardDataRef.s("王权征用","trigger",4,"bottom_high_card","罪证和高稀有度手牌送至牌库底。"),CardDataRef.s("国王禁令","continuous",4,"block_category","封锁一个卡牌类别。"),CardDataRef.s("记忆抹除","trigger",5,"randomize_dice","目标骰恢复本轮初始点数。")])
	_drawn_cards=[scribe,executioner,king]
	var scene:=load("res://scenes/gameflow/DiceGameScene.tscn") as PackedScene;var instance:=scene.instantiate() as Control;add_child(instance);instance.setup_with_flow(stages[3],self,_drawn_cards)

func _show_victory(true_ending:bool)->void:
	GameState.delete_run_save();EventBus.run_ended.emit(true)
	var victory:=preload("res://scripts/ui/VictoryUI.gd").new();victory.set_meta("true_ending",true_ending);add_child(victory)

func handle_event_death()->void:
	GameState.delete_run_save();GameState.save_progress();EventBus.run_ended.emit(false);get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func emit_node_done()->void:EventBus.node_completed.emit("")
func _clear_active_scene()->void:
	for child in get_children():
		if child is Control and child.name not in ["ShopUI","EventUI"]:child.queue_free()
