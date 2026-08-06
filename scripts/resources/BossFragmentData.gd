class_name BossFragmentData
extends RefCounted

const MAX_FRAGMENTS:=2
const DEFINITIONS:Dictionary={
	"recycler":{"name":"回收碎片","desc":"每轮第一次主动弃牌后抽1张。"},
	"lucky_one":{"name":"幸运碎片","desc":"基础投掷随机至多2骰，各有1/3概率成为可参与一个骰型的万能①。"},
	"referee":{"name":"裁判碎片","desc":"每场一次，使一个敌人当前倒计时+2。"},
	"mirror_tech":{"name":"镜面碎片","desc":"每轮第一次单目标骰子操作可复制到另一颗合法骰。"},
	"table_ghost":{"name":"幽灵碎片","desc":"抵挡下一次同化后消失。"},
	"alliance_oled":{"name":"同盟碎片","desc":"额外公开敌人的下下个意图。"},
	"casino_owner":{"name":"赌场碎片","desc":"基础投掷随机1颗未锁定骰投两次取高，计分前保持暗骰。"},
	"prophet":{"name":"先知碎片","desc":"每场一次免费重投全部未锁定骰，不推进倒计时。"},
	"dealer":{"name":"庄家碎片","desc":"每场开局额外增加1颗骰子。"},
}

static func has_definition(id:String)->bool:return DEFINITIONS.has(id)
static func get_fragment_name(id:String)->String:return str(DEFINITIONS.get(id,{"name":id}).name)
static func get_fragment_desc(id:String)->String:return str(DEFINITIONS.get(id,{"desc":""}).desc)
static func get_info(id:String)->Dictionary:
	if not DEFINITIONS.has(id):return {}
	return {"boss_name":"额外Boss技能","fragment_name":get_fragment_name(id),"fragment_desc":get_fragment_desc(id)}
