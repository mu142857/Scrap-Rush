class_name BossBar
extends CanvasLayer
## 屏幕底部的 Boss 名字和血条。挨打时白条慢慢追上实际血量；66%、33% 两处刻度是换阶段的地方。
## 10-18：和精英血条一样，名字和血条排成一行贴在画面最底下，血条 3 像素；子弹、怪、主角走到后面时变淡（BarFade）

const WARM := Color8(255, 211, 138)
const BAR_W := 260.0
const BAR_H := 3.0

## 任何有 hp / max_hp / phase 属性和 hp_changed / defeated 信号的 Boss
var boss: Node2D
var boss_name := "THE STOKER"

var _shown := 1.0
var _flash := 0.0
var _root: Control
var _name: Label
## 血条的位置（_ready 里按名字的宽度排）
var BAR := Rect2()
var _alpha := 1.0
## appear() 以后才显示；之前 modulate 由出场淡入管
var _appeared := false


func _ready() -> void:
	# 底部血条亮着的时候，hud 把同一行的操作说明藏起来（10-18 作者：不要有文字重叠）
	add_to_group("hp_bar")
	layer = 11
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.draw.connect(_draw_bar)
	add_child(_root)
	_name = Label.new()
	_name.label_settings = Hud.small_text(WARM)
	_name.text = boss_name
	_root.add_child(_name)
	var w := _name.get_minimum_size().x
	var at: Array = BarFade.row(w, BAR_W, BAR_H)
	_name.position = at[0]
	_name.size = Vector2(w, 12)
	BAR = at[1]
	_root.modulate.a = 0.0
	boss.connect("hp_changed", func(_hp: float, _max: float): _flash = 1.0)
	boss.connect("defeated", _on_defeated)


## 出场：从透明慢慢显出来（_process 里 BarFade.step 往 1 走）
func appear() -> void:
	_alpha = 0.0
	_appeared = true


func _on_defeated() -> void:
	_appeared = false
	var tw := _root.create_tween().set_ignore_time_scale(true)
	tw.tween_interval(0.6)
	tw.tween_property(_root, "modulate:a", 0.0, 0.8)


func _process(delta: float) -> void:
	var ratio := float(boss.get("hp")) / float(boss.get("max_hp"))
	_shown = move_toward(_shown, ratio, delta * 0.4)
	if _shown < ratio:
		_shown = ratio
	_flash = maxf(_flash - delta * 6.0, 0.0)
	if _appeared:
		_alpha = BarFade.step(_alpha, BarFade.crowded(self, BAR.merge(Rect2(_name.position, _name.size))), delta)
		_root.modulate.a = _alpha
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
