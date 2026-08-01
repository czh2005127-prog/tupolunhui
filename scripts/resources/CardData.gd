## Card data resource — defines one opponent card.
## Each card has a unique skill that fires at a specific trigger point.
class_name CardData
extends Resource

enum Rarity { COMMON, RARE, EPIC, LEGENDARY, GENESIS, UNKNOWN }
enum SkillTrigger { ON_BEFORE_BID, ON_AFTER_BID, ON_CHALLENGED, ON_ROUND_END, ON_ELIMINATED, PASSIVE, ON_GAME_START }

@export var card_id: String = ""
@export var card_name: String = ""
@export var skill_name: String = ""
@export var skill_desc: String = ""
@export var rarity: Rarity = Rarity.COMMON
@export var skill_trigger: SkillTrigger = SkillTrigger.PASSIVE
@export var portrait_path: String = ""
@export var dice_count: int = 5

func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON: return "普通"
		Rarity.RARE: return "稀有"
		Rarity.EPIC: return "史诗"
		Rarity.LEGENDARY: return "传说"
		Rarity.GENESIS: return "创世"
		Rarity.UNKNOWN: return "未知"
	return ""

func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON: return Color(0.7, 0.7, 0.66)
		Rarity.RARE: return Color(0.52, 0.72, 0.92)
		Rarity.EPIC: return Color(0.75, 0.45, 0.85)
		Rarity.LEGENDARY: return Color(0.98, 0.78, 0.29)
		Rarity.GENESIS: return Color(0.98, 0.35, 0.35)
		Rarity.UNKNOWN: return Color(0.55, 0.35, 0.65)
	return Color.WHITE

static func make(id: String, cname: String, sname: String, desc: String, r: int, t: int, dice: int = 5) -> CardData:
	var card := CardData.new()
	card.card_id = id
	card.card_name = cname
	card.skill_name = sname
	card.skill_desc = desc
	card.rarity = r as Rarity
	card.skill_trigger = t as SkillTrigger
	card.dice_count = dice
	return card


## ---------- FULL CARD POOL (20 cards) ----------

static func get_common_pool() -> Array[CardData]:
	return [
		make("jack_crt", "瘸腿老杰克", "偷窥", "每局1次：随机看玩家1颗骰子", Rarity.COMMON, SkillTrigger.ON_BEFORE_BID),
		make("rust_warrior", "锈铁战士", "意志依存", "被淘汰时随机给一个存活者+1颗①", Rarity.COMMON, SkillTrigger.ON_ELIMINATED),
		make("battery_kid", "电池小子", "备用电源", "第一次被击败免死，回1HP", Rarity.COMMON, SkillTrigger.PASSIVE),
		make("signal_noise", "信号噪音", "干扰", "开局随机禁用玩家1个道具", Rarity.COMMON, SkillTrigger.ON_GAME_START),
	]

static func get_rare_pool() -> Array[CardData]:
	return [
		make("cyclops_lcd", "独眼龙LCD", "锁定", "每局1次：删1个点数；高等级可公开普通骰", Rarity.RARE, SkillTrigger.ON_BEFORE_BID),
		make("two_face", "双面人", "反转骰", "每颗骰子正反面通用，⑥=万能", Rarity.RARE, SkillTrigger.PASSIVE),
		make("chamberlain", "侍从长", "军械库", "开局获得3个只影响自身的随机道具", Rarity.RARE, SkillTrigger.ON_GAME_START),
	]

static func get_epic_pool() -> Array[CardData]:
	return [
		make("recycler", "回收商", "捡骰", "有人开失败时他+1骰子", Rarity.EPIC, SkillTrigger.PASSIVE),
		make("lucky_one", "幸运儿", "骰神眷顾", "骰子里永远多1个①", Rarity.EPIC, SkillTrigger.PASSIVE),
		make("referee", "裁判长", "强制执行", "每局有限次数强制一个对手立即质疑或叫牌", Rarity.EPIC, SkillTrigger.PASSIVE),
		make("mirror_tech", "镜面技师", "镜像", "复制玩家骰子及玩家的自身战斗道具", Rarity.EPIC, SkillTrigger.PASSIVE),
		make("table_ghost", "赌桌幽灵", "附身", "淘汰后附身1个对手(+1骰子+幽灵技能)", Rarity.EPIC, SkillTrigger.ON_ELIMINATED),
	]

static func get_legendary_pool() -> Array[CardData]:
	return [
		make("alliance_oled", "同盟OLED", "全知", "开局随机让1个对手看到你的骰子", Rarity.LEGENDARY, SkillTrigger.ON_GAME_START),
		make("casino_owner", "赌场主", "暗骰加码", "每人+1颗暗骰(他自己也看不到)", Rarity.LEGENDARY, SkillTrigger.ON_GAME_START),
		make("prophet", "算法先知", "重算", "每轮可重掷任意颗骰子", Rarity.LEGENDARY, SkillTrigger.ON_BEFORE_BID),
		make("dealer", "庄家", "开盘", "每轮由庄家先叫，庄家开局拥有8颗骰子", Rarity.LEGENDARY, SkillTrigger.ON_GAME_START),
	]

static func get_genesis_pool() -> Array[CardData]:
	return [
		make("dice_god", "骰子之神HOLO", "禁忌变更", "每轮随机更换1个禁忌点数", Rarity.GENESIS, SkillTrigger.PASSIVE),
	]

static func get_unknown_pool() -> Array[CardData]:
	return [
		make("unknown_mirror", "???·镜像", "广播", "每轮公布全场最多的1个点数", Rarity.UNKNOWN, SkillTrigger.ON_GAME_START),
		make("unknown_chaos", "???·混沌", "乱码", "叫牌显示随机篡改", Rarity.UNKNOWN, SkillTrigger.PASSIVE),
		make("unknown_abyss", "???·深渊", "吞噬", "整场对局结束时吞随机一个对手1颗骰子", Rarity.UNKNOWN, SkillTrigger.PASSIVE),
	]

static func get_pool_by_rarity(rarity: Rarity) -> Array[CardData]:
	match rarity:
		Rarity.COMMON: return get_common_pool()
		Rarity.RARE: return get_rare_pool()
		Rarity.EPIC: return get_epic_pool()
		Rarity.LEGENDARY: return get_legendary_pool()
		Rarity.GENESIS: return get_genesis_pool()
		Rarity.UNKNOWN: return get_unknown_pool()
	return []

static func get_card_by_id(card_id: String) -> CardData:
	for pool in [get_common_pool(), get_rare_pool(), get_epic_pool(), get_legendary_pool(), get_genesis_pool(), get_unknown_pool()]:
		for card in pool:
			if card.card_id == card_id:
				return card
	return null
