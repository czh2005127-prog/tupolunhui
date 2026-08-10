extends Node

const CardArtRef := preload("res://scripts/resources/CardArtCatalog.gd")
const CardDataRef := preload("res://scripts/resources/CardData.gd")
const PlayerCardRef := preload("res://scripts/resources/PlayerCardData.gd")
const CardDrawRef := preload("res://scripts/ui/CardDrawUI.gd")

func _ready() -> void:
	for card in PlayerCardRef.get_all_cards():
		var texture := CardArtRef.get_player_texture(card.card_id)
		assert(texture != null, "缺少玩家卡面：%s" % card.card_id)
		assert(texture.get_size() == Vector2(107, 155))
	for card in CardDataRef.get_all_cards():
		var texture := CardArtRef.get_opponent_texture(card.card_id)
		assert(texture != null, "缺少对手卡面：%s" % card.card_id)
		assert(texture.get_size() == Vector2(107, 155))
	for card_id in ["card_king", "royal_scribe", "royal_executioner"]:
		var texture := CardArtRef.get_opponent_texture(card_id)
		assert(texture != null, "缺少隐藏对手卡面：%s" % card_id)
		assert(texture.get_size() == Vector2(107, 155))
	for back_id in ["common", "unknown", "king"]:
		var back := CardArtRef.get_back_texture(back_id)
		assert(back != null, "缺少卡背：%s" % back_id)
		assert(back.get_size() == Vector2(140, 220))
	var draw_ui := CardDrawRef.new() as CardDrawUI
	add_child(draw_ui)
	draw_ui.setup(CardDataRef.get_common_pool(), [], null, false, 2, 0, true)
	await get_tree().process_frame
	assert(draw_ui._card_rects.size() == 4)
	assert(draw_ui._card_rects[0].rect.find_children("*", "TextureRect", true, false).size() > 0)
	print("CARD_ART_SMOKE_OK")
	get_tree().quit(0)
