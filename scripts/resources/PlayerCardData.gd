class_name PlayerCardData
extends Resource

enum Rarity { COMMON, RARE, LEGENDARY }

var card_id: String = ""
var card_name: String = ""
var category: String = ""
var description: String = ""
var rarity: Rarity = Rarity.COMMON
var effect: String = ""
var amount: int = 0
var secondary: int = 0

static func make(id: String, title: String, group: String, desc: String, tier: int, effect_id: String, value: int = 0, extra: int = 0) -> PlayerCardData:
	var card := PlayerCardData.new()
	card.card_id = id
	card.card_name = title
	card.category = group
	card.description = desc
	card.rarity = tier as Rarity
	card.effect = effect_id
	card.amount = value
	card.secondary = extra
	return card

func get_rarity_name() -> String:
	return ["普通", "稀有", "传说"][int(rarity)]

func get_rarity_color() -> Color:
	return [Color(0.76, 0.74, 0.68), Color(0.36, 0.67, 0.94), Color(0.96, 0.72, 0.22)][int(rarity)]

static func get_starter_deck_ids() -> Array[String]:
	return ["reroll_stone", "reroll_stone", "flip_die", "freeze_die", "old_chip", "amp_gear"]

static func get_all_cards() -> Array[PlayerCardData]:
	return [
		# 普通
		make("reroll_stone", "重摇石", "骰子", "重投1颗骰子。", Rarity.COMMON, "reroll", 1),
		make("flip_die", "翻转骰", "骰子", "翻转1颗骰子：①↔⑥、②↔⑤、③↔④。", Rarity.COMMON, "flip", 1),
		make("freeze_die", "定格骰", "骰子", "锁定1颗骰子，使其下轮不参与基础投掷。", Rarity.COMMON, "lock", 1),
		make("calibration_wrench", "校准扳手", "骰子", "1颗骰子+1或-1，不循环。", Rarity.COMMON, "adjust", 1),
		make("shock_stone", "震荡石", "骰子", "恰好重投2颗骰子。", Rarity.COMMON, "reroll", 2),
		make("full_reroll", "全重摇", "骰子", "重投全部未锁定骰子。", Rarity.COMMON, "reroll_all"),
		make("pair_rivet", "对子铆钉", "骰型", "本轮每个恰好对子额外+2倍率。", Rarity.COMMON, "pair_bonus", 2),
		make("short_straight_wire", "短顺接线", "骰型", "本轮每个恰好三连顺额外+2倍率。", Rarity.COMMON, "straight3_bonus", 2),
		make("variety_gear", "杂色齿轮", "骰型", "本轮至少出现4种点数时，倍率+2。", Rarity.COMMON, "variety_bonus", 2, 4),
		make("amp_gear", "增幅齿轮", "倍率", "本轮倍率+1。", Rarity.COMMON, "mult", 1),
		make("old_chip", "旧芯片", "点数", "本轮基础点数+8。", Rarity.COMMON, "chips", 8),
		make("high_capacitor", "高点电容", "点数", "每颗④⑤⑥额外+2基础点数。", Rarity.COMMON, "face_group_chips", 2, 1),
		make("even_wire", "偶数导线", "点数", "每颗②④⑥额外+2基础点数。", Rarity.COMMON, "face_group_chips", 2, 2),
		make("scavenge", "翻找", "牌库", "抽2张牌。", Rarity.COMMON, "draw", 2),
		make("hand_sort", "手牌整理", "牌库", "弃至多2张，再抽等量牌。", Rarity.COMMON, "discard_draw", 2),
		make("trade_scrap", "破旧换新", "牌库", "恰好弃2张，抽3张。", Rarity.COMMON, "discard_draw", 2, 3),
		make("insulation", "绝缘外壳", "防护", "1颗骰子免疫下一次敌方效果。", Rarity.COMMON, "protect_die", 1),
		make("signal_fuse", "信号保险", "防护", "1张手牌免疫下一次敌方效果。", Rarity.COMMON, "protect_card", 1),
		make("coin_purse", "零钱包", "金币", "本轮计分后获得4金币。", Rarity.COMMON, "gold", 4),
		make("face_bounty", "点数悬赏", "金币", "指定点数，本轮每出现1颗获得1金币，最多5。", Rarity.COMMON, "face_gold", 1, 5),
		make("thrift", "节俭", "金币", "若是本轮唯一使用的牌，获得7金币。", Rarity.COMMON, "sole_gold", 7),
		make("lucky_coin", "幸运硬币", "风险", "50%基础点数+20，否则随机弃1张其他手牌。", Rarity.COMMON, "coin_flip", 20),
		# 稀有
		make("clone_die", "克隆骰", "骰子", "复制1颗骰子并新增1颗。", Rarity.RARE, "clone", 1),
		make("split_die", "裂变骰", "骰子", "将1颗≥4点骰子拆成两颗，点数之和不变。", Rarity.RARE, "split", 1),
		make("group_calibration", "群体校准", "骰子", "调整至多三分之一骰子，各±1。", Rarity.RARE, "adjust_ratio", 1),
		make("spare_dice_bag", "备用骰袋", "骰子", "本场增加1颗骰子并立即投掷。", Rarity.RARE, "add_die", 1),
		make("pair_mold", "对子锻模", "骰型", "选择2颗骰子，较低者变为较高者。", Rarity.RARE, "make_pair", 1),
		make("straight_mold", "顺子刻模", "骰型", "调整1颗骰子以组成三连顺。", Rarity.RARE, "make_straight", 1),
		make("face_plating", "点面镀层", "点数", "指定点数，本轮每颗额外+4基础点数。", Rarity.RARE, "face_chips", 4),
		make("chain_chip", "连锁芯片", "倍率", "本轮每种不同骰型+2倍率。", Rarity.RARE, "type_bonus", 2),
		make("triple_power", "三连动力", "倍率", "每个三条或三连顺额外+3倍率。", Rarity.RARE, "triple_bonus", 3),
		make("round_amp", "回合放大器", "倍率", "作为本轮第3张牌使用时倍率+4。", Rarity.RARE, "third_mult", 4),
		make("direct_search", "定向检索", "牌库", "从抽牌堆选择1张加入手牌。", Rarity.RARE, "search_draw", 1),
		make("reverse_search", "逆向检索", "牌库", "从弃牌堆选择1张加入手牌。", Rarity.RARE, "recover", 1),
		make("copy_paper", "复制纸", "牌库", "复制1张非复制类手牌，本轮结束消失。", Rarity.RARE, "copy", 1),
		make("scrap_turbine", "废牌涡轮", "牌库", "弃任意牌，每张使本轮基础点数+5。", Rarity.RARE, "discard_chips", 5),
		make("counter_protocol", "反制协议", "防护", "取消下一次影响玩家的触发型敌方技能。", Rarity.RARE, "counter", 1),
		make("pattern_contract", "骰型委托", "金币", "指定骰型；形成则+10金币，否则-3金币。", Rarity.RARE, "pattern_gold", 10, 3),
		make("gold_furnace", "黄金熔炉", "金币", "移出本场至多3张手牌，每张获得4金币。", Rarity.RARE, "exhaust_gold", 4, 3),
		make("risk_investment", "风险投资", "金币", "支付5金币；本轮达到目标30%时返还15。", Rarity.RARE, "investment", 15, 5),
		# 传说
		make("fate_die", "命运骰", "骰子", "固定1颗骰子3个计分轮。", Rarity.LEGENDARY, "fate_lock", 3),
		make("mirror_node", "镜面节点", "骰子", "第二颗骰子复制第一颗当前点数与本轮增益。", Rarity.LEGENDARY, "mirror", 1),
		make("overload_storage", "过载骰仓", "骰子", "本场增加2颗骰子，随机弃1张手牌。", Rarity.LEGENDARY, "add_die_discard", 2, 1),
		make("golden_face", "黄金面", "点数", "指定点数，本轮每颗额外+8基础点数。", Rarity.LEGENDARY, "face_chips", 8),
		make("final_amplifier", "最终放大器", "倍率", "本轮最终分数×2。", Rarity.LEGENDARY, "final_mult", 2),
		make("full_draw", "满载抽取", "牌库", "抽牌直到手牌达到10张，不中途洗牌。", Rarity.LEGENDARY, "draw_to_max", 10),
		make("mirror_archive", "镜像档案", "牌库", "复制本轮上一张非复制类卡牌。", Rarity.LEGENDARY, "repeat_last", 1),
		make("forbidden_roulette", "禁忌轮盘", "风险", "全部未锁定骰变为①，本轮最终分数×3。", Rarity.LEGENDARY, "forbidden_roulette", 3),
		make("gold_printer", "黄金打印机", "金币", "本场每轮首次形成骰型+3金币，最多15。", Rarity.LEGENDARY, "battle_gold_engine", 3, 15),
		make("king_contract", "国王契约", "金币", "立即+30金币，本场目标提高25%。", Rarity.LEGENDARY, "king_contract", 30, 25),
		make("winner_take_all", "胜者通吃", "金币", "本场奖励+50%；第5轮才通关则无基础金币。", Rarity.LEGENDARY, "winner_take_all", 50),
		make("alchemy", "点金术", "金币", "指定点数，每颗参与骰型的该点数+2金币，最多6。", Rarity.LEGENDARY, "alchemy", 2, 6),
	]

static func get_by_id(id: String) -> PlayerCardData:
	for card in get_all_cards():
		if card.card_id == id:
			return card
	return null

static func get_pool(rarity_filter: int = -1) -> Array[PlayerCardData]:
	var result: Array[PlayerCardData] = []
	for card in get_all_cards():
		if rarity_filter < 0 or int(card.rarity) == rarity_filter:
			result.append(card)
	return result
