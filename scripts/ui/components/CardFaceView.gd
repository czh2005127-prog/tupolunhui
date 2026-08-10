class_name CardFaceView
extends Control

const CardArtRef := preload("res://scripts/resources/CardArtCatalog.gd")
const CARD_SIZE := Vector2(107, 155)

func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = CARD_SIZE
	if size == Vector2.ZERO:
		size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func setup_player(card: Resource, show_description: bool = true) -> void:
	_clear()
	_size_self()
	_add_texture(CardArtRef.get_player_texture(str(card.card_id)))
	_add_text(str(card.card_name), Rect2(5, 3, 97, 16), 9, Color("eadfca"), HORIZONTAL_ALIGNMENT_CENTER)
	if show_description:
		_add_text(str(card.description), Rect2(7, 108, 93, 42), 7, Color("30271f"), HORIZONTAL_ALIGNMENT_CENTER, true)

func setup_opponent(card: Resource, detail_text: String = "", show_name: bool = true, detail_font_size: int = 7) -> void:
	_clear()
	_size_self()
	_add_texture(CardArtRef.get_opponent_texture(str(card.card_id)))
	if show_name:
		_add_text(str(card.card_name), Rect2(4, 3, 99, 16), 9, Color("eadfca"), HORIZONTAL_ALIGNMENT_CENTER)
	var shown := detail_text
	if shown.is_empty() and card.get("skill_name") != null:
		shown = str(card.skill_name)
	if not shown.is_empty():
		_add_text(shown, Rect2(6, 108, 95, 42), detail_font_size, Color("30271f"), HORIZONTAL_ALIGNMENT_CENTER, true)

func setup_back(card_id: String) -> void:
	_clear()
	size = Vector2(140, 220)
	custom_minimum_size = size
	var texture_rect := TextureRect.new()
	texture_rect.texture = CardArtRef.get_opponent_back(card_id)
	texture_rect.position = Vector2.ZERO
	texture_rect.size = size
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(texture_rect)

func add_state_overlay(color: Color) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.position = Vector2.ZERO
	overlay.size = size
	overlay.color = color
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	return overlay

func _size_self() -> void:
	size = CARD_SIZE
	custom_minimum_size = CARD_SIZE

func _add_texture(texture: Texture2D) -> void:
	var texture_rect := TextureRect.new()
	texture_rect.texture = texture
	texture_rect.position = Vector2.ZERO
	texture_rect.size = CARD_SIZE
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(texture_rect)

func _add_text(text_value: String, rect: Rect2, font_size: int, color: Color, alignment: HorizontalAlignment, wrap: bool = false) -> void:
	var label := Label.new()
	label.text = text_value
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.28))
	label.add_theme_constant_override("outline_size", 1)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

func _clear() -> void:
	for child in get_children():
		child.queue_free()
