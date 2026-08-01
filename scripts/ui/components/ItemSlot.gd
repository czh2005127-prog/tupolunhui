## Reusable item slot row — name + rarity color + use button + hover tooltip.
## Emits item_hovered(item_id, description) and item_used(item_id).
class_name ItemSlot
extends Control

const GameButtonScript := preload("res://scripts/ui/components/GameButton.gd")

signal item_hovered(item_id: String, desc: String)
signal item_used(item_id: String)
signal item_unhovered

var item_id: String = ""
var item_name: String = ""
var item_desc: String = ""
var rarity_color: Color = UITheme.RARITY_COMMON

var _name_label: Label
var _use_btn: ColorRect
var _bg: ColorRect

static func create(parent: Control, pos: Vector2, size: Vector2) -> ItemSlot:
	var slot := ItemSlot.new()
	slot.position = pos
	slot.size = size
	slot.mouse_filter = Control.MOUSE_FILTER_PASS

	slot._bg = ColorRect.new()
	slot._bg.position = Vector2.ZERO
	slot._bg.size = size
	slot._bg.color = UITheme.BG_SLOT
	UITheme.add_border(slot._bg, int(size.x), int(size.y), UITheme.BORDER_SUBTLE)
	slot.add_child(slot._bg)

	slot._name_label = UITheme.label(slot, "空", Vector2(UITheme.SPACING_MD, 6), Vector2(size.x - 56, 20), UITheme.TEXT_DIM, UITheme.FONT_CAPTION)

	# "用" button (positioned at right edge)
	slot._use_btn = GameButtonScript.create(slot, Vector2(size.x - 44, 4), Vector2(36, 24), "用", UITheme.BLUE, func(): slot.item_used.emit(slot.item_id))
	slot._use_btn.visible = false

	# Hover detection
	slot.mouse_entered.connect(func():
		if slot.item_id != "":
			slot.item_hovered.emit(slot.item_id, slot.item_desc)
	)
	slot.mouse_exited.connect(func():
		slot.item_unhovered.emit()
	)

	parent.add_child(slot)
	return slot

## Set item data (or clear if item_id is empty).
func set_item(id: String, name: String, desc: String, rcol: Color) -> void:
	item_id = id
	item_name = name
	item_desc = desc
	rarity_color = rcol
	if id == "":
		_name_label.text = "空"
		_name_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		_use_btn.visible = false
	else:
		_name_label.text = name
		_name_label.add_theme_color_override("font_color", rcol)
		_use_btn.visible = true
