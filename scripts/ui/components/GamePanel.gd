## Reusable panel — ColorRect with optional border.
extends ColorRect

var _bordered: bool = false

static func create(parent: Control, pos: Vector2, size: Vector2, bg: Color = UITheme.BG_PANEL, border_color: Color = UITheme.BORDER_SUBTLE) -> ColorRect:
	var p := ColorRect.new()
	p.set_script(load("res://scripts/ui/components/GamePanel.gd"))
	p.position = pos
	p.size = size
	p.color = bg
	if border_color.a > 0:
		UITheme.add_border(p, int(size.x), int(size.y), border_color)
		p._bordered = true
	parent.add_child(p)
	return p
