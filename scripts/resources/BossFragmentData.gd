class_name BossFragmentData
extends RefCounted

const MAX_FRAGMENTS: int = 2

const DEFINITIONS: Dictionary = {
	"recycler": {"boss_name": "强制回收", "fragment_name": "回收碎片", "fragment_desc": "质疑成功时从被质疑者处夺取1颗骰子"},
	"lucky_one": {"boss_name": "绝对幸运", "fragment_name": "幸运碎片", "fragment_desc": "每轮随机选至多2颗骰子，各有50%概率变为①"},
	"referee": {"boss_name": "终审豁免", "fragment_name": "裁判碎片", "fragment_desc": "每局第一次质疑失败不产生同化"},
	"mirror_tech": {"boss_name": "增殖镜像", "fragment_name": "镜面碎片", "fragment_desc": "每局第一轮复制自己随机1颗骰子"},
	"table_ghost": {"boss_name": "亡者席位", "fragment_name": "幽灵碎片", "fragment_desc": "抵挡下一次同化，触发后碎片消失"},
	"alliance_oled": {"boss_name": "公开审判", "fragment_name": "同盟碎片", "fragment_desc": "每轮公开一名对手的2颗普通骰子"},
	"casino_owner": {"boss_name": "黑幕抽水", "fragment_name": "赌场碎片", "fragment_desc": "每局第一轮增加1颗仅自己可见的骰子"},
	"prophet": {"boss_name": "收敛预言", "fragment_name": "先知碎片", "fragment_desc": "每轮保底重摇最低的非①骰"},
	"dealer": {"boss_name": "加注开盘", "fragment_name": "庄家碎片", "fragment_desc": "每局开局额外获得1颗骰子"},
}

static func has_definition(card_id: String) -> bool:
	return DEFINITIONS.has(card_id)

static func get_info(card_id: String) -> Dictionary:
	return (DEFINITIONS.get(card_id, {}) as Dictionary).duplicate()

static func get_fragment_name(card_id: String) -> String:
	return str(DEFINITIONS.get(card_id, {}).get("fragment_name", card_id))

static func get_fragment_desc(card_id: String) -> String:
	return str(DEFINITIONS.get(card_id, {}).get("fragment_desc", ""))

static func get_boss_skill_name(card_id: String) -> String:
	if card_id == "dice_god":
		return "双命禁忌"
	return str(DEFINITIONS.get(card_id, {}).get("boss_name", "Boss强化"))
