class_name ShopStand
extends Node2D
## 商店里的一件货：一张小卡片（和开局选武器界面同一套画法，见 UiStyle）里放图标和等级格，下面挂一个价签。
## 主角走到它前面就"选中"：卡片边变暖黄、四角角标一张一缩、图标放大浮动，没选中的买不起的调暗。
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
		"hammer", "tongs", "horn", "rivet", "rage", "slave", "echo", "dynamo", "shotgun", "laser", "record",
		"fuse", "valve", "burnin", "rewind"]
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
var _back: Node2D
var _marks: Node2D
var _tag: Label
var _pop := 0.0
var _t := 0.0
var _focus_s := 0.0

const CARD := Rect2(-11, -11, 22, 22)


func _ready() -> void:
	z_index = 4
	# 卡片底、价签、角标都不吃场景光照，暗处也看得清；卡片底在图标后面，价签和角标在最上面
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_back = Node2D.new()
	_back.material = unshaded
	_back.z_index = -1
	_back.draw.connect(_draw_back)
	add_child(_back)
	_sprite = Sprite2D.new()
	_sprite.texture = ICONS
	_sprite.hframes = ICON_NAMES.size()
	_sprite.material = unshaded
	add_child(_sprite)
	_marks = Node2D.new()
	_marks.material = unshaded
	_marks.z_index = 30
	_marks.z_as_relative = false
	_marks.draw.connect(_draw_marks)
	add_child(_marks)
	_tag = Label.new()
	_tag.use_parent_material = true
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.size = Vector2(80, 12)
	_marks.add_child(_tag)
	_t = randf() * TAU
	refresh_view()


## info 或图标变了以后调一次
func refresh_view() -> void:
	if _sprite == null:
		return
	_sprite.frame = maxi(ICON_NAMES.find(icon), 0)
	var text := tag_text()
	_tag.text = text
	_tag.label_settings = Hud.small_text(tag_color())
	# 价签左边留 6 像素画小齿轮（只有写着价钱的时候画）
	var gear := 6.0 if text.is_valid_int() else 0.0
	_tag.position = Vector2(-40.0 + gear * 0.5, tag_y)
	_back.queue_redraw()
	_marks.queue_redraw()


## 价签上的字：价钱 / FREE / MAX / SOLD / SOON
func tag_text() -> String:
	var title: String = info.get("title", "")
	if title == "SOLD":
		return "SOLD"
	if info.get("maxed", false) or title.ends_with("MAX"):
		return "MAX"
	if info.get("dim", false):
		return "SOON"
	var price: int = info.get("price", 0)
	if price > 0:
		return str(price)
	# 只有拉杆（刷新）会免费：写清楚免费的是什么，远看只有"免费"两个字新玩家看不懂（新玩家体验报告）
	if info.get("can_buy", false):
		return "FREE REROLL" if id == "refresh" else "FREE"
	return ""


func tag_color() -> Color:
	if not info.has("price") or info.get("dim", false):
		return UiStyle.DIM
	return UiStyle.WARM if info.get("can_buy", false) else UiStyle.POOR


func can_buy() -> bool:
	return info.get("can_buy", false)


## 选中时卡片边的颜色：买得起暖黄；有价钱但零件不够红；不用买（马灯满了、买满、卖完、还没做）灰
func edge_color() -> Color:
	if can_buy():
		return UiStyle.WARM
	if int(info.get("price", 0)) > 0 and not info.get("dim", false) and tag_text() not in ["MAX", "SOLD"]:
		return UiStyle.POOR
	return UiStyle.DIM


## 买不起：卡片和信息卡抖一下
func deny() -> void:
	shake = 0.3


## 买到了：图标弹一下
func pop() -> void:
	_pop = 1.0


func near(p: Player) -> bool:
	var d := p.global_position - global_position
	return absf(d.x) <= zone_half and d.y > -4.0 and d.y < 100.0


## 按下买以后这么久里不再认别的买：双人同时（或前后几帧）按下只算一次，不会连买两级（夜间质检报的）
const BUY_GAP := 0.15
var _buy_cd := 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	_buy_cd = maxf(_buy_cd - delta, 0.0)
	shake = maxf(shake - delta, 0.0)
	_pop = maxf(_pop - delta * 4.0, 0.0)
	focused = false
	for n in get_tree().get_nodes_in_group("player"):
		var p := n as Player
		if p == null or not near(p):
			continue
		focused = true
		if Input.is_action_just_pressed(p.input_prefix + "_crystal") and _buy_cd <= 0.0:
			_buy_cd = BUY_GAP
			buy_pressed.emit(self, p)
	_focus_s = move_toward(_focus_s, 1.0 if focused else 0.0, delta * 8.0)
	var sh := Vector2(roundf(sin(shake * 60.0) * 2.0 * signf(shake)), 0)
	_marks.position = sh
	_back.position = sh
	# 选中：图标放大一点、上下浮；买到：往上弹一下；买不起或还没做的：调暗（和选武器界面没选中的卡一样）
	# 选中：图标抬起 1 像素再上下浮；买到：往上弹 3 像素（只挪整数像素，不缩放）
	var bob := (-1.0 + roundf(sin(_t * 3.0))) if focused else 0.0
	_sprite.position = sh + Vector2(0, bob - roundf(sin(_pop * PI) * 3.0))
	var usable := can_buy() or focused
	_sprite.modulate = Color.WHITE if usable else UiStyle.DIM_MOD
	if info.get("dim", false):
		_sprite.modulate = Color(0.45, 0.42, 0.42)
	_back.queue_redraw()
	_marks.queue_redraw()


## 卡片底：和选武器界面的卡片一样（近黑底 + 细边；选中暖黄边，买不起的选中是红边）。
## 买得起、没选中的：边一明一暗地泛暖黄，告诉你"这个能买"。拉杆那种没图标的不画卡片
func _draw_back() -> void:
	if not _sprite.visible:
		return
	var on := focused
	UiStyle.panel(_back, CARD, false, _t, UiStyle.WARM, Color(UiStyle.PANEL, 0.82))
	if not on and can_buy():
		var a := 0.25 + 0.3 * (0.5 + 0.5 * sin(_t * 4.0))
		var c := Color(UiStyle.WARM, a)
		_back.draw_rect(Rect2(CARD.position, Vector2(CARD.size.x, 1)), c)
		_back.draw_rect(Rect2(CARD.position.x, CARD.end.y - 1, CARD.size.x, 1), c)
		_back.draw_rect(Rect2(CARD.position, Vector2(1, CARD.size.y)), c)
		_back.draw_rect(Rect2(CARD.end.x - 1, CARD.position.y, 1, CARD.size.y), c)
	# 等级格：卡片底边里面三小格
	if pips >= 0:
		UiStyle.bars(_back, Vector2(-8, 8), pips, Upgrades.MAX_LEVEL, 5.0, 1.0, 1.0)


func _draw_marks() -> void:
	var col := edge_color()
	# 选中：卡片四角外面一张一缩的角标（拉杆没有卡片，就围着拉杆那一块）
	if focused:
		var r := CARD if _sprite.visible else Rect2(-7, -9, 14, 18)
		UiStyle.corners(_marks, r, _t, col, 3.0)
		if _sprite.visible:
			_marks.draw_rect(Rect2(CARD.position, Vector2(CARD.size.x, 1)), col)
			_marks.draw_rect(Rect2(CARD.position.x, CARD.end.y - 1, CARD.size.x, 1), col)
			_marks.draw_rect(Rect2(CARD.position, Vector2(1, CARD.size.y)), col)
			_marks.draw_rect(Rect2(CARD.end.x - 1, CARD.position.y, 1, CARD.size.y), col)
	# 价签：一块小黑底，价钱前面一个小齿轮
	if _tag.text == "":
		return
	var w := Hud.font().get_string_size(tr(_tag.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var gear := 6.0 if _tag.text.is_valid_int() else 0.0
	var tw := roundf(w + gear + 4.0)
	var tr := Rect2(-roundf(tw * 0.5), tag_y + 1.0, tw, 10)
	_marks.draw_rect(tr, Color(UiStyle.PANEL, 0.88))
	if gear > 0.0:
		var gx := tr.position.x + 2.0
		var gy := tr.position.y + 3.0
		var tc := tag_color()
		_marks.draw_rect(Rect2(gx + 1, gy, 3, 5), tc)
		_marks.draw_rect(Rect2(gx, gy + 1, 5, 3), tc)
		_marks.draw_rect(Rect2(gx + 2, gy + 2, 1, 1), Color(0.1, 0.08, 0.08))
