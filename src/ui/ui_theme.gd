class_name UITheme
## Builds the shared fantasy/cartoon UI theme in code (no theme asset needed yet).

const PANEL_BG := Color(0.12, 0.1, 0.16, 0.86)
const PANEL_BORDER := Color(0.85, 0.68, 0.36)
const TEXT := Color(0.97, 0.94, 0.86)
const TEXT_DIM := Color(0.75, 0.72, 0.66)
const HEALTH := Color(0.88, 0.24, 0.28)
const STAMINA := Color(0.55, 0.85, 0.3)
const HUNGER := Color(0.95, 0.62, 0.22)
const GOLD := Color(1.0, 0.8, 0.35)


static func panel_style(bg: Color = PANEL_BG, border: Color = PANEL_BORDER, border_width: int = 2, radius: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 4
	return s


## One theme shared by every screen, so the high-contrast setting can update
## all open UI at once (Milestone 13).
static var _shared: Theme
static var high_contrast := false


static func build() -> Theme:
	if _shared == null:
		_shared = Theme.new()
		_populate(_shared)
	return _shared


## Accessibility: opaque panels, white text with thick outlines, bright borders.
static func set_high_contrast(on: bool) -> void:
	if on == high_contrast and _shared != null:
		return
	high_contrast = on
	if _shared:
		_shared.clear()
		_populate(_shared)


static func _populate(t: Theme) -> void:
	var hc := high_contrast
	t.default_font_size = 16
	t.set_color(&"font_color", &"Label", Color.WHITE if hc else TEXT)
	t.set_color(&"font_outline_color", &"Label", Color(0, 0, 0, 1.0 if hc else 0.85))
	t.set_constant(&"outline_size", &"Label", 7 if hc else 4)
	var panel := panel_style(Color(0.02, 0.02, 0.03, 0.97), Color(1, 0.9, 0.3), 3) if hc else panel_style()
	t.set_stylebox(&"panel", &"PanelContainer", panel)
	t.set_stylebox(&"panel", &"Panel", panel)

	var btn := panel_style(Color(0.05, 0.05, 0.08, 1.0) if hc else Color(0.24, 0.19, 0.28, 0.95), Color.WHITE if hc else PANEL_BORDER, 3 if hc else 2, 6)
	btn.content_margin_left = 14
	btn.content_margin_right = 14
	btn.content_margin_top = 6
	btn.content_margin_bottom = 6
	var btn_hover := btn.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.34, 0.27, 0.38, 0.95)
	btn_hover.border_color = GOLD
	var btn_pressed := btn.duplicate() as StyleBoxFlat
	btn_pressed.bg_color = Color(0.45, 0.32, 0.16, 0.95)  # also the "selected" look of toggle buttons
	btn_pressed.border_color = GOLD
	btn_pressed.set_border_width_all(3)
	var btn_disabled := btn.duplicate() as StyleBoxFlat
	btn_disabled.bg_color = Color(0.2, 0.2, 0.2, 0.7)
	btn_disabled.border_color = Color(0.4, 0.4, 0.4)
	t.set_stylebox(&"normal", &"Button", btn)
	t.set_stylebox(&"hover", &"Button", btn_hover)
	t.set_stylebox(&"pressed", &"Button", btn_pressed)
	t.set_stylebox(&"hover_pressed", &"Button", btn_pressed)
	t.set_stylebox(&"disabled", &"Button", btn_disabled)
	t.set_stylebox(&"focus", &"Button", StyleBoxEmpty.new())
	t.set_color(&"font_color", &"Button", TEXT)
	t.set_color(&"font_hover_color", &"Button", GOLD)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.05, 0.04, 0.07, 0.9)
	bar_bg.set_corner_radius_all(5)
	bar_bg.border_color = Color(0, 0, 0, 0.6)
	bar_bg.set_border_width_all(1)
	t.set_stylebox(&"background", &"ProgressBar", bar_bg)
	t.set_color(&"font_color", &"TooltipLabel", TEXT)
	t.set_stylebox(&"panel", &"TooltipPanel", panel_style(Color(0.1, 0.08, 0.13, 0.96)))
	if hc:
		t.set_color(&"font_color", &"Button", Color.WHITE)
		t.set_color(&"font_hover_color", &"Button", Color(1, 0.95, 0.3))
		t.set_color(&"font_outline_color", &"Button", Color.BLACK)
		t.set_constant(&"outline_size", &"Button", 4)


static func bar_fill(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(5)
	s.border_color = color.lightened(0.35)
	s.border_width_top = 2
	return s
