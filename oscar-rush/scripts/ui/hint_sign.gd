class_name HintSign
extends Node2D
## 关卡里的路线提示牌：一行字加一个会上下（或左右）晃的像素箭头。
## 有玩家走进 zone 就淡入，走出去就淡出。不吃场景压暗，黑处也看得清。
## 原点是箭头尖的位置，字在箭头上面。字不会伸出关卡左右两边。
## 屏幕分区（2026-10-17 夜间，游戏细节讨论会话）：
## - 有精英在画面里（出场名字卡、打的时候）就淡出，让给名字卡和战斗；打完再淡回来；
## - 字快出画面时往里推（离边 SCREEN_MARGIN 像素），箭头还指着原来的地方。

const FADE_SPEED := 4.0
const SCREEN_MARGIN := 6.0
## 屏幕最上面这一条是 HUD 的（左上马灯血条、右上压力表），字不往这里放
const TOP_MARGIN := 22.0
const ARROW_COLOR := Color8(255, 211, 138)
## 箭头朝下的像素图，其他方向旋转着画
const ARROW := [
	"..###..",
	"..###..",
	"..###..",
	"#######",
	".#####.",
	"..###..",
	"...#...",
]

var zone := Rect2()
var text := ""
## "up" / "down" / "left" / "right"
var arrow := "down"
## 关卡宽度：字不会伸出关卡左右两边。默认是第一关的 1006；更宽的关卡要设成自己的宽度，
## 不然 x 超过 1000 左右的提示牌，字会被推到画面外（2026-10-17 夜，第三关发现）
var level_width := 1006.0

var _alpha := 0.0
var _time := 0.0
var _label: Label
var _text_half := 0.0
var _base_label_pos := Vector2.ZERO


func _ready() -> void:
	# Coach（新手提示框）放到屏幕上方时会避开提示牌
	add_to_group("hint_sign")
	z_index = 30
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
	_label = Label.new()
	_label.use_parent_material = true
	_label.label_settings = Hud.small_text(ARROW_COLOR)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.text = text
	_label.size = Vector2(160, 12)
	_label.position = Vector2(-80, -24)
	add_child(_label)
	_text_half = Hud.font().get_string_size(tr(text), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x * 0.5 + 10.0
	_label.position.x = clampf(-80.0, _text_half - position.x - 80.0, level_width - _text_half - position.x - 80.0)
	_base_label_pos = _label.position
	modulate.a = 0.0


func _process(delta: float) -> void:
	_time += delta
	var inside := false
	for p in get_tree().get_nodes_in_group("player"):
		if zone.has_point((p as Node2D).global_position):
			inside = true
			break
	# 关卡开场的名字卡、精英名字卡在屏幕上时也先藏着（name_card 组），放完再淡出来
	var want := inside and not _elite_on_screen() and get_tree().get_nodes_in_group("name_card").is_empty()
	_alpha = move_toward(_alpha, 1.0 if want else 0.0, delta * FADE_SPEED)
	modulate.a = _alpha
	visible = _alpha > 0.0
	if visible:
		_keep_label_on_screen()
	queue_redraw()


## 画面里有没有还活着的精英（出场中或者在打）
func _elite_on_screen() -> bool:
	var view := get_viewport_rect().grow(-4.0)
	for n in get_tree().get_nodes_in_group("enemy"):
		if n is EliteBase and not n.get("dead"):
			if view.has_point((n as Node2D).get_global_transform_with_canvas().origin):
				return true
	return false


## 字的屏幕位置快出边时，把字往里推；推完换算回自己的坐标
func _keep_label_on_screen() -> void:
	_label.position = _base_label_pos
	var xf := get_global_transform_with_canvas()
	var s := xf.get_scale()
	if s.x <= 0.0 or s.y <= 0.0:
		return
	var view := get_viewport_rect().size
	var half := _text_half - 10.0
	var center := xf * (_base_label_pos + Vector2(80.0, 6.0))
	var dx := 0.0
	if center.x - half * s.x < SCREEN_MARGIN:
		dx = SCREEN_MARGIN - (center.x - half * s.x)
	elif center.x + half * s.x > view.x - SCREEN_MARGIN:
		dx = (view.x - SCREEN_MARGIN) - (center.x + half * s.x)
	var top := (xf * _base_label_pos).y
	var dy := maxf(0.0, TOP_MARGIN - top)
	_label.position = _base_label_pos + Vector2(dx / s.x, dy / s.y).round()


func _draw() -> void:
	var dir := {"down": Vector2.DOWN, "up": Vector2.UP, "left": Vector2.LEFT, "right": Vector2.RIGHT}[arrow] as Vector2
	var bob := dir * roundf(1.5 + 1.5 * sin(_time * 6.0)) - Vector2(0, 4)
	var pixels: Array[Vector2] = []
	for y in ARROW.size():
		var row: String = ARROW[y]
		for x in row.length():
			if row[x] != "#":
				continue
			# 原图朝下、尖在 (3, 6)；转到 dir 的方向
			var v := Vector2(x - 3, y - 6)
			match arrow:
				"up": v = Vector2(v.x, -v.y)
				"left": v = Vector2(-v.y, v.x)
				"right": v = Vector2(v.y, v.x)
			pixels.append((v + bob).round())
	# 先画完一整层影子再画箭头，不然后画的影子会盖住前面的像素
	for v in pixels:
		draw_rect(Rect2(v + Vector2(0, 1), Vector2.ONE), Color(0.03, 0.03, 0.045))
	for v in pixels:
		draw_rect(Rect2(v, Vector2.ONE), ARROW_COLOR)
