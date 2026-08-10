extends Node

const ShopRef := preload("res://scripts/ui/ShopUI.gd")
const WorkshopRef := preload("res://scripts/ui/RustWorkshop.gd")

func _ready() -> void:
	GameState.setup_new_run()
	var shop := ShopRef.new()
	add_child(shop)
	await get_tree().process_frame
	shop._page = "singles"
	shop._draw_stock()
	await get_tree().process_frame
	assert(shop._content.find_children("*", "TextureRect", true, false).size() == 6)
	shop.queue_free()
	await get_tree().process_frame
	GameState.hidden_king_discovered = true
	var workshop := WorkshopRef.new()
	add_child(workshop)
	await get_tree().process_frame
	assert(workshop.find_children("*", "TextureRect", true, false).size() >= 18)
	print("CARD_SCREENS_SMOKE_OK")
	get_tree().quit(0)
