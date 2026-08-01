extends Node

const CardPoolScript := preload("res://scripts/cards/CardPool.gd")
const CardDataScript := preload("res://scripts/resources/CardData.gd")
const DiceCupScript := preload("res://scripts/dice/DiceCup.gd")
const DiceGameScript := preload("res://scripts/dice/DiceGame.gd")
const BossFragmentDataScript := preload("res://scripts/resources/BossFragmentData.gd")
const GameFlowScript := preload("res://scripts/gameflow/GameFlow.gd")
const ShopUIScript := preload("res://scripts/ui/ShopUI.gd")
const MainMenuScript := preload("res://scripts/ui/MainMenu.gd")
const CardDrawUIScript := preload("res://scripts/ui/CardDrawUI.gd")

func _ready() -> void:
	GameState.tutorial_completed = true
	_test_dynamic_candidates()
	_test_pair_fix()
	_test_fragment_inventory()
	_test_three_stage_curve()
	_test_upgrade_migration()
	_test_battle_entry_snapshot()
	_test_random_stage_nodes()
	_test_forbidden_rewards_and_payout()
	_test_shop_build()
	_test_ai_probability_logic()
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
	assert(initial_pool.size() == 5, "混合候选必须固定五张")
	var initial_unknowns: int = initial_pool.filter(func(card): return card.rarity == CardDataScript.Rarity.UNKNOWN).size()
	assert(initial_unknowns == 2, "五张候选必须包含两张不同未知卡")
	var unknown_ids: Array = initial_pool.filter(func(card): return card.rarity == CardDataScript.Rarity.UNKNOWN).map(func(card): return card.card_id)
	assert(unknown_ids[0] != unknown_ids[1], "未知候选不得重复")
	GameState.unlocked_cards.append("signal_noise")
	var expanded_pool: Array = CardPoolScript.get_mixed_pool(0)
	assert(expanded_pool.size() == 5, "解锁增长后仍固定五张候选")
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
	assert(GameState.add_boss_fragment("dice_god") == "invalid", "骰子之神不能产出碎片")

func _test_three_stage_curve() -> void:
	GameState.card_levels["jack_crt"] = 3
	GameState.purchased_card_levels["jack_crt"] = 3
	assert(GameState.get_max_level_for_card("jack_crt") == 3)
	assert(GameState.get_max_level_for_card("dealer") == 0)
	var jack = CardDataScript.get_card_by_id("jack_crt")
	assert(is_equal_approx(GameState.get_battle_reward_multiplier([jack]), 1.22))
	GameState.card_levels["jack_crt"] = 0
	GameState.purchased_card_levels["jack_crt"] = 0

func _test_upgrade_migration() -> void:
	var old_points: int = GameState.rust_points
	GameState.rust_points = 0
	GameState.card_levels["jack_crt"] = 5
	GameState.purchased_card_levels["jack_crt"] = 5
	assert(GameState._migrate_three_level_upgrades())
	assert(GameState.card_levels["jack_crt"] == 3 and GameState.purchased_card_levels["jack_crt"] == 3)
	assert(GameState.rust_points == 9, "移除Lv.4和Lv.5应返还4+5点")
	GameState.card_levels["jack_crt"] = 0
	GameState.purchased_card_levels["jack_crt"] = 0
	GameState.rust_points = old_points

func _test_battle_entry_snapshot() -> void:
	var jack = CardDataScript.get_card_by_id("jack_crt")
	var warrior = CardDataScript.get_card_by_id("rust_warrior")
	GameState.gold = 37
	GameState.assimilation_count = 1
	GameState.consumable_items.assign(["payout", "full_reroll"])
	GameState.boss_fragments.assign(["lucky_one"])
	GameState.capture_battle_entry([jack, warrior])
	var captured_seed: int = GameState.current_battle_seed
	assert(captured_seed != 0, "战斗入口必须保存确定性随机种子")
	GameState.gold = 999
	GameState.assimilation_count = 2
	GameState.consumable_items.clear()
	GameState.boss_fragments.clear()
	GameState._restore_battle_entry(GameState._battle_entry_snapshot)
	assert(GameState.gold == 37 and GameState.assimilation_count == 1)
	assert(GameState.consumable_items == ["payout", "full_reroll"])
	assert(GameState.boss_fragments == ["lucky_one"])
	assert(GameState.saved_battle_card_ids == ["jack_crt", "rust_warrior"])
	assert(GameState.current_battle_seed == captured_seed)
	GameState.clear_battle_entry()
	GameState.assimilation_count = 0
	GameState.consumable_items.clear()
	GameState.boss_fragments.clear()

func _test_random_stage_nodes() -> void:
	GameState.stage_node_orders.clear()
	var flow = GameFlowScript.new()
	flow.current_stage_index = 0
	flow._generate_nodes()
	assert(flow.nodes_this_stage.size() == 5)
	assert(flow.nodes_this_stage.back() == GameFlowScript.NodeType.BOSS)
	assert(flow.nodes_this_stage.count(GameFlowScript.NodeType.DICE) == 2)
	assert(flow.nodes_this_stage.count(GameFlowScript.NodeType.SHOP) == 1)
	assert(flow.nodes_this_stage.count(GameFlowScript.NodeType.EVENT) == 1)
	assert(flow.nodes_this_stage.find(GameFlowScript.NodeType.DICE) < flow.nodes_this_stage.find(GameFlowScript.NodeType.SHOP), "商店前必须至少有一场战斗")
	flow.free()

func _test_forbidden_rewards_and_payout() -> void:
	var old_rules: Array[String] = GameState.active_forbidden_rules.duplicate()
	GameState.active_forbidden_rules.assign(["high_pressure"])
	var jack = CardDataScript.get_card_by_id("jack_crt")
	GameState.card_levels["jack_crt"] = 0
	assert(is_equal_approx(GameState.get_battle_reward_multiplier([jack]), 1.15))
	var game = DiceGameScript.new()
	game.queue_payout_reward(15); game.queue_payout_reward(15)
	assert(game.claim_payout_reward() == 30, "多张清算必须在胜利时叠加结算")
	assert(game.claim_payout_reward() == 0, "清算奖励只能领取一次")
	game.free()
	GameState.active_forbidden_rules = old_rules

func _test_shop_build() -> void:
	var old_seen: bool = GameState.tutorial_shop_seen
	GameState.tutorial_shop_seen = true
	var shop = ShopUIScript.new()
	add_child(shop)
	shop.set_parent_flow(self)
	assert(shop.find_child("GambleBtn", true, false) != null, "商店必须提供最多两次的店内赌桌入口")
	remove_child(shop)
	shop.free()
	GameState.tutorial_shop_seen = old_seen

func _test_ai_probability_logic() -> void:
	var ai_script := preload("res://scripts/ai/AiController.gd")
	var cup = DiceCupScript.new(5)
	for i in range(5): cup.dice[i].value = 2
	var ai = ai_script.new(CardDataScript.get_card_by_id("jack_crt"), cup)
	ai.total_other_dice = 10
	var strong: float = ai.estimate_bid_truth_probability(6, 2, cup.get_values())
	var reckless: float = ai.estimate_bid_truth_probability(13, 5, cup.get_values())
	assert(strong > reckless, "AI必须根据己方骰子与未知骰子的概率区分可靠叫牌和冒险叫牌")
	ai.current_bid_count = 6; ai.current_bid_value = 2
	var bid: Dictionary = ai.make_bid()
	assert(int(bid.count) <= 9, "没有充分证据时AI不应一次把数量抬得过大")

func _test_growth_curse() -> void:
	var game = DiceGameScript.new()
	game.player_cup = DiceCupScript.new(2)
	game.player_cup.dice[0].value = 1
	game.player_cup.dice[1].value = 4
	GameState.assimilation_curse = "growth_cost"
	for _i in range(6): game._apply_player_round_effects()
	assert(game.player_cup.dice.size() == 5, "增殖代价每场最多增加3颗骰子")
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
	assert(game.ai_cup_3.dice.size() == 9, "Boss庄家应在普通庄家的8骰上额外+1")
	assert(game.get_min_opening() == 5, "四人存活时最低起叫应为人数+1，即5")
	game.game_active = false
	await get_tree().create_timer(4.0).timeout
	for ctrl in [game.ai_controller_1, game.ai_controller_2, game.ai_controller_3]:
		if ctrl: ctrl.set_dice_game(null)
	game.ai_controller_1 = null; game.ai_controller_2 = null; game.ai_controller_3 = null
	game.ai_cup_1 = null; game.ai_cup_2 = null; game.ai_cup_3 = null; game.player_cup = null
	remove_child(game)
	game.free()
