class_name Hud
extends CanvasLayer
## 屏幕上的 UI：左上角水晶血量、底部常驻按键提示、正中的大字（水晶碎了等）。
## 情绪指针表做情绪值时再加。

const FONT_PATH := "res://fonts/PixelFont.ttf"
const WARM := Color8(255, 211, 138)
const DIM := Color(0.55, 0.55, 0.6)
const LANTERN := [
	"..#..",
	".###.",
	"#ooo#",
	"#oOo#",
	"#ooo#",
	"#####",
]

static var _font: FontFile

var _bar: Control
var _hint: Label
var _banner: Label
var _shown_hp := 100.0
## Boss 房里关掉底部按键提示（那里放 Boss 血条）
var show_hint := true
## 马灯血量低于这个比例，血条红着闪
const LOW_HP := 0.3
var _coach: Coach


static func font() -> FontFile:
	if _font == null:
		_font = load(FONT_PATH)
		_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_font.hinting = TextServer.HINTING_NONE
		_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return _font


static func small_text(color := Color(0.85, 0.85, 0.85)) -> LabelSettings:
	var s := LabelSettings.new()
	s.font = font()
	s.font_size = 11
	s.font_color = color
	s.outline_size = 2
	s.outline_color = Color(0.03, 0.03, 0.045)
	return s


func _ready() -> void:
	layer = 10
	_bar = Control.new()
	_bar.position = Vector2(8, 8)
	_bar.size = Vector2(90, 12)
	_bar.draw.connect(_draw_bar)
	add_child(_bar)

	_hint = Label.new()
	_hint.label_settings = small_text(DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(0, 255)
	_hint.size = Vector2(480, 12)
	add_child(_hint)

	_banner = Label.new()
	var big := small_text(WARM)
	big.font_size = 22
	big.outline_size = 4
	_banner.label_settings = big
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.position = Vector2(0, 110)
	_banner.size = Vector2(480, 30)
	_banner.visible = false
	add_child(_banner)

	_coach = Coach.new()
	add_child(_coach)
	# 情绪指针表、全屏老电视滤镜、马灯光圈和回血特效（scripts/ui/emotion_fx.gd）
	add_child(EmotionFx.new())

	_shown_hp = Run.crystal_hp
	Run.crystal_changed.connect(_on_crystal_changed)
	# 暂停菜单里换了语言，底下这行当场换
	Settings.changed.connect(_update_hint)
	_update_hint()


func _on_crystal_changed(_hp: float, _max: float) -> void:
	_bar.queue_redraw()


func _process(delta: float) -> void:
	# 掉血时白条慢慢追上实际血量，看得出这一下掉了多少
	if not is_equal_approx(_shown_hp, Run.crystal_hp):
		_shown_hp = move_toward(_shown_hp, Run.crystal_hp, delta * 40.0)
		_bar.queue_redraw()
	# 底层地面贴着屏幕底边，有人走到那儿就把按键提示淡掉，别挡住脚
	var low := false
	for p in get_tree().get_nodes_in_group("player"):
		if (p as Node2D).get_global_transform_with_canvas().origin.y > _hint.position.y - 6.0:
			low = true
			break
	var hide := low or not show_hint or _coach.busy()
	_hint.modulate.a = move_toward(_hint.modulate.a, 0.0 if hide else 1.0, delta * 5.0)
	# 马灯快灭了：血条一直红着闪
	if Run.crystal_hp / Run.crystal_max < LOW_HP:
		_bar.queue_redraw()


func show_banner(text: String) -> void:
	_banner.text = text
	_banner.visible = true
	_banner.modulate.a = 0.0
	var tw := create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_banner, "modulate:a", 1.0, 0.25)


func _update_hint() -> void:
	var s := Run.players[0]["input"] as String
	var atk := Controls.key_name(s, "attack")
	var attack_text := tr("Hold %s: charge, release: shoot") % atk
	match Upgrades.weapon:
		"rivet":
			attack_text = tr("Hold %s: fire") % atk
		"hammer":
			attack_text = tr("%s: steam blast") % atk
	_hint.text = tr("%s Move   %s Jump (hold in air: fly)   %s   %s Drop/pick lantern   R Restart") % [
		Controls.key_name(s, "move"), Controls.key_name(s, "jump"), attack_text, Controls.key_name(s, "crystal")]


func _draw_bar() -> void:
	var ratio := Run.crystal_hp / Run.crystal_max
	var shown := _shown_hp / Run.crystal_max
	for y in LANTERN.size():
		var row: String = LANTERN[y]
		for x in row.length():
			var c := row[x]
			if c == ".":
				continue
			var col := Color8(84, 68, 54)
			if c == "o":
				col = WARM.lerp(Color8(120, 90, 70), 1.0 - ratio)
			elif c == "O":
				col = Color8(255, 240, 200).lerp(WARM, 1.0 - ratio)
			_bar.draw_rect(Rect2(x, y + 2, 1, 1), col)
	var bar := Rect2(8, 4, 60, 4)
	_bar.draw_rect(bar.grow(1), Color(0.03, 0.03, 0.045))
	_bar.draw_rect(bar, Color(0.16, 0.14, 0.14))
	_bar.draw_rect(Rect2(bar.position, Vector2(bar.size.x * shown, bar.size.y)), Color(0.95, 0.9, 0.85))
	var fill := WARM
	if ratio < LOW_HP:
		var k := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 9.0)
		fill = WARM.lerp(Color(1.0, 0.25, 0.18), k)
		_bar.draw_rect(bar.grow(1), Color(1.0, 0.25, 0.18, 0.5 * k), false)
	_bar.draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), fill)
