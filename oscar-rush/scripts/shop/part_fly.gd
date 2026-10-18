class_name PartFly
extends Node2D
## 商店里买东西时，零件从人身上一颗颗飞到货架上（ShopRoom._on_buy 里按价钱生几颗）。
## 走一条往上拱的弧线，落到货上冒两颗火星，调 on_arrive（商店在这里放"叮"一声）。
## 5×5 的像素小齿轮，不吃场景压暗；位置取整，不做平滑缩放。

const WARM := Color8(255, 211, 138)
const DARK := Color8(150, 112, 70)
const GEAR := [
	".#.#.",
	"#####",
	".#o#.",
	"#####",
	".#.#.",
]

var from := Vector2.ZERO
var to := Vector2.ZERO
var delay := 0.0
var duration := 0.32
var arc := 22.0
var on_arrive: Callable
var _t := 0.0


func _ready() -> void:
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
	z_index = 20
	position = from.round()
	visible = false


func _process(delta: float) -> void:
	_t += delta
	if _t < delay:
		return
	visible = true
	var k := clampf((_t - delay) / duration, 0.0, 1.0)
	position = (from.lerp(to, k) + Vector2(0, -sin(k * PI) * arc)).round()
	if k >= 1.0:
		Game.sparks(get_parent(), to, WARM, 3, 40.0)
		if on_arrive.is_valid():
			on_arrive.call()
		queue_free()


func _draw() -> void:
	for y in GEAR.size():
		var row: String = GEAR[y]
		for x in row.length():
			var c := row[x]
			if c == ".":
				continue
			draw_rect(Rect2(x - 2, y - 2, 1, 1), DARK if c == "o" else WARM)
