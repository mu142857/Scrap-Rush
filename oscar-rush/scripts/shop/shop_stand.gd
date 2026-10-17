class_name ShopStand
extends Node2D
## 商店里的一件货：一个图标（可选等级小格），下面常驻一个小价签。主角走到它前面就"选中"，
## 名字、说明和价钱显示在屏幕下方的信息框里（ShopRoom 管），按互动键（和捡灯同一个键）就买。
## 买不买得起、买了以后怎么样由 ShopRoom 决定。
## 原点在图标正中。
##
## 为什么不把字飘在图标上面：商店镜头放大 2 倍，只看得到 240×135，洞洞板上那几件的字
## 会顶到屏幕最上沿，和左上角的马灯血条、零件数叠在一起，还会被切掉一截（作者试玩反馈）。

signal buy_pressed(stand: ShopStand, player: Player)

const ICONS := preload("res://art/shop/icons.png")
## 和 tools/draw_shop.py 的 ICONS 顺序一样
const ICON_NAMES: Array[String] = ["part", "charge", "fuel", "plating", "damping", "repair", "refresh",
		"hammer", "tongs", "horn", "rivet", "rage", "slave", "echo", "dynamo"]
const WARM := Color8(255, 211, 138)
const DIM := Color(0.62, 0.6, 0.6)
const POOR := Color8(220, 90, 70)

## 货的编号：charge / fuel / plating / damping / repair / refresh / weapon / mutation
var id := ""
## weapon / mutation 格子里现在摆的是哪一个
var item := ""
var icon := "part"
## 主角离图标水平多远算"站在前面"，垂直方向主角脚底要在图标下面 0~100 像素内（洞洞板上的挂得高）
var zone_half := 13.0
## 等级小格：-1 不画
var pips := -1
## 由 ShopRoom 填：{"title", "detail", "price", "can_buy", "dim"}
var info := {}
## 有主角站在它前面
var focused := false
## 价签、亮框画在图标下面多远（拉杆那种没有图标的，ShopRoom 会改）
var tag_y := 13.0
## 买不起时字抖一下的剩余时间（信息框也读它）
var shake := 0.0

var _sprite: Sprite2D
var _marks: Node2D
var _tag: Label
var _pop := 0.0
var _t := 0.0


func _ready() -> void:
	z_index = 4
	_sprite = Sprite2D.new()
	_sprite.texture = ICONS
	_sprite.hframes = ICON_NAMES.size()
	add_child(_sprite)

	# 价签和亮框不吃场景光照，暗处也看得清
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_marks = Node2D.new()
	_marks.material = unshaded
	_marks.z_index = 30
	_marks.z_as_relative = false
	_marks.draw.connect(_draw_marks)
	add_child(_marks)
	_tag = Label.new()
	_tag.use_parent_material = true
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.size = Vector2(40, 12)
	_marks.add_child(_tag)
	_t = randf() * TAU
	refresh_view()


## info 或图标变了以后调一次
func refresh_view() -> void:
	if _sprite == null:
		return
	_sprite.frame = maxi(ICON_NAMES.find(icon), 0)
	_sprite.modulate = Color(0.45, 0.42, 0.42) if info.get("dim", false) else Color.WHITE
	var text := tag_text()
	_tag.text = text
	_tag.label_settings = Hud.small_text(tag_color())
	# 价签左边留 5 像素画小齿轮（只有写着价钱的时候画）
	var gear := 5.0 if text.is_valid_int() else 0.0
	_tag.position = Vector2(-20.0 + gear * 0.5 + 1.0, tag_y + (4.0 if pips >= 0 else 0.0))
	_marks.queue_redraw()


## 价签上的字：价钱 / FREE / MAX / SOLD / SOON
func tag_text() -> String:
	var title: String = info.get("title", "")
	if title == "SOLD":
		return "SOLD"
	if title.ends_with("MAX"):
		return "MAX"
	if info.get("dim", false):
		return "SOON"
	var price: int = info.get("price", 0)
	if price > 0:
		return str(price)
	return "FREE" if info.get("can_buy", false) else ""


func tag_color() -> Color:
	if not info.has("price") or info.get("dim", false):
		return DIM
	return WARM if info.get("can_buy", false) else POOR


func can_buy() -> bool:
	return info.get("can_buy", false)


## 买不起：价签和信息框抖一下
func deny() -> void:
	shake = 0.3


## 买到了：图标弹一下
func pop() -> void:
	_pop = 1.0


func near(p: Player) -> bool:
	var d := p.global_position - global_position
	return absf(d.x) <= zone_half and d.y > -4.0 and d.y < 100.0


func _physics_process(delta: float) -> void:
	_t += delta
	shake = maxf(shake - delta, 0.0)
	_pop = maxf(_pop - delta * 4.0, 0.0)
	focused = false
	for n in get_tree().get_nodes_in_group("player"):
		var p := n as Player
		if p == null or not near(p):
			continue
		focused = true
		if Input.is_action_just_pressed(p.input_prefix + "_crystal"):
			buy_pressed.emit(self, p)
	_marks.position = Vector2(roundf(sin(shake * 60.0) * 2.0 * signf(shake)), 0)
	_sprite.position = Vector2(0, -roundf(sin(_pop * PI) * 3.0))
	_marks.queue_redraw()


func _draw_marks() -> void:
	# 等级小格，在图标下面
	if pips >= 0:
		for i in Upgrades.MAX_LEVEL:
			_marks.draw_rect(Rect2(-6 + i * 4, 10, 3, 2), WARM if i < pips else Color(0.22, 0.2, 0.2))
	# 价签前面的小齿轮
	if _tag.text.is_valid_int():
		var w := Hud.font().get_string_size(_tag.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var gx := roundf(_tag.position.x + 20.0 - w * 0.5) - 6.0
		var gy := _tag.position.y + 3.0
		var col := tag_color()
		_marks.draw_rect(Rect2(gx + 1, gy, 3, 5), col)
		_marks.draw_rect(Rect2(gx, gy + 1, 5, 3), col)
		_marks.draw_rect(Rect2(gx + 2, gy + 2, 1, 1), Color(0.1, 0.08, 0.08))
	# 四角亮框：买得起的一直一闪一闪，站到前面时变实；买不起的只在站到前面时出一个暗红框
	var a := 0.0
	var col := WARM
	if focused:
		a = 1.0
		col = WARM if can_buy() else POOR
	elif can_buy():
		a = 0.35 + 0.35 * (0.5 + 0.5 * sin(_t * 4.0))
	if a <= 0.0:
		return
	col.a = a
	var r := 10.0 if focused else 9.0
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var cx: float = sx * r
			var cy: float = sy * r - (1.0 if sy < 0.0 else 0.0)
			_marks.draw_rect(Rect2(minf(cx, cx - sx * 3.0), cy, 3, 1), col)
			_marks.draw_rect(Rect2(cx, minf(cy, cy - sy * 3.0), 1, 3), col)
