extends Node

const CardPoolRef:=preload("res://scripts/cards/CardPool.gd")
const CardDataRef:=preload("res://scripts/resources/CardData.gd")
const PlayerCardRef:=preload("res://scripts/resources/PlayerCardData.gd")
const DiceCupRef:=preload("res://scripts/dice/DiceCup.gd")
const ScoreEngineRef:=preload("res://scripts/dice/ScoreEngine.gd")
const DiceGameRef:=preload("res://scripts/dice/DiceGame.gd")
const GameFlowRef:=preload("res://scripts/gameflow/GameFlow.gd")
const ShopRef:=preload("res://scripts/ui/ShopUI.gd")

func _ready()->void:
	_test_all_scripts_load()
	_test_score_rules()
	_test_natural_rolls()
	_test_player_cards()
	_test_candidates()
	_test_enemy_levels()
	_test_node_order()
	_test_battle_boot()
	print("RULE_LOGIC_SMOKE_OK")
	get_tree().quit(0)

func _test_all_scripts_load()->void:
	var paths:Array[String]=[];_collect("res://scripts",paths)
	for path in paths:assert(ResourceLoader.load(path)!=null,"项目脚本无法加载: %s"%path)

func _collect(dir:String,out:Array[String])->void:
	for file in DirAccess.get_files_at(dir):if file.ends_with(".gd"):out.append(dir.path_join(file))
	for child in DirAccess.get_directories_at(dir):_collect(dir.path_join(child),out)

func _test_score_rules()->void:
	var pair:=ScoreEngineRef.score([2,2,4,5,6]);assert(pair.base==19);assert(pair.multiplier>=2)
	var triple:=ScoreEngineRef.score([3,3,3,5,6]);assert(triple.multiplier>=4)
	var straight:=ScoreEngineRef.score([1,2,3,5,6]);assert(straight.multiplier>=3)
	var partitioned:=ScoreEngineRef.score([2,2,3,4,5]);assert(partitioned.multiplier==5,"骰子不能同时重复计入对子和顺子")
	var wild:=ScoreEngineRef.score([1,2,2,2,6],{"wild_indices":[0]});assert(wild.base==13);assert(wild.multiplier==7,"万能①应能组成四条但仍按1点计算基础点数")
	var boosted:=ScoreEngineRef.score([2,2,4,5,6],{"chips":8,"mult":1,"final_mult":2});assert(boosted.score==(19+8)*(pair.multiplier+1)*2)

func _test_natural_rolls()->void:
	var cup:=DiceCupRef.new(5,42);cup.roll_all();assert(cup.dice.size()==5)
	# The v2 rules do not repair rolls into guaranteed pairs or remove straights.
	cup.dice[0].value=1;cup.dice[1].value=2;cup.dice[2].value=3;cup.dice[3].value=4;cup.dice[4].value=5
	assert(cup.get_all_values()==[1,2,3,4,5])

func _test_player_cards()->void:
	assert(PlayerCardRef.get_starter_deck_ids().size()==6)
	assert(PlayerCardRef.get_all_cards().size()>=50)
	assert(PlayerCardRef.get_by_id("pair_fix")==null)
	assert(PlayerCardRef.get_by_id("final_amplifier").effect=="final_mult")

func _test_candidates()->void:
	GameState.unlocked_cards.clear()
	var candidates:=CardPoolRef.draw_candidates(0,5);assert(candidates.size()==5)
	var unknown:=0
	for card in candidates:if card.rarity==CardDataRef.Rarity.UNKNOWN:unknown+=1
	assert(unknown==1,"每组候选必须恰好一张未知卡")

func _test_enemy_levels()->void:
	assert(GameState.get_max_level_for_card("jack_crt")==2)
	assert(GameState.get_max_level_for_card("recycler")==3)
	assert(GameState.get_max_level_for_card("dice_god")==4)
	assert(GameState.get_max_level_for_card("unknown_mirror")==1)
	assert(GameState.get_upgrade_cost_for_rarity(CardDataRef.Rarity.LEGENDARY)==4)
	assert(not GameState.downgrade_card("jack_crt"),"升级不可退款或降级")

func _test_node_order()->void:
	var flow:=GameFlowRef.new();flow.current_stage_index=0;flow._generate_nodes()
	assert(flow.nodes_this_stage.size()==7);assert(flow.nodes_this_stage.back()==flow.NodeType.BOSS)
	assert(flow.nodes_this_stage.count(flow.NodeType.DICE)==3);assert(flow.nodes_this_stage.count(flow.NodeType.EVENT)==2)
	flow.free()

func _test_battle_boot()->void:
	GameState.player_deck.assign(PlayerCardRef.get_starter_deck_ids());GameState.current_battle_seed=12345
	var game:=DiceGameRef.new();add_child(game);game.configure(0,[CardDataRef.get_common_pool()[0],CardDataRef.get_common_pool()[1]],false,0)
	var state:=game.get_view_state();assert(state.round==1);assert(state.hand.size()==6);assert(state.dice.size()==5);assert(state.target==180)
	var playable_index:=0
	for i in range(state.hand.size()):
		if str(state.hand[i].id) in ["old_chip","amp_gear"]:playable_index=i;break
	var before:int=state.enemies[0].timer;var card_result:=game.request_use_card(playable_index)
	assert(card_result.ok);state=game.get_view_state();assert(state.enemies[0].timer!=before or before==1)
	game.queue_free()
