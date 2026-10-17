class_name BossBar
extends CanvasLayer
## 屏幕底部的 Boss 名字和血条。挨打时白条慢慢追上实际血量；66%、33% 两处刻度是换阶段的地方。

const WARM := Color8(255, 211, 138)
const BAR := Rect2(110, 256, 260, 4)

## 任何有 hp / max_hp / phase 属性和 hp_changed / defeated 信号的 Boss
var boss: Node2D
var boss_name := "THE STOKER"

var _shown := 1.0
var _flash := 0.0
var _root: Control
var _name: Label


func _ready() -> void:
	layer = 11
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.draw.connect(_draw_bar)
	add_child(_root)
	_name = Label.new()
	_name.label_settings = Hud.small_text(WARM)
	_name.text = boss_name
	_name.position = Vector2(BAR.position.x, BAR.position.y - 14)
	_name.size = Vector2(200, 12)
	_root.add_child(_name)
	_root.modulate.a = 0.0
	boss.connect("hp_changed", func(_hp: float, _max: float): _flash = 1.0)
	boss.connect("defeated", _on_defeated)


func appear() -> void:
	_root.create_tween().tween_property(_root, "modulate:a", 1.0, 0.5)


func _on_defeated() -> void:
	var tw := _root.create_tween().set_ignore_time_scale(true)
	tw.tween_interval(0.6)
	tw.tween_property(_root, "modulate:a", 0.0, 0.8)


func _process(delta: float) -> void:
	var ratio := float(boss.get("hp")) / float(boss.get("max_hp"))
	_shown = move_toward(_shown, ratio, delta * 0.4)
	if _shown < ratio:
		_shown = ratio
	_flash = maxf(_flash - delta * 6.0, 0.0)
	_root.queue_redraw()


func _draw_bar() -> void:
	var ratio := float(boss.get("hp")) / float(boss.get("max_hp"))
	_root.draw_rect(BAR.grow(1), Color(0.03, 0.03, 0.045))
	_root.draw_rect(BAR, Color(0.16, 0.12, 0.11))
	_root.draw_rect(Rect2(BAR.position, Vector2(BAR.size.x * _shown, BAR.size.y)), Color(0.95, 0.9, 0.85))
	var fill := Color(0.9, 0.35, 0.18).lerp(Color.WHITE, _flash * 0.5)
	if int(boss.get("phase")) == 3:
		fill = fill.lerp(Color(1.0, 0.15, 0.1), 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0))
	_root.draw_rect(Rect2(BAR.position, Vector2(BAR.size.x * ratio, BAR.size.y)), fill)
	for k in [0.66, 0.33]:
		var x := roundf(BAR.position.x + BAR.size.x * k)
		_root.draw_rect(Rect2(x, BAR.position.y - 1, 1, BAR.size.y + 2), Color(0.03, 0.03, 0.045))
