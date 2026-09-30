class_name TemperatureGauge
extends Control
## Horizontal thermometer: cold (blue) -> comfortable (green) -> hot (red).
## White marker = felt body temperature, thin tick = ambient air.

const MIN_T := -25.0
const MAX_T := 50.0

var felt := 18.0
var ambient := 18.0


func _init() -> void:
	custom_minimum_size = Vector2(220, 16)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_values(p_felt: float, p_ambient: float) -> void:
	felt = p_felt
	ambient = p_ambient
	queue_redraw()


func _x_for(t: float) -> float:
	return clampf((t - MIN_T) / (MAX_T - MIN_T), 0.0, 1.0) * size.x


func _draw() -> void:
	var h := size.y
	var segments := [
		[MIN_T, TemperatureComponent.FREEZING_THRESHOLD, Color(0.45, 0.55, 1.0)],
		[TemperatureComponent.FREEZING_THRESHOLD, TemperatureComponent.COLD_THRESHOLD, Color(0.45, 0.75, 1.0)],
		[TemperatureComponent.COLD_THRESHOLD, TemperatureComponent.COMFORT_MIN, Color(0.6, 0.9, 0.95)],
		[TemperatureComponent.COMFORT_MIN, TemperatureComponent.COMFORT_MAX, Color(0.5, 0.85, 0.4)],
		[TemperatureComponent.COMFORT_MAX, TemperatureComponent.HOT_THRESHOLD, Color(1.0, 0.8, 0.35)],
		[TemperatureComponent.HOT_THRESHOLD, TemperatureComponent.SCORCHING_THRESHOLD, Color(1.0, 0.5, 0.25)],
		[TemperatureComponent.SCORCHING_THRESHOLD, MAX_T, Color(0.95, 0.25, 0.2)],
	]
	draw_rect(Rect2(Vector2(-2, -2), size + Vector2(4, 4)), Color(0, 0, 0, 0.7))
	for seg in segments:
		var x0 := _x_for(seg[0])
		var x1 := _x_for(seg[1])
		draw_rect(Rect2(x0, 0, x1 - x0, h), seg[2])
	var ax := _x_for(ambient)
	draw_line(Vector2(ax, -3), Vector2(ax, h + 3), Color(0.1, 0.1, 0.1), 2.0)
	var fx := _x_for(felt)
	draw_rect(Rect2(fx - 3, -4, 6, h + 8), Color.WHITE)
	draw_rect(Rect2(fx - 3, -4, 6, h + 8), Color(0, 0, 0), false, 1.5)
