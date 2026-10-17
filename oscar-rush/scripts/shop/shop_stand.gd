class_name ShopStand
extends Node2D
## 商店里的一件货：一个图标（可选等级小格），主角走到它前面，头上飘出名字、说明和价钱，
## 按互动键（和捡灯同一个键）就买。买不买得起、买了以后怎么样由 ShopRoom 决定。
## 原点在图标正中。

signal buy_pressed(stand: ShopStand, player: Player)

const ICONS := preload("res://art/shop/icons.png")
## 和 tools/draw_shop.py 的 ICONS 顺序一样
const ICON_NAMES: Array[String] = ["part", "charge", "fuel", "plating", "damping", "repair", "refresh",
		"hammer", "tongs", "horn", "rivet", "rage", "slave", "echo", "dynamo"]
const WARM := Color8(255, 211, 138)
const DIM := Color(0.62, 0.6, 0.6)
const POOR := Color8(220, 90, 70)
const FADE_SPEED := 6.0
## 小齿轮（价钱前面的零件符号），7×7
const GEAR := [
	".#.#.#.",
	"#######",
	".##.##.",
	"###.###",
	".##.##.",
	"#######",
	".#.#.#.",
]

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

var _sprite: Sprite2D
var _panel: Node2D
var _title: Label
var _detail: Label
var _price: Label
var _alpha := 0.0
var _shake := 0.0
var _pop := 0.0
var _key := "V"


func _ready() -> void:
	z_index = 4
	_sprite = Sprite2D.new()
	_sprite.texture = ICONS
	_sprite.hframes = ICON_NAMES.size()
	add_child(_sprite)

	_panel = Node2D.new()
	_panel.z_index = 30
	_panel.z_as_relative = false
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_panel.material = unshaded
	_panel.draw.connect(_draw_panel)
	add_child(_panel)
	_title = _make_label(WARM, -40)
	_detail = _make_label(DIM, -30)
	_price = _make_label(WARM, -20)
	_panel.modulate.a = 0.0
	if not Run.players.is_empty():
		_key = Controls.key_name(Run.players[0]["input"], "crystal")
	refresh_view()


func _make_label(color: Color, y: float) -> Label:
	var l := Label.new()
	l.use_parent_material = true
	l.label_settings = Hud.small_text(color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(160, 12)
	l.position = Vector2(-80, y)
	_panel.add_child(l)
	return l


## info 或图标变了以后调一次
func refresh_view() -> void:
	if _sprite == null:
		return
	_sprite.frame = maxi(ICON_NAMES.find(icon), 0)
	_sprite.modulate = Color(0.45, 0.42, 0.42) if info.get("dim", false) else Color.WHITE
	_title.text = info.get("title", "")
	_detail.text = info.get("detail", "")
	var price: int = info.get("price", 0)
	if info.get("can_buy", false) or price > 0:
		_price.text = ("x%d   %s  BUY" % [price, _key]) if price > 0 else ("FREE   %s" % _key)
	else:
		_price.text = ""
	_price.label_settings = Hud.small_text(WARM if info.get("can_buy", false) else POOR) \
			if _price.text != "" else _price.label_settings
	# 字不要伸出画面左右两边
	var w := 0.0
	for l in [_title, _detail, _price]:
		w = maxf(w, Hud.font().get_string_size((l as Label).text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x)
	var half := w * 0.5 + 4.0
	var shift := clampf(0.0, half - global_position.x, 480.0 - half - global_position.x)
	for l in [_title, _detail, _price]:
		(l as Label).position.x = -80.0 + shift
	_panel.queue_redraw()


## 买不起：字抖一下
func deny() -> void:
	_shake = 0.3


## 买到了：图标弹一下
func pop() -> void:
	_pop = 1.0


func near(p: Player) -> bool:
	var d := p.global_position - global_position
	return absf(d.x) <= zone_half and d.y > -4.0 and d.y < 100.0


func _physics_process(delta: float) -> void:
	_shake = maxf(_shake - delta, 0.0)
	_pop = maxf(_pop - delta * 4.0, 0.0)
	var someone := false
	for n in get_tree().get_nodes_in_group("player"):
		var p := n as Player
		if p == null or not near(p):
			continue
		someone = true
		if Input.is_action_just_pressed(p.input_prefix + "_crystal"):
			buy_pressed.emit(self, p)
	_alpha = move_toward(_alpha, 1.0 if someone else 0.0, delta * FADE_SPEED)
	_panel.modulate.a = _alpha
	_panel.visible = _alpha > 0.0
	_panel.position = Vector2(roundf(sin(_shake * 60.0) * 2.0 * signf(_shake)), 0)
	_sprite.position = Vector2(0, -roundf(sin(_pop * PI) * 3.0))
	queue_redraw()


func _draw() -> void:
	if pips < 0:
		return
	# 三个等级小格，在图标下面
	for i in Upgrades.MAX_LEVEL:
		var r := Rect2(-6 + i * 4, 10, 3, 2)
		draw_rect(r, WARM if i < pips else Color(0.22, 0.2, 0.2))


func _draw_panel() -> void:
	if _price.text == "" or info.get("price", 0) <= 0:
		return
	# 价钱前面画一个小齿轮
	var tw := Hud.font().get_string_size(_price.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var x0 := roundf(_price.position.x + 80.0 - tw * 0.5) - 9.0
	var col: Color = _price.label_settings.font_color
	for y in GEAR.size():
		var row: String = GEAR[y]
		for x in row.length():
			if row[x] == "#":
				_panel.draw_rect(Rect2(x0 + x, _price.position.y + 2 + y + 1, 1, 1), Color(0.03, 0.03, 0.045))
				_panel.draw_rect(Rect2(x0 + x, _price.position.y + 2 + y, 1, 1), col)
