extends Node

const CardDataRef:=preload("res://scripts/resources/CardData.gd")
const PlayerCardRef:=preload("res://scripts/resources/PlayerCardData.gd")
const BossFragmentRef:=preload("res://scripts/resources/BossFragmentData.gd")
const PROGRESS_MARKER:="SCORE_PROGRESS_V2"
const RUN_MARKER:="SCORE_RUN_V2"
const MAX_ASSIMILATION:=2
const MAX_DECK_SIZE:=25
const STARTING_GOLD:=45

# Current run
var gold:=0
var assimilation_count:=0
var current_stage:=0
var current_node_index:=0
var stage_node_orders:Dictionary={}
var player_deck:Array[String]=[]
var draw_pile:Array[String]=[]
var discard_pile:Array[String]=[]
var exhausted_pile:Array[String]=[]
var boss_fragments:Array[String]=[]
var current_battle_seed:=0
var current_contract:Dictionary={}
var prisoner_offer_stages:Array[int]=[]
var prisoner_accepted_stages:Array[int]=[]
var prisoner_breaches:=0
var royal_fragment_available:=false
var boss_rust_awarded_this_run:Array[int]=[]
var event_ids_seen_this_run:Array[String]=[]
var next_battle_modifiers:Dictionary={}
var after_battle_modifiers:Dictionary={}
var active_forbidden_rules:Array[String]=[]
var battle_rounds_used:=5
var bosses_defeated:Array[String]=[]
var events_completed:=0
var total_assimilations:=0
var _battle_entry_snapshot:Dictionary={}
var _run_rust_points:=0

# Permanent progression
var has_cleared_game:=false
var rust_points:=0
var tech_points:=0
var card_levels:Dictionary={}
var purchased_card_levels:Dictionary={}
var unlocked_cards:Array[String]=[]
var unlocked_player_cards:Array[String]=[]
var purchased_tech_nodes:Array[String]=[]
var selected_forbidden_rules:Array[String]=[]
var forbidden_slot_limit:=1
var completed_three_forbidden:=false
var hidden_king_discovered:=false
var tutorial_enabled:=true
var tutorial_completed:=false
var tutorial_shop_seen:=false
var tutorial_seen_topics:Array[String]=[]

func _ready()->void:load_progress()

func setup_new_run()->void:
	gold=STARTING_GOLD+(5 if "prep_gold_1" in purchased_tech_nodes else 0)+(5 if "prep_gold_2" in purchased_tech_nodes else 0)
	assimilation_count=0;current_stage=0;current_node_index=0;stage_node_orders.clear();boss_fragments.clear();current_battle_seed=0
	current_contract.clear();prisoner_offer_stages.clear();prisoner_accepted_stages.clear();prisoner_breaches=0;royal_fragment_available=false
	boss_rust_awarded_this_run.clear();event_ids_seen_this_run.clear();next_battle_modifiers.clear();after_battle_modifiers.clear();next_battle_modifiers.starting_shop_done=false
	bosses_defeated.clear();events_completed=0;total_assimilations=0;_battle_entry_snapshot.clear();_run_rust_points=0;battle_rounds_used=5
	active_forbidden_rules.clear()
	if has_cleared_game:active_forbidden_rules.assign(selected_forbidden_rules)
	if "greedy_box" in active_forbidden_rules:gold+=20
	initialize_player_deck();delete_run_save();EventBus.run_started.emit()

func initialize_player_deck()->void:
	player_deck.assign(PlayerCardRef.get_starter_deck_ids());draw_pile.clear();discard_pile.clear();exhausted_pile.clear()

func add_player_card(card_id:String)->bool:
	if PlayerCardRef.get_by_id(card_id)==null or player_deck.size()>=MAX_DECK_SIZE:return false
	player_deck.append(card_id);return true

func remove_player_card_at(index:int)->bool:
	if index<0 or index>=player_deck.size():return false
	player_deck.remove_at(index);return true

func add_gold(amount:int)->void:gold=maxi(0,gold+amount);EventBus.gold_changed.emit(gold)
func spend_gold(amount:int)->bool:
	if amount<0 or gold<amount:return false
	gold-=amount;EventBus.gold_changed.emit(gold);return true

func assimilate()->void:
	if assimilation_count>=MAX_ASSIMILATION:return
	assimilation_count+=1;total_assimilations+=1
	if assimilation_count==1:EventBus.half_assimilated.emit()
	else:EventBus.fully_assimilated.emit()
func clear_assimilation()->void:assimilation_count=0
func is_half_assimilated()->bool:return assimilation_count==1

func add_boss_fragment(card_id:String)->String:
	if not BossFragmentRef.has_definition(card_id):return "invalid"
	if card_id in boss_fragments:return "duplicate"
	if boss_fragments.size()>=BossFragmentRef.MAX_FRAGMENTS:return "full"
	boss_fragments.append(card_id);return "added"
func replace_boss_fragment(index:int,new_id:String)->bool:
	if index<0 or index>=boss_fragments.size() or new_id in boss_fragments or not BossFragmentRef.has_definition(new_id):return false
	boss_fragments[index]=new_id;return true
func consume_boss_fragment(card_id:String)->bool:
	var index:=boss_fragments.find(card_id)
	if index<0:return false
	boss_fragments.remove_at(index);return true

func prisoner_can_appear(stage:int)->bool:
	if prisoner_breaches>2 or stage in prisoner_offer_stages:return false
	if stage<=1:return true
	return 0 in prisoner_accepted_stages and 1 in prisoner_accepted_stages
func record_prisoner_offer(stage:int)->void:
	if stage not in prisoner_offer_stages:prisoner_offer_stages.append(stage)
func record_prisoner_acceptance(stage:int)->void:
	if stage not in prisoner_accepted_stages:prisoner_accepted_stages.append(stage)

func get_card_level(card_id:String)->int:return maxi(1,int(card_levels.get(card_id,1)))
func get_purchased_card_level(card_id:String)->int:return get_card_level(card_id)
func get_max_level_for_card(card_id:String)->int:
	var card:=CardDataRef.get_card_by_id(card_id)
	if card==null:return 1
	match card.rarity:
		CardData.Rarity.COMMON,CardData.Rarity.RARE:return 2
		CardData.Rarity.EPIC,CardData.Rarity.LEGENDARY:return 3
		CardData.Rarity.GENESIS:return 4
	return 1
func get_upgrade_cost_for_rarity(rarity:int)->int:return [1,2,3,4,5,0][clampi(rarity,0,5)]
func get_next_card_level_cost(card_id:String)->int:
	var card:=CardDataRef.get_card_by_id(card_id)
	if card==null or get_card_level(card_id)>=get_max_level_for_card(card_id):return 0
	return get_upgrade_cost_for_rarity(card.rarity)
func upgrade_card(card_id:String)->bool:
	var cost:=get_next_card_level_cost(card_id)
	if cost<=0 or rust_points<cost:return false
	rust_points-=cost;var level:=get_card_level(card_id)+1;card_levels[card_id]=level;purchased_card_levels[card_id]=level;tech_points+=1;save_progress();return true
func downgrade_card(_card_id:String)->bool:return false
func clear_all_levels()->int:return 0
func add_rust_points(amount:int)->void:rust_points+=maxi(0,amount);_run_rust_points+=maxi(0,amount)
func get_run_rust_points()->int:return _run_rust_points
func award_boss_rust(stage:int)->bool:
	if stage in boss_rust_awarded_this_run:return false
	boss_rust_awarded_this_run.append(stage);add_rust_points(1);save_progress();return true

func purchase_tech(node_id:String,cost:int)->bool:
	if node_id in purchased_tech_nodes or cost<0 or tech_points<cost:return false
	tech_points-=cost;purchased_tech_nodes.append(node_id);save_progress();return true

func mark_tutorial_topic(topic_id:String)->bool:
	if not tutorial_enabled or topic_id in tutorial_seen_topics:return false
	tutorial_seen_topics.append(topic_id);save_progress();return true

func capture_battle_entry(cards:Array)->void:
	if current_battle_seed<=0:current_battle_seed=randi_range(1,2147483646)
	var ids:Array[String]=[]
	for card in cards:
		if card!=null:ids.append(str(card.card_id))
	_battle_entry_snapshot=_run_dictionary();_battle_entry_snapshot.card_ids=ids;_battle_entry_snapshot.battle_seed=current_battle_seed;save_run()
func clear_battle_entry()->void:_battle_entry_snapshot.clear();current_battle_seed=0;current_contract.clear()
func restore_battle_entry_preserving_costs()->bool:
	if _battle_entry_snapshot.is_empty():return false
	var saved_assimilation:=assimilation_count;var saved_total:=total_assimilations;var saved_fragments:=boss_fragments.duplicate();var saved_royal:=royal_fragment_available
	_apply_run(_battle_entry_snapshot)
	assimilation_count=saved_assimilation;total_assimilations=saved_total;boss_fragments.assign(saved_fragments);royal_fragment_available=saved_royal
	return true

func _run_dictionary()->Dictionary:
	return {"gold":gold,"assimilation_count":assimilation_count,"current_stage":current_stage,"current_node_index":current_node_index,"stage_node_orders":stage_node_orders.duplicate(true),"player_deck":player_deck.duplicate(),"draw_pile":draw_pile.duplicate(),"discard_pile":discard_pile.duplicate(),"exhausted_pile":exhausted_pile.duplicate(),"boss_fragments":boss_fragments.duplicate(),"battle_seed":current_battle_seed,"current_contract":current_contract.duplicate(true),"prisoner_offer_stages":prisoner_offer_stages.duplicate(),"prisoner_accepted_stages":prisoner_accepted_stages.duplicate(),"prisoner_breaches":prisoner_breaches,"royal_fragment_available":royal_fragment_available,"boss_rust_awarded":boss_rust_awarded_this_run.duplicate(),"event_ids_seen":event_ids_seen_this_run.duplicate(),"next_battle_modifiers":next_battle_modifiers.duplicate(true),"after_battle_modifiers":after_battle_modifiers.duplicate(true),"active_forbidden_rules":active_forbidden_rules.duplicate(),"battle_rounds_used":battle_rounds_used,"bosses_defeated":bosses_defeated.duplicate(),"events_completed":events_completed,"total_assimilations":total_assimilations,"run_rust":_run_rust_points}

func _apply_run(data:Dictionary)->void:
	gold=int(data.get("gold",0));assimilation_count=int(data.get("assimilation_count",0));current_stage=int(data.get("current_stage",0));current_node_index=int(data.get("current_node_index",0));stage_node_orders=(data.get("stage_node_orders",{}) as Dictionary).duplicate(true)
	player_deck.assign(data.get("player_deck",PlayerCardRef.get_starter_deck_ids()));draw_pile.assign(data.get("draw_pile",[]));discard_pile.assign(data.get("discard_pile",[]));exhausted_pile.assign(data.get("exhausted_pile",[]));boss_fragments.assign(data.get("boss_fragments",[]));current_battle_seed=int(data.get("battle_seed",0));current_contract=(data.get("current_contract",{}) as Dictionary).duplicate(true)
	prisoner_offer_stages.assign(data.get("prisoner_offer_stages",[]));prisoner_accepted_stages.assign(data.get("prisoner_accepted_stages",[]));prisoner_breaches=int(data.get("prisoner_breaches",0));royal_fragment_available=bool(data.get("royal_fragment_available",false));boss_rust_awarded_this_run.assign(data.get("boss_rust_awarded",[]));event_ids_seen_this_run.assign(data.get("event_ids_seen",[]));next_battle_modifiers=(data.get("next_battle_modifiers",{}) as Dictionary).duplicate(true);after_battle_modifiers=(data.get("after_battle_modifiers",{}) as Dictionary).duplicate(true);active_forbidden_rules.assign(data.get("active_forbidden_rules",[]));battle_rounds_used=int(data.get("battle_rounds_used",5));bosses_defeated.assign(data.get("bosses_defeated",[]));events_completed=int(data.get("events_completed",0));total_assimilations=int(data.get("total_assimilations",0));_run_rust_points=int(data.get("run_rust",0))

func save_run()->void:
	var file:=FileAccess.open("user://save_game.dat",FileAccess.WRITE)
	if file==null:return
	file.store_pascal_string(RUN_MARKER);file.store_var(_run_dictionary(),true);file.close()
func load_run()->bool:
	var file:=FileAccess.open("user://save_game.dat",FileAccess.READ)
	if file==null:return false
	if file.get_pascal_string()!=RUN_MARKER:file.close();return false
	var data:Variant=file.get_var(true);file.close()
	if data is not Dictionary:return false
	_apply_run(data);return true
func has_saved_game()->bool:
	var file:=FileAccess.open("user://save_game.dat",FileAccess.READ)
	if file==null:return false
	var valid:=file.get_pascal_string()==RUN_MARKER;file.close();return valid
func delete_run_save()->void:
	if FileAccess.file_exists("user://save_game.dat"):DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_game.dat"))
func _clear_save()->void:delete_run_save();EventBus.run_started.emit()

func save_progress()->void:
	var file:=FileAccess.open("user://progress.dat",FileAccess.WRITE)
	if file==null:return
	file.store_pascal_string(PROGRESS_MARKER)
	file.store_var({"has_cleared":has_cleared_game,"rust_points":rust_points,"tech_points":tech_points,"card_levels":card_levels.duplicate(),"unlocked_cards":unlocked_cards.duplicate(),"unlocked_player_cards":unlocked_player_cards.duplicate(),"tech_nodes":purchased_tech_nodes.duplicate(),"selected_forbidden":selected_forbidden_rules.duplicate(),"forbidden_limit":forbidden_slot_limit,"completed_three":completed_three_forbidden,"hidden_king":hidden_king_discovered,"tutorial_enabled":tutorial_enabled,"tutorial_completed":tutorial_completed,"tutorial_shop_seen":tutorial_shop_seen,"tutorial_topics":tutorial_seen_topics.duplicate()},true);file.close()

func load_progress()->void:
	_ensure_progress_defaults()
	var file:=FileAccess.open("user://progress.dat",FileAccess.READ)
	if file==null:return
	var marker:=file.get_pascal_string()
	if marker==PROGRESS_MARKER:
		var data:Variant=file.get_var(true);file.close()
		if data is Dictionary:_apply_progress(data)
		return
	# Legacy migration: preserve clear state, rust points and readable card levels.
	file.seek(0);has_cleared_game=file.get_32()==1;rust_points=maxi(0,file.get_32());var count:=file.get_32()
	if count>=0 and count<=128:
		for _i in range(count):
			var id:=file.get_pascal_string();var old_level:=file.get_32();if CardDataRef.get_card_by_id(id)!=null:card_levels[id]=clampi(maxi(1,old_level),1,get_max_level_for_card(id))
	file.close();save_progress()

func _apply_progress(data:Dictionary)->void:
	has_cleared_game=bool(data.get("has_cleared",false));rust_points=int(data.get("rust_points",0));tech_points=int(data.get("tech_points",0));card_levels=(data.get("card_levels",{}) as Dictionary).duplicate();purchased_card_levels=card_levels.duplicate();unlocked_cards.assign(data.get("unlocked_cards",unlocked_cards));unlocked_player_cards.assign(data.get("unlocked_player_cards",unlocked_player_cards));purchased_tech_nodes.assign(data.get("tech_nodes",[]));selected_forbidden_rules.assign(data.get("selected_forbidden",[]));forbidden_slot_limit=clampi(int(data.get("forbidden_limit",1)),1,3);completed_three_forbidden=bool(data.get("completed_three",false));hidden_king_discovered=bool(data.get("hidden_king",false));tutorial_enabled=bool(data.get("tutorial_enabled",true));tutorial_completed=bool(data.get("tutorial_completed",false));tutorial_shop_seen=bool(data.get("tutorial_shop_seen",false));tutorial_seen_topics.assign(data.get("tutorial_topics",[]));_ensure_progress_defaults()

func _ensure_progress_defaults()->void:
	if unlocked_cards.is_empty():unlocked_cards.assign(["jack_crt","rust_warrior","battery_kid","cyclops_lcd","two_face","chamberlain","recycler","lucky_one","referee","alliance_oled","casino_owner","prophet","dice_god"])
	if unlocked_player_cards.is_empty():
		for card in PlayerCardRef.get_all_cards():unlocked_player_cards.append(card.card_id)
	for card in CardDataRef.get_all_cards():
		if card.rarity!=CardData.Rarity.UNKNOWN:card_levels[card.card_id]=clampi(maxi(1,int(card_levels.get(card.card_id,1))),1,get_max_level_for_card(card.card_id))

func calculate_score()->Dictionary:
	var total:=bosses_defeated.size()*100+gold/4+events_completed*12-total_assimilations*50
	var tier:="S" if total>=480 else ("A" if total>=350 else ("B" if total>=220 else "C"))
	return {"score":total,"tier":tier,"boss_bonus":bosses_defeated.size()*100,"gold_bonus":gold/4,"assimilation_penalty":total_assimilations*50,"event_bonus":events_completed*12}
