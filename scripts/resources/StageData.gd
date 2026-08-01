## Defines a single stage in the game — name, mutation rule, boss, and node layout.
class_name StageData
extends Resource

enum MutationType { NONE, DARK_DIE, INFECTIOUS_DIE, FORBIDDEN_POINTS }

@export var stage_name: String = ""
@export var mutation: MutationType = MutationType.NONE
@export var boss_name: String = ""
@export var boss_screen: String = "CRT"
@export var boss_personality: int = 0  # AiPersonality.PersonalityType
@export var node_count: int = 5
@export var rest_zones: int = 2
@export var bg_color: Color = Color(0.025, 0.025, 0.03)
@export var mutation_description: String = ""

func describe_mutation() -> String:
    match mutation:
        MutationType.DARK_DIE:
            return "暗骰: 每人一颗看不到的骰子"
        MutationType.INFECTIOUS_DIE:
            return "传染骰: 叫到传染点数必须跟叫"
        MutationType.FORBIDDEN_POINTS:
            return "禁忌点数: 叫到者扣除1颗骰子"
    return "标准规则"
