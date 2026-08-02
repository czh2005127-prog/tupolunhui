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
const RustWorkshopScript := preload("res://scripts/ui/RustWorkshop.gd")
const DiceGameScene := preload("res://scenes/gameflow/DiceGameScene.tscn")
const EventUIScript := preload("res://scripts/ui/EventUI.gd")

func _ready() -> void:
	GameState.tutorial_completed = true
	_test_all_project_scripts_load()
	_test_dynamic_candidates()
	_test_card_draw_runtime_types()
	_test_pair_fix()
	_test_fragment_inventory()
	_test_six_item_capacity()
	_test_three_stage_curve()
	_test_upgrade_migration()
	_test_battle_entry_snapshot()
	_test_break_score_progression()
	_test_break_score_dice_awards()
	_test_prisoner_king_arc()
	_test_duplicate_card_weight()
	_test_event_score_weight()
	_test_random_stage_nodes()
	_test_forbidden_rewards_and_payout()
	_test_prisoner_contract_objectives()
	_test_event_gold_does_not_request_item_swap()
	_test_shop_build()
	await _test_tutorial_bar_separation()
	_test_ai_probability_logic()
	_test_cyclops_keeps_legal_player_bid()
	_test_growth_curse()
	await _test_rust_workshop_rebuild()
	await _test_duplicate_dealers()
	await _test_boss_dealer()
	await _test_dice_god_phases()
	print("RULE_LOGIC_SMOKE_OK")
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0)

func _test_all_project_scripts_load() -> void:
	var script_paths: Array[String] = []
	_collect_script_paths("res://scripts", script_paths)
	for script_path in script_paths:
		assert(ResourceLoader.load(script_path) != null, "项目脚本无法加载: %s" % script_path)

func _collect_script_paths(directory: String, output: Array[String]) -> void:
	for file_name in DirAccess.get_files_at(directory):
		if file_name.ends_with(".gd"):
			output.append(directory.path_join(file_name))
	for child_directory in DirAccess.get_directories_at(directory):
		_collect_script_paths(directory.path_join(child_directory), output)

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

func _test_card_draw_runtime_types() -> void:
	assert(CardPoolScript.draw_cards(0, false).size() == 2)
	assert(CardPoolScript.draw_cards(0, true).size() == 3)

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

func _test_six_item_capacity() -> void:
	var old_items: Array[String] = GameState.consumable_items.duplicate()
	GameState.consumable_items.clear()
	for i in range(GameState.MAX_CONSUMABLE):
		assert(GameState.add_consumable_item("test_item_%d" % i))
	assert(GameState.MAX_CONSUMABLE == 6 and GameState.consumable_items.size() == 6)
	GameState.consumable_items.assign(old_items)

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

func _test_break_score_progression() -> void:
	var old_stage: int = GameState.current_stage
	var old_scores: Array[int] = GameState.stage_break_scores.duplicate()
	var old_battle_score: int = GameState.current_battle_break_score
	var old_streak: int = GameState.current_break_streak
	GameState.current_stage = 0
	GameState.stage_break_scores.assign([0, 0, 0, 0])
	GameState.begin_break_score_battle()
	assert(GameState.get_stage_break_target() == 1500)
	assert(GameState.add_break_score(100, 3, "精准看破") == 300)
	assert(GameState.add_break_score(100, 1, "镇场") == 200, "第二次连续得分必须应用×2")
	GameState.reset_break_score_streak()
	assert(GameState.add_break_score(100, 1, "瞒天") == 100)
	assert(GameState.get_stage_break_score() == 600 and GameState.current_battle_break_score == 600)
	GameState.stage_break_scores[0] = 1500
	assert(GameState.is_stage_break_qualified() and GameState.get_stage_break_rating() == "合格")
	var jack = CardDataScript.get_card_by_id("jack_crt")
	var warrior = CardDataScript.get_card_by_id("rust_warrior")
	GameState.capture_battle_entry([jack, warrior])
	GameState.stage_break_scores[0] = 2300
	assert(GameState.prepare_boss_break_score_retry())
	assert(GameState.stage_break_scores[0] == 2300, "Boss未达标重战必须保留已获得的本层分数")
	assert(GameState.current_battle_break_score == 0 and GameState.current_break_streak == 0)
	assert(GameState.current_battle_seed == 0, "Boss计分重战必须生成新的随机种子")
	GameState.clear_battle_entry()
	GameState.current_stage = old_stage
	GameState.stage_break_scores.assign(old_scores)
	GameState.current_battle_break_score = old_battle_score
	GameState.current_break_streak = old_streak

func _test_break_score_dice_awards() -> void:
	var old_stage: int = GameState.current_stage
	var old_scores: Array[int] = GameState.stage_break_scores.duplicate()
	GameState.current_stage = 0
	GameState.stage_break_scores.assign([0, 0, 0, 0])
	GameState.begin_break_score_battle()
	var game = DiceGameScript.new()
	game.player_cup = DiceCupScript.new(2)
	game.ai_cup_1 = DiceCupScript.new(2)
	game.ai_cup_2 = DiceCupScript.new(0)
	game.ai_cup_3 = DiceCupScript.new(0)
	for die in game.player_cup.dice: die.value = 2
	for die in game.ai_cup_1.dice: die.value = 2
	game.ai1_virus = 0
	game.ai2_virus = game.AI_MAX_VIRUS
	game.ai3_virus = game.AI_MAX_VIRUS
	game.current_bid_count = 3
	game.current_bid_value = 4
	game._award_player_challenge_score("player", "ai1", 2, false, "ai1")
	assert(GameState.get_stage_break_score() == 3600, "精准看破、高压叫牌和两颗残骰倍率必须共同结算")
	game.current_bid_count = 3
	game.current_bid_value = 6
	game._award_accepted_player_bluff()
	assert(GameState.get_stage_break_score() > 3600, "AI放过虚假玩家叫牌时必须结算瞒天得分")
	game.free()
	GameState.current_stage = old_stage
	GameState.stage_break_scores.assign(old_scores)
	GameState.current_battle_break_score = 0
	GameState.current_break_streak = 0

func _test_prisoner_king_arc() -> void:
	GameState.prisoner_offer_stages.clear()
	GameState.prisoner_accepted_stages.clear()
	GameState.prisoner_breaches = 0
	GameState.prisoner_identity_revealed = false
	GameState.royal_fragment_available = false
	assert(GameState.prisoner_can_appear(0) and GameState.prisoner_can_appear(1))
	GameState.record_prisoner_offer(0)
	GameState.record_prisoner_acceptance(0)
	assert(not GameState.prisoner_can_appear(2), "前两层没有全部接受时，囚徒不得进入后两层")
	GameState.record_prisoner_offer(1)
	GameState.record_prisoner_acceptance(1)
	assert(GameState.prisoner_can_appear(2) and GameState.prisoner_king_arc_complete())
	GameState.prisoner_breaches = 3
	assert(not GameState.prisoner_can_appear(2) and not GameState.prisoner_king_arc_complete(), "违约三次后囚徒必须离开本盘")
	GameState.prisoner_breaches = 0
	GameState.gold = 41
	GameState.royal_fragment_available = true
	var jack = CardDataScript.get_card_by_id("jack_crt")
	var warrior = CardDataScript.get_card_by_id("rust_warrior")
	GameState.capture_battle_entry([jack, warrior])
	GameState.gold = 0
	assert(GameState.consume_royal_fragment_retry(false), "王权碎片应恢复骰子之神战斗入口状态")
	assert(GameState.gold == 41 and not GameState.royal_fragment_available)
	assert(not GameState.consume_royal_fragment_retry(false), "王权碎片只能使用一次")
	GameState.clear_battle_entry()
	GameState.prisoner_offer_stages.clear()
	GameState.prisoner_accepted_stages.clear()
	GameState.prisoner_breaches = 0
	GameState.prisoner_identity_revealed = false

func _test_duplicate_card_weight() -> void:
	var old_unlocks: Array[String] = GameState.unlocked_cards.duplicate()
	GameState.unlocked_cards.assign(["jack_crt", "rust_warrior", "battery_kid"])
	seed(20260801)
	var duplicate_draws: int = 0
	var common_pool: Array = CardDataScript.get_common_pool()
	const SAMPLE_COUNT: int = 2000
	for _i in range(SAMPLE_COUNT):
		var draw: Array = CardPoolScript._pick_from(common_pool, 3)
		var ids: Array = draw.map(func(card): return card.card_id)
		if ids.size() == 3 and (ids[0] == ids[1] or ids[0] == ids[2] or ids[1] == ids[2]):
			duplicate_draws += 1
	var rate: float = float(duplicate_draws) / SAMPLE_COUNT
	assert(rate > 0.08 and rate < 0.40, "重复牌应保留小概率，但不能成为常态")
	GameState.unlocked_cards.assign(old_unlocks)

func _test_event_score_weight() -> void:
	var old_events: int = GameState.events_completed
	var old_bosses: Array[String] = GameState.bosses_defeated.duplicate()
	var old_gold: int = GameState.gold
	var old_assimilations: int = GameState.total_assimilations
	GameState.events_completed = 3
	GameState.bosses_defeated.clear()
	GameState.gold = 0
	GameState.total_assimilations = 0
	var result: Dictionary = GameState.calculate_score()
	assert(result.event_bonus == 36 and result.score == 36, "事件分数应降低为每次12分")
	GameState.events_completed = old_events
	GameState.bosses_defeated.assign(old_bosses)
	GameState.gold = old_gold
	GameState.total_assimilations = old_assimilations

func _test_random_stage_nodes() -> void:
	GameState.stage_node_orders.clear()
	for _sample in range(100):
		var sampled_flow = GameFlowScript.new()
		sampled_flow.current_stage_index = 0
		sampled_flow._generate_nodes()
		assert(not (sampled_flow.nodes_this_stage[0] == GameFlowScript.NodeType.EVENT and sampled_flow.nodes_this_stage[1] == GameFlowScript.NodeType.EVENT), "每层不得连续两个事件开场")
		sampled_flow.free()
		GameState.stage_node_orders.clear()
	var flow = GameFlowScript.new()
	flow.current_stage_index = 0
	flow._generate_nodes()
	assert(flow.nodes_this_stage.size() == 6)
	assert(flow.nodes_this_stage.back() == GameFlowScript.NodeType.BOSS)
	assert(flow.nodes_this_stage.count(GameFlowScript.NodeType.DICE) == 2)
	assert(flow.nodes_this_stage.count(GameFlowScript.NodeType.SHOP) == 1)
	assert(flow.nodes_this_stage.count(GameFlowScript.NodeType.EVENT) == 2)
	assert(flow.nodes_this_stage.find(GameFlowScript.NodeType.DICE) < flow.nodes_this_stage.find(GameFlowScript.NodeType.SHOP), "商店前必须至少有一场战斗")
	flow.free()
	GameState.stage_node_orders = {"0": [GameFlowScript.NodeType.DICE, GameFlowScript.NodeType.SHOP, GameFlowScript.NodeType.DICE, GameFlowScript.NodeType.EVENT, GameFlowScript.NodeType.BOSS]}
	var migrated_flow = GameFlowScript.new()
	migrated_flow.current_stage_index = 0
	migrated_flow._generate_nodes()
	assert(migrated_flow.nodes_this_stage.size() == 6 and migrated_flow.nodes_this_stage[-2] == GameFlowScript.NodeType.EVENT, "旧五节点存档应在Boss前补入事件")
	migrated_flow.free()
	GameState.stage_node_orders.clear()
	var event_ui = EventUIScript.new()
	var event_pool: Array[Dictionary] = event_ui._get_pool()
	assert(event_pool.size() == 12, "正式事件池应包含四层各三个剧情事件")
	for stage in range(4):
		assert(event_pool.filter(func(event): return stage in event.stages).size() == 3)
	event_ui.free()

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

func _test_prisoner_contract_objectives() -> void:
	var game = DiceGameScript.new()
	GameState.current_contract = {"id": "five_twos"}
	game._contract_five_twos = true
	assert(game.contract_was_completed())
	GameState.current_contract = {"id": "three_faces"}
	game._contract_bid_faces.assign([2, 4, 6])
	assert(game.contract_was_completed())
	GameState.current_contract = {"id": "three_rounds"}
	game.round_number = 3
	assert(game.contract_was_completed())
	GameState.current_contract.clear()
	game.free()

func _test_event_gold_does_not_request_item_swap() -> void:
	var old_items: Array[String] = GameState.consumable_items.duplicate()
	var old_gold: int = GameState.gold
	GameState.consumable_items.assign(["a", "b", "c", "d", "e", "f"])
	var event_ui = EventUIScript.new()
	event_ui._apply_result({"id": "memory_fragment", "type": EventUIScript.Category.NARRATIVE}, "b")
	assert(GameState.gold == old_gold + 25)
	assert(not event_ui._pending_discard and event_ui._expected_discard_item.is_empty(), "纯金币事件不得触发道具替换")
	event_ui.free()
	GameState.gold = old_gold
	GameState.consumable_items.assign(old_items)

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

func _test_tutorial_bar_separation() -> void:
	var hud = DiceGameScene.instantiate()
	add_child(hud)
	await get_tree().process_frame
	EventBus.tutorial_hint_show.emit("教程测试", 5.0)
	assert(hud.get("_tutorial_bar").visible, "教程应显示在独立教程栏")
	assert(hud.get("_tutorial_label").text == "教程测试")
	assert(hud.get("_notify_label").text != "教程测试", "教程不得覆盖现有提示栏")
	assert(hud.find_child("TutorialReviewButton", true, false) != null)
	assert(hud.find_child("BreakScoreBoard", true, false) != null, "每场对局必须显示独立实时计分板")
	hud._toggle_tutorial_review()
	assert(hud.get("_tutorial_review_panel").visible, "教程回顾栏应能独立打开")
	assert("教程测试" in hud.get("_tutorial_review_text").text)
	hud._on_dice_revealed([1, 4], [2, 2, 5], [3], [], true, true, false, false)
	assert("你（2颗）" in hud._get_final_dice_summary() and "（3颗）" in hud._get_final_dice_summary(), "对局结算必须保留最后开骰的数量与点数")
	var old_stage_score: int = GameState.stage_break_scores[GameState.current_stage]
	GameState.stage_break_scores[GameState.current_stage] = 0
	hud._show_boss_break_qualification()
	var qualification = hud.find_child("BossBreakQualification", true, false)
	assert(qualification != null and qualification.find_child("FinalDiceSummary", true, false) != null, "Boss胜利后必须显示含最后开骰的合格判定页")
	qualification.queue_free()
	GameState.stage_break_scores[GameState.current_stage] = old_stage_score
	hud._show_death_screen()
	var final_dice_panel = hud.find_child("FinalDiceSummary", true, false)
	assert(final_dice_panel != null and "最后开骰" in final_dice_panel.text, "死亡结算必须展示最后开骰")
	GameState.gold = 8
	GameState.current_contract = {"id": "five_twos", "title": "五个二", "penalty_type": "gold", "penalty": 12}
	hud.game_ctrl._contract_five_twos = false
	hud._resolve_prisoner_contract()
	assert(GameState.gold == 0, "囚徒契约违约扣款不得使金币变成负数")
	GameState.current_contract = {"id": "three_rounds", "title": "熬过三轮", "penalty_type": "next_die", "penalty": 1}
	hud.game_ctrl.round_number = 1
	hud._resolve_prisoner_contract()
	assert(GameState.get_bonus_dice_count() == -1, "熬过三轮违约应使下一战少一骰")
	GameState.current_contract.clear()
	remove_child(hud)
	hud.free()

func _test_rust_workshop_rebuild() -> void:
	var workshop = RustWorkshopScript.new()
	add_child(workshop)
	await get_tree().process_frame
	await get_tree().process_frame
	await workshop._build()
	remove_child(workshop)
	workshop.free()

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

func _test_cyclops_keeps_legal_player_bid() -> void:
	var old_curse: String = GameState.assimilation_curse
	GameState.assimilation_curse = "double_wild"
	var game = DiceGameScript.new()
	game._cyclops_locks.assign([2, 4, 5, 6])
	game._ensure_player_callable_face()
	var legal: Dictionary = game.find_legal_player_bid(game.get_min_opening(), 2)
	assert(not legal.is_empty() and int(legal.value) not in [1, 3] and int(legal.value) not in game._cyclops_locks, "独眼龙与禁叫效果叠加后必须保留合法叫牌")
	game.free()
	GameState.assimilation_curse = old_curse

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
	var public_context: Dictionary = game._build_public_ai_context("ai1")
	assert(not public_context.has("player_dice_values") and not public_context.has("current_contract"), "AI公开上下文不得泄露玩家暗骰或囚徒契约")
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

func _test_dice_god_phases() -> void:
	var commons: Array = CardDataScript.get_common_pool()
	var dice_god = CardDataScript.get_card_by_id("dice_god")
	var game = DiceGameScript.new()
	add_child(game)
	GameState.current_stage = 3
	GameState.assimilation_count = 0
	game.start_game(commons[0], commons[1], false, dice_god, true)
	game.game_active = false
	assert(game._dice_god_phase == 1)
	assert(game.ai_controller_3.infect())
	assert(game._try_advance_dice_god_phase("ai3"), "骰子之神首次应被淘汰时应进入第二阶段")
	assert(game._dice_god_phase == 2 and game.ai3_virus == 0 and game.ai_cup_3.dice.size() == 3)
	assert(game.ai_controller_3.infect(), "骰子之神第二条命耗尽时应被淘汰")
	assert(not game._try_advance_dice_god_phase("ai3"), "骰子之神不得出现第三阶段")
	await get_tree().create_timer(4.0).timeout
	for ctrl in [game.ai_controller_1, game.ai_controller_2, game.ai_controller_3]:
		if ctrl: ctrl.set_dice_game(null)
	game.ai_controller_1 = null; game.ai_controller_2 = null; game.ai_controller_3 = null
	game.ai_cup_1 = null; game.ai_cup_2 = null; game.ai_cup_3 = null; game.player_cup = null
	remove_child(game)
	game.free()
