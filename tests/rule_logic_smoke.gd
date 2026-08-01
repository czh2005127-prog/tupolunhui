extends Node

const CardPoolScript := preload("res://scripts/cards/CardPool.gd")
const CardDataScript := preload("res://scripts/resources/CardData.gd")
const DiceCupScript := preload("res://scripts/dice/DiceCup.gd")
const DiceGameScript := preload("res://scripts/dice/DiceGame.gd")
const BossFragmentDataScript := preload("res://scripts/resources/BossFragmentData.gd")

func _ready() -> void:
	_test_dynamic_candidates()
	_test_pair_fix()
	_test_fragment_inventory()
	_test_five_stage_curve()
	_test_growth_curse()
	await _test_duplicate_dealers()
	await _test_boss_dealer()
	print("RULE_LOGIC_SMOKE_OK")
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0)

func _test_dynamic_candidates() -> void:
	GameState.unlocked_cards.clear()
	GameState.unlocked_cards.append_array(["jack_crt", "rust_warrior", "battery_kid"])
	var initial_pool: Array = CardPoolScript.get_mixed_pool(0)
	assert(initial_pool.size() == 3, "初始候选应为三张")
	GameState.unlocked_cards.append("signal_noise")
	var expanded_pool: Array = CardPoolScript.get_mixed_pool(0)
	assert(expanded_pool.size() == 4, "第四张同稀有度卡解锁后候选应增长")
	GameState.unlocked_cards.append_array(["recycler", "lucky_one", "table_ghost", "mirror_tech", "referee"])
	var maximum_pool: Array = CardPoolScript.get_mixed_pool(2)
	assert(maximum_pool.size() == 5, "候选数量上限应为五张")
	var has_unknown: bool = false
	for card in initial_pool:
		if card.rarity == CardDataScript.Rarity.UNKNOWN: has_unknown = true
	assert(has_unknown, "混合牌堆必须注入未知卡")

func _test_pair_fix() -> void:
	var game = DiceGameScript.new()
	var cup = DiceCupScript.new(3)
	cup.dice[0].value = 2
	cup.dice[1].value = 6
	cup.dice[2].value = 3
	assert(game._apply_pair_fix_to_cup(cup), "无对子时保底对应生效")
	assert(cup.dice[0].value == 6, "最低点数必须变为当前最高点数")
	assert(cup.has_pairs(), "保底对生效后必须形成对子")
	game.free()

func _test_fragment_inventory() -> void:
	GameState.boss_fragments.clear()
	assert(GameState.add_boss_fragment("recycler") == "added")
	assert(GameState.add_boss_fragment("recycler") == "duplicate")
	assert(GameState.add_boss_fragment("lucky_one") == "added")
	assert(GameState.add_boss_fragment("referee") == "full")
	assert(GameState.boss_fragments.size() == BossFragmentDataScript.MAX_FRAGMENTS)
	assert(GameState.replace_boss_fragment(0, "referee"))
	assert(GameState.boss_fragments == ["referee", "lucky_one"])

func _test_five_stage_curve() -> void:
	GameState.card_levels["jack_crt"] = 5
	GameState.purchased_card_levels["jack_crt"] = 5
	assert(GameState.get_max_level_for_card("jack_crt") == 5)
	assert(GameState.get_max_level_for_card("dealer") == 0)
	assert(DiceGameScript.get_rust_start_dice_bonus(2) == 0)
	assert(DiceGameScript.get_rust_start_dice_bonus(3) == 1)
	assert(DiceGameScript.get_rust_start_dice_bonus(4) == 2)
	assert(DiceGameScript.get_rust_start_dice_bonus(5) == 4)
	var jack = CardDataScript.get_card_by_id("jack_crt")
	assert(is_equal_approx(GameState.get_battle_reward_multiplier([jack]), 1.5))
	GameState.card_levels["jack_crt"] = 0
	GameState.purchased_card_levels["jack_crt"] = 0

func _test_growth_curse() -> void:
	var game = DiceGameScript.new()
	game.player_cup = DiceCupScript.new(2)
	game.player_cup.dice[0].value = 1
	game.player_cup.dice[1].value = 4
	GameState.assimilation_curse = "growth_cost"
	game._apply_player_round_effects()
	assert(game.player_cup.dice.size() == 3)
	assert(game.player_cup.get_all_values().count(1) <= 1, "增殖代价每轮应随机改变一颗①")
	GameState.assimilation_curse = ""
	game.free()

func _test_duplicate_dealers() -> void:
	var dealers: Array = CardDataScript.get_legendary_pool().filter(
		func(card): return card.card_id == "dealer"
	)
	assert(dealers.size() == 1)
	var game = DiceGameScript.new()
	add_child(game)
	GameState.current_stage = 0
	GameState.assimilation_count = 0
	game.start_game(dealers[0], dealers[0], false, null, false)
	assert(game.ai_cup_1.dice.size() == 8, "第一名庄家应以8骰开局")
	assert(game.ai_cup_2.dice.size() == 8, "重复庄家也应以8骰开局")
	assert(game.current_player in ["ai1", "ai2"], "双庄家应随机由其中一名起叫")
	game.game_active = false
	await get_tree().create_timer(4.0).timeout
	for ctrl in [game.ai_controller_1, game.ai_controller_2, game.ai_controller_3]:
		if ctrl: ctrl.set_dice_game(null)
	game.ai_controller_1 = null
	game.ai_controller_2 = null
	game.ai_controller_3 = null
	game.ai_cup_1 = null
	game.ai_cup_2 = null
	game.ai_cup_3 = null
	game.player_cup = null
	remove_child(game)
	game.free()

func _test_boss_dealer() -> void:
	var commons: Array = CardDataScript.get_common_pool()
	var dealer = CardDataScript.get_card_by_id("dealer")
	var game = DiceGameScript.new()
	add_child(game)
	GameState.current_stage = 0
	GameState.assimilation_count = 0
	GameState.boss_fragments.clear()
	game.start_game(commons[0], commons[1], false, dealer, true)
	assert(game.ai_cup_3.dice.size() == 10, "Boss庄家应以10骰开局")
	assert(game.get_min_opening() == 7, "Boss庄家存活时四人最低起叫应为7")
	game.game_active = false
	await get_tree().create_timer(4.0).timeout
	for ctrl in [game.ai_controller_1, game.ai_controller_2, game.ai_controller_3]:
		if ctrl: ctrl.set_dice_game(null)
	game.ai_controller_1 = null; game.ai_controller_2 = null; game.ai_controller_3 = null
	game.ai_cup_1 = null; game.ai_cup_2 = null; game.ai_cup_3 = null; game.player_cup = null
	remove_child(game)
	game.free()
