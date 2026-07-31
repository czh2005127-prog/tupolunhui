## Item data resource + full item registry.
class_name ItemData
extends Resource

enum Rarity { COMMON, RARE, LEGENDARY }
enum ItemType { CONSUMABLE }

@export var item_id: String = ""
@export var item_name: String = ""
@export var description: String = ""
@export var rarity: Rarity = Rarity.COMMON
@export var item_type: ItemType = ItemType.CONSUMABLE
@export var price: int = 10

func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON: return Color(0.7, 0.7, 0.66)
		Rarity.RARE: return Color(0.52, 0.72, 0.92)
		Rarity.LEGENDARY: return Color(0.98, 0.78, 0.29)
	return Color.WHITE

func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON: return "普通"
		Rarity.RARE: return "稀有"
		Rarity.LEGENDARY: return "传说"
	return ""

static func make(id: String, name: String, desc: String, r: int, t: int, p: int) -> ItemData:
	var item := ItemData.new()
	item.item_id = id
	item.item_name = name
	item.description = desc
	item.rarity = r as Rarity
	item.item_type = t as ItemType
	item.price = p
	return item

## All consumable items
static func get_consumable_pool() -> Array:
	return [
		# --- 骰子 (7) ---
		make("reroll_stone", "重摇石", "重摇自己任意数量骰子", Rarity.COMMON, ItemType.CONSUMABLE, 10),
		make("freeze_die", "定格骰", "指定一颗骰子，下一轮固定为选定点数", Rarity.RARE, ItemType.CONSUMABLE, 30),
		make("split_die", "裂变骰", "一颗骰子劈成两颗，本局6颗骰子", Rarity.RARE, ItemType.CONSUMABLE, 35),
		make("full_reroll", "全重摇", "五颗骰子全部重摇", Rarity.COMMON, ItemType.CONSUMABLE, 12),
		make("clone_die", "克隆骰", "有对子时，复制一颗变三颗同点数", Rarity.RARE, ItemType.CONSUMABLE, 28),
		make("flip_die", "翻转骰", "翻转一颗骰子(1↔6,2↔5,3↔4)", Rarity.COMMON, ItemType.CONSUMABLE, 10),
		# --- 感知 (2) ---
		make("see_dark", "透屏", "自选一个对手，看其一颗骰子", Rarity.COMMON, ItemType.CONSUMABLE, 10),
		make("heat_vision", "热感视觉", "自选一个对手，看骰子大小分布", Rarity.RARE, ItemType.CONSUMABLE, 25),
		# --- 抗压 (1) ---
		make("emergency_restart", "大/小判", "自选一个对手，看穿骰子大小", Rarity.COMMON, ItemType.CONSUMABLE, 12),
		# --- 特殊 (8) ---
		make("silent_turn", "静默回合", "跳过自己本轮叫牌，叫牌链跳过你继续", Rarity.COMMON, ItemType.CONSUMABLE, 8),
		make("fate_die", "命运骰", "50%概率所有骰子全部变为①", Rarity.LEGENDARY, ItemType.CONSUMABLE, 60),
		make("extra_die", "加骰", "下一局永久增加2颗骰子", Rarity.RARE, ItemType.CONSUMABLE, 30),
		make("purge_chip", "净化芯片", "清除半同化状态", Rarity.COMMON, ItemType.CONSUMABLE, 15),
		make("gambler_hunch", "赌徒直觉", "提示区显示全桌最多的点数", Rarity.COMMON, ItemType.CONSUMABLE, 10),
make("payout", "清算", "直接获得50金币", Rarity.COMMON, ItemType.CONSUMABLE, 8),
	make("rig_dice", "虚张声势", "自己两颗骰子变为①", Rarity.LEGENDARY, ItemType.CONSUMABLE, 55),
	make("sabotage", "算力超频", "所有人增加一颗随机骰子", Rarity.LEGENDARY, ItemType.CONSUMABLE, 50),
	]

## Get random shop items (no duplicates, respects unlock)
static func get_random_shop_items(count: int) -> Array:
	var pool: Array = get_unlocked_pool()
	pool.shuffle()
	var result: Array = []
	for i in range(min(count, pool.size())):
		result.append(pool[i])
	return result

## Get consumable pool filtered by player's unlocked items
static func get_unlocked_pool() -> Array:
	var all: Array = get_consumable_pool()
	var unlocked: Array[String] = GameState.unlocked_items
	if unlocked.is_empty():
		return all
	var result: Array = []
	for item in all:
		if item.item_id in unlocked:
			result.append(item)
	return result

## Get item by id from consumable pool
static func get_by_id(item_id: String) -> Resource:
	for item in get_consumable_pool():
		if item.item_id == item_id:
			return item
	return null
