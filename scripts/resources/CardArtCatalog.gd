class_name CardArtCatalog
extends RefCounted

const PLAYER_ROOT := "res://assets/cards/player/"
const OPPONENT_ROOT := "res://assets/cards/opponents/"
const BACK_ROOT := "res://assets/cards/backs/"

static func get_player_texture(card_id: String) -> Texture2D:
	return _load_texture(PLAYER_ROOT + card_id + ".png")

static func get_opponent_texture(card_id: String) -> Texture2D:
	return _load_texture(OPPONENT_ROOT + card_id + ".png")

static func get_opponent_back(card_id: String) -> Texture2D:
	var back_id := "common"
	if card_id.begins_with("unknown_"):
		back_id = "unknown"
	elif card_id in ["card_king", "royal_scribe", "royal_executioner"]:
		back_id = "king"
	return _load_texture(BACK_ROOT + back_id + ".png")

static func get_back_texture(back_id: String) -> Texture2D:
	return _load_texture(BACK_ROOT + back_id + ".png")

static func has_player_texture(card_id: String) -> bool:
	return ResourceLoader.exists(PLAYER_ROOT + card_id + ".png")

static func has_opponent_texture(card_id: String) -> bool:
	return ResourceLoader.exists(OPPONENT_ROOT + card_id + ".png")

static func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
