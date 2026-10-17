class_name HintSign
extends Node2D
## 关卡里的路线提示牌：一行字加一个会上下（或左右）晃的像素箭头。
## 有玩家走进 zone 就淡入，走出去就淡出。不吃场景压暗，黑处也看得清。
## 原点是箭头尖的位置，字在箭头上面。字不会伸出关卡左右两边。

const FADE_SPEED := 4.0
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

var _alpha := 0.0
var _time := 0.0
var _label: Label
var _text_half := 0.0


func _ready() -> void:
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
	_text_half = Hud.font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x * 0.5 + 10.0
	_label.position.x = clampf(-80.0, _text_half - position.x - 80.0, 1006.0 - _text_half - position.x - 80.0)
	modulate.a = 0.0


func _process(delta: float) -> void:
	_time += delta
	var inside := false
	for p in get_tree().get_nodes_in_group("player"):
		if zone.has_point((p as Node2D).global_position):
			inside = true
			break
	_alpha = move_toward(_alpha, 1.0 if inside else 0.0, delta * FADE_SPEED)
	modulate.a = _alpha
	visible = _alpha > 0.0
	queue_redraw()


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
