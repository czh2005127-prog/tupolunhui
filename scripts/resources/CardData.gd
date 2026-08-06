class_name CardData
extends Resource

enum Rarity { COMMON, RARE, EPIC, LEGENDARY, GENESIS, UNKNOWN }
enum SkillTrigger { PASSIVE, CONTINUOUS, TRIGGERED }

var card_id: String = ""
var card_name: String = ""
var skill_name: String = ""
var skill_desc: String = ""
var rarity: Rarity = Rarity.COMMON
var skill_trigger: SkillTrigger = SkillTrigger.PASSIVE
var portrait_path: String = ""
var dice_count: int = 0
var skills: Array[Dictionary] = []

static func make(id: String, title: String, tier: int, skill_defs: Array[Dictionary]) -> CardData:
	var card := CardData.new()
	card.card_id = id
	card.card_name = title
	card.rarity = tier as Rarity
	card.skills.assign(skill_defs)
	if not card.skills.is_empty():
		card.skill_name = str(card.skills[0].get("name", ""))
		var lines: Array[String] = []
		for skill in card.skills:
			lines.append("%s：%s" % [skill.get("name", ""), skill.get("desc", "")])
		card.skill_desc = "\n".join(lines)
	return card

static func s(name: String, kind: String, countdown: int, effect: String, desc: String, value: int = 0) -> Dictionary:
	return {"name":name, "kind":kind, "countdown":countdown, "effect":effect, "desc":desc, "value":value}

func get_rarity_name() -> String:
	return ["普通", "稀有", "史诗", "传说", "创世", "未知"][int(rarity)]

func get_rarity_color() -> Color:
	return [Color(0.72,0.72,0.68), Color(0.42,0.68,0.94), Color(0.72,0.40,0.86), Color(0.96,0.72,0.22), Color(0.96,0.28,0.28), Color(0.54,0.28,0.67)][int(rarity)]

static func get_common_pool() -> Array[CardData]:
	return [
		make("jack_crt", "瘸腿老杰克", Rarity.COMMON, [s("偷窥","continuous",3,"protect_high","标记最高点目标骰，玩家卡牌不能选择。"), s("反面预判","trigger",3,"flip_high","翻转最高点目标骰。"), s("重复识破","continuous",4,"modify_limit","限制每颗骰子可被修改次数。",2)]),
		make("rust_warrior", "锈铁战士", Rarity.COMMON, [s("铁锤","trigger",3,"lower_high","降低最高点目标骰。",1), s("锈锁","continuous",3,"no_reroll","目标骰不能重投。"), s("重甲封闭","continuous",4,"limit_add_die","限制卡牌增加骰子。",1)]),
		make("battery_kid", "电池小子", Rarity.COMMON, [s("短路","trigger",3,"reroll_high","重投目标骰，结果提前公开。"), s("电流限制","continuous",3,"card_dice_limit","每张牌最多影响指定数量骰子。",2), s("强制断电","trigger",4,"lock_high","锁定最高点目标骰直到计分。")]),
		make("signal_noise", "信号噪音", Rarity.COMMON, [s("错误频段","continuous",4,"block_category","按比例封锁当前手牌类别。"), s("搜索噪声","continuous",3,"draw_penalty","抽牌和检索数量减少。",1), s("乱码清除","trigger",2,"discard_high_card","弃掉高稀有度目标手牌。")]),
	]

static func get_rare_pool() -> Array[CardData]:
	return [
		make("cyclops_lcd", "独眼龙LCD", Rarity.RARE, [s("点数删除","continuous",4,"disable_face_pattern","声明点数不能组成骰型。",1), s("锁定射线","continuous",3,"lock_face","声明点数不能被修改。",1), s("刷新屏幕","trigger",3,"flip_face","翻转声明点数骰。",1)]),
		make("two_face", "双面人", Rarity.RARE, [s("反转协议","continuous",4,"flip_after_change","明确改变点数后再翻转。"), s("双重操作","continuous",3,"duplicate_single","单目标骰子牌额外影响另一颗。"), s("全面翻转","trigger",3,"flip_all","翻转全部未锁定骰。")]),
		make("chamberlain", "侍从长", Rarity.RARE, [s("军械记录","continuous",4,"block_repeat_name","记录最先使用的牌名并封锁同名牌。",1), s("装备检查","continuous",3,"block_persistent","封锁持续型与复制类牌。"), s("强制收缴","trigger",3,"discard_high_card","弃掉高稀有度目标手牌。")]),
	]

static func get_epic_pool() -> Array[CardData]:
	return [
		make("recycler", "回收商", Rarity.EPIC, [s("捡骰","trigger",4,"remove_low_die","最低点目标骰离场，计分后返回。"), s("废牌封存","continuous",4,"seal_discard","封存弃牌堆高稀有度目标牌。"), s("回收磁场","continuous",3,"seal_voluntary_discard","主动弃牌被封存至效果结束。")]),
		make("lucky_one", "幸运儿", Rarity.EPIC, [s("幸运窃取","continuous",4,"reroll_take_low","目标骰重投两次取较低。"), s("命运封锁","continuous",3,"no_direct_change","目标骰不能直接设值或加减。"), s("一点偏爱","trigger",4,"high_to_one","最高点目标骰变为①。")]),
		make("referee", "裁判长", Rarity.EPIC, [s("证物保全","continuous",4,"protect_high","目标骰不能改变。"), s("重复违规","continuous",4,"limit_card_names","限制同名牌重复使用。",2), s("强制封盘","trigger",5,"seal_hand","封锁剩余手牌直到计分。")]),
		make("mirror_tech", "镜面技师", Rarity.EPIC, [s("镜像连接","continuous",4,"mirror_die","核心骰操作复制给目标骰。"), s("镜像重构","trigger",3,"copy_low_to_high","高点目标骰复制最低点。"), s("镜像回声","continuous",4,"undo_multi","多骰牌结算后目标骰复原。")]),
		make("table_ghost", "赌桌幽灵", Rarity.EPIC, [s("附身","continuous",4,"haunt_hand","目标牌不能主动弃掉或保留。"), s("亡者占位","continuous",4,"occupy_hand","按比例占据手牌上限。"), s("鬼手拖拽","trigger",3,"bottom_high_card","高稀有度目标手牌送至牌库底。")]),
	]

static func get_legendary_pool() -> Array[CardData]:
	return [
		make("alliance_oled", "同盟OLED", Rarity.LEGENDARY, [s("全知扫描","continuous",4,"protect_optimal","当前最优骰型中贡献最高的目标骰不能修改。"), s("行动预读","continuous",4,"used_to_bottom","高稀有度目标牌使用后送至牌库底。"), s("情报共享","continuous",5,"copy_restriction","复制另一对手的目标限制。")]),
		make("casino_owner", "赌场主", Rarity.LEGENDARY, [s("暗骰加码","continuous",5,"hide_dice","目标骰隐藏点数但仍可操作。"), s("暗骰封锁","continuous",4,"hide_lock_dice","目标骰隐藏且不能成为目标。"), s("黑幕摇骰","trigger",3,"hidden_reroll","暗中重投目标骰。")]),
		make("prophet", "算法先知", Rarity.LEGENDARY, [s("局部重算","trigger",3,"reroll_high","重投最高点目标骰，结果预告。"), s("反复迭代","continuous",4,"reroll_after_change","玩家修改目标骰后额外重投。"), s("路径剪枝","continuous",4,"protect_optimal","锁定当前最优骰型目标骰。")]),
		make("dealer", "庄家", Rarity.LEGENDARY, [s("开盘","continuous",4,"cover_hand","覆盖目标手牌，使用后逐张公开。"), s("洗牌","trigger",3,"shuffle_high_hand","高稀有度目标手牌送回抽牌堆并抽等量。"), s("压桌","continuous",4,"no_lock","目标骰不能被锁定。")]),
	]

static func get_genesis_pool() -> Array[CardData]:
	return [make("dice_god", "骰子之神HOLO", Rarity.GENESIS, [s("禁忌刻印","continuous",4,"forbidden_faces","目标骰不能被卡牌改成禁忌面。"), s("神骰重铸","trigger",3,"reroll_high","重投最高点目标骰。"), s("木盒吞牌","trigger",4,"bottom_high_card","高稀有度目标手牌送至牌库底。"), s("锈蚀轮回","continuous",5,"rust_used_cards","目标牌使用后锈蚀占位。")])]

static func get_unknown_pool() -> Array[CardData]:
	return [
		make("unknown_mirror", "???·镜像", Rarity.UNKNOWN, [s("广播","continuous",4,"link_common_face","最多点数组同步明确点数操作。"), s("对称交换","trigger",3,"swap_high_low","最高点与最低点目标骰交换。"), s("镜像手牌","continuous",4,"pair_hand","目标手牌配对，使用一张后封锁另一张。")]),
		make("unknown_chaos", "???·混沌", Rarity.UNKNOWN, [s("乱码","continuous",4,"rotate_card_effects","目标手牌效果循环错位并公开。"), s("目标错位","continuous",3,"redirect_dice","目标骰操作重定向至公开映射。"), s("混沌重组","trigger",3,"randomize_dice","改变目标骰，结果预告。")]),
		make("unknown_abyss", "???·深渊", Rarity.UNKNOWN, [s("吞骰","continuous",5,"remove_high_die","最高点目标骰离场后原样返回。"), s("吞牌","continuous",4,"remove_high_card","高稀有度目标手牌离场后返回。"), s("吞噬牌库","continuous",5,"remove_draw_cards","抽牌堆顶目标牌离场后按原序返回。")]),
	]

static func get_pool_by_rarity(tier: Rarity) -> Array[CardData]:
	match tier:
		Rarity.COMMON: return get_common_pool()
		Rarity.RARE: return get_rare_pool()
		Rarity.EPIC: return get_epic_pool()
		Rarity.LEGENDARY: return get_legendary_pool()
		Rarity.GENESIS: return get_genesis_pool()
		Rarity.UNKNOWN: return get_unknown_pool()
	return []

static func get_all_cards() -> Array[CardData]:
	var result: Array[CardData] = []
	for pool in [get_common_pool(), get_rare_pool(), get_epic_pool(), get_legendary_pool(), get_genesis_pool(), get_unknown_pool()]:
		result.append_array(pool)
	return result

static func get_card_by_id(id: String) -> CardData:
	for card in get_all_cards():
		if card.card_id == id:
			return card
	return null
