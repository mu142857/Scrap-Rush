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
## 横幅后面垫的深色底条：出生点的提示牌常常就在横幅那一带，不垫的话两行字挤成一团（美术巡检）
var _banner_bg: ColorRect
var _banner_tw: Tween
var _shown_hp := 100.0
## Boss 房里关掉底部按键提示（那里放 Boss 血条）
var show_hint := true
var _in_fight := false
## 这一局打完了几场遭遇战（Run.checkpoint_saved 计数）。打完两场以后，底部说明缩成"马灯 / 重来"两项，不再整局挂一长串
static var fights_cleared := 0
const SHORT_HINT_AFTER := 2
## 底部说明要连续这么久没有"该藏"的理由才淡回来
const CALM_TIME := 2.5
var _calm := 0.0
var _fight_poll := 0.0
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
	_hint.modulate.a = 0.0
	add_child(_hint)

	_banner_bg = ColorRect.new()
	_banner_bg.color = Color(0.02, 0.02, 0.03, 0.78)
	_banner_bg.position = Vector2(0, 108)
	_banner_bg.size = Vector2(480, 34)
	_banner_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_bg.visible = false
	add_child(_banner_bg)
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
	# 换输入设备（键盘 ↔ 手柄）时按键名跟着变
	Controls.device_changed.connect(func(_p: bool) -> void: _update_hint())
	Run.checkpoint_saved.connect(func() -> void:
		fights_cleared += 1
		_update_hint())


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
		# 留 30 像素余量：第二关地面贴着画面底边，落地、跳的时候镜头一晃，字就会从人身上横穿过去（夜间质检）
		if (p as Node2D).get_global_transform_with_canvas().origin.y > _hint.position.y - 30.0:
			low = true
			break
	_fight_poll -= delta
	if _fight_poll <= 0.0:
		_fight_poll = 0.25
		_in_fight = _enemies_near()
	var hide := low or not show_hint or _coach.busy() or _dialog_open() or _in_fight
	if get_tree().get_nodes_in_group("player").is_empty():
		hide = true
	# 藏的理由消失以后，还要安静 2.5 秒才淡回来：刚落地、刚进场景、刚打完都不会马上冒出来
	_calm = 0.0 if hide else _calm + delta
	_hint.modulate.a = move_toward(_hint.modulate.a, 1.0 if _calm > CALM_TIME else 0.0, delta * 5.0)
	# 马灯快灭了：血条一直红着闪
	if Run.crystal_hp / Run.crystal_max < LOW_HP:
		_bar.queue_redraw()


## 屏幕中间的大字。hold > 0：停 hold 秒以后淡掉、藏起来（关卡中途的提示用）；
## hold = 0：一直留着（马上要切场景、重来时用，和以前一样）
## 主角身边有活着的怪（在打架）：底部那行操作说明这时只是杂讯，还常压在地面线上（第二关新玩家报告）
func _enemies_near() -> bool:
	var ps := get_tree().get_nodes_in_group("player")
	if ps.is_empty():
		return false
	var p := (ps[0] as Node2D).global_position
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Node2D and not e.get("dead") and (e as Node2D).global_position.distance_to(p) < 160.0:
			return true
	return false


## 有对话框开着（对话框的框底下会露出这行提示）
func _dialog_open() -> bool:
	for d in get_tree().get_nodes_in_group("dialog_box"):
		if d.get("visible"):
			return true
	return false


func show_banner(text: String, hold := 0.0) -> void:
	_banner.text = text
	_banner.visible = true
	_banner.modulate.a = 0.0
	_banner_bg.visible = true
	_banner_bg.modulate.a = 0.0
	if _banner_tw:
		_banner_tw.kill()
	_banner_tw = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_banner_tw.tween_property(_banner, "modulate:a", 1.0, 0.25)
	_banner_tw.parallel().tween_property(_banner_bg, "modulate:a", 1.0, 0.25)
	if hold > 0.0:
		_banner_tw.tween_interval(hold)
		_banner_tw.tween_property(_banner, "modulate:a", 0.0, 0.5)
		_banner_tw.parallel().tween_property(_banner_bg, "modulate:a", 0.0, 0.5)
		_banner_tw.tween_callback(_banner.hide)
		_banner_tw.tween_callback(_banner_bg.hide)


func _update_hint() -> void:
	var s := Run.players[0]["input"] as String
	var atk := Controls.key_name(s, "attack")
	var attack_text := tr("Hold %s: charge, release: shoot") % atk
	match Upgrades.weapon:
		"rivet":
			attack_text = tr("Hold %s: fire") % atk
		"hammer":
			attack_text = tr("%s: steam blast") % atk
	# 键盘：R 重来；手柄没有 R，改成"Start 暂停"（重来在暂停菜单里）
	var last := tr("R Restart")
	if s == "solo" and Controls.using_pad or s.begins_with("pad"):
		last = tr("%s Pause") % Controls.label("pause")
	if fights_cleared >= SHORT_HINT_AFTER:
		_hint.text = tr("%s Drop/pick lantern   %s") % [Controls.key_name(s, "crystal"), last]
		return
	_hint.text = tr("%s Move   %s Jump (hold in air: fly)   %s   %s Drop/pick lantern   %s") % [
		Controls.key_name(s, "move"), Controls.key_name(s, "jump"), attack_text, Controls.key_name(s, "crystal"), last]


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
