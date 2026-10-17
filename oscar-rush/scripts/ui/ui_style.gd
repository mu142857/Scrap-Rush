class_name UiStyle
extends RefCounted
## 菜单卡片的共用画法，从开局选武器界面（weapon_select.gd，"游戏设计"会话做的）抽出来，商店用同一套，
## 两边看起来是一套 UI：
## - 卡片：近黑偏紫的半透明底，1 像素细边；选中时边变暖黄，四个角外面各有一个往外一张一缩的小角标。
## - 没选中 / 用不了的：整体调暗（乘 DIM_MOD）。
## - 名字暖黄，说明浅灰，小标签灰；数值是一格一格的小条（亮格暖黄、暗格深灰）。
## weapon_select.gd 本身没改，以后它也可以直接调这里。

const WARM := Color8(255, 211, 138)
const TEXT := Color(0.82, 0.8, 0.78)
const DIM := Color(0.55, 0.55, 0.6)
const POOR := Color8(220, 90, 70)
const PANEL := Color(0.06, 0.055, 0.07, 0.92)
const EDGE := Color(0.35, 0.33, 0.33)
const BAR_OFF := Color(0.22, 0.21, 0.23)
## 没选中的卡片乘这个颜色
const DIM_MOD := Color(0.62, 0.62, 0.66)


## 一张卡片：底 + 细边；on = 选中（暖黄边 + 闪动角标）。edge_on 可以换成别的颜色（比如买不起的红）
static func panel(ci: CanvasItem, r: Rect2, on: bool, time: float, edge_on := WARM, fill := PANEL) -> void:
	ci.draw_rect(r, fill)
	var edge := edge_on if on else EDGE
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), edge)
	ci.draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), edge)
	ci.draw_rect(Rect2(r.position.x, r.position.y, 1, r.size.y), edge)
	ci.draw_rect(Rect2(r.end.x - 1, r.position.y, 1, r.size.y), edge)
	if on:
		corners(ci, r, time, edge_on)


## 选中时四个角外面一张一缩的 L 形小角标（和选武器界面一样：离卡片 2~4 像素，4 像素长）
static func corners(ci: CanvasItem, r: Rect2, time: float, col := WARM, size := 4.0) -> void:
	var k := 2.0 + roundf(absf(sin(time * 5.0)) * 2.0)
	var s := size
	for p: Vector2 in [r.position + Vector2(-k, -k), Vector2(r.end.x + k - s, r.position.y - k),
			Vector2(r.position.x - k, r.end.y + k - s), r.end + Vector2(k - s, k - s)]:
		var left := p.x < r.position.x + r.size.x * 0.5
		var top := p.y < r.position.y + r.size.y * 0.5
		ci.draw_rect(Rect2(p.x, p.y if top else p.y + s - 1, s, 1), col)
		ci.draw_rect(Rect2(p.x if left else p.x + s - 1, p.y, 1, s), col)


## 一排格子条：value 格亮（暖黄），其余暗。blink >= 0 时，第 blink 格（比如"买了就会到的下一级"）一闪一闪
static func bars(ci: CanvasItem, pos: Vector2, value: int, total: int, w := 9.0, h := 4.0, gap := 2.0,
		on_col := WARM, time := 0.0, blink := -1) -> void:
	for j in total:
		var col := on_col if j < value else BAR_OFF
		if j == blink:
			col = BAR_OFF.lerp(on_col, 0.35 + 0.35 * sin(time * 8.0))
		ci.draw_rect(Rect2(pos.x + j * (w + gap), pos.y, w, h), col)


## 图集里的一格图标，按整数倍放大画出来
static func icon(ci: CanvasItem, atlas: Texture2D, index: int, at: Vector2, scale := 1, modulate := Color.WHITE) -> void:
	ci.draw_texture_rect_region(atlas, Rect2(at, Vector2(16, 16) * scale), Rect2(index * 16, 0, 16, 16), modulate)


static func label(text: String, color: Color, pos: Vector2, w: float, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.label_settings = Hud.small_text(color)
	l.text = text
	l.horizontal_alignment = align
	l.position = pos
	l.size = Vector2(w, 12)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## 像素圆环：中点画圆法，一个个 1×1 的格子，硬边
static func pixel_ring(ci: CanvasItem, center: Vector2, r: int, col: Color) -> void:
	var c := center.round()
	var x := r
	var y := 0
	var err := 1 - r
	var done := {}
	while x >= y:
		for p: Vector2 in [Vector2(x, y), Vector2(y, x), Vector2(-y, x), Vector2(-x, y),
				Vector2(-x, -y), Vector2(-y, -x), Vector2(y, -x), Vector2(x, -y)]:
			if not done.has(p):
				done[p] = true
				ci.draw_rect(Rect2(c + p, Vector2.ONE), col)
		y += 1
		if err < 0:
			err += 2 * y + 1
		else:
			x -= 1
			err += 2 * (y - x) + 1


## 像素弧带：离圆心 r_in~r_out、角度在 a0~a1 之间的格子都填上（指针表的色区）
static func pixel_arc_band(ci: CanvasItem, center: Vector2, r_in: float, r_out: float, a0: float, a1: float, col: Color) -> void:
	var c := center.round()
	var n := int(ceilf(r_out))
	for yy in range(-n, n + 1):
		for xx in range(-n, n + 1):
			var d := Vector2(xx + 0.5, yy + 0.5)
			var len := d.length()
			if len < r_in or len > r_out:
				continue
			var a := fposmod(d.angle(), TAU)
			var lo := fposmod(a0, TAU)
			var hi := lo + (a1 - a0)
			if a < lo:
				a += TAU
			if a <= hi:
				ci.draw_rect(Rect2(c + Vector2(xx, yy), Vector2.ONE), col)


## 像素直线：两端取整，逐格画（Bresenham）
static func pixel_line(ci: CanvasItem, from: Vector2, to: Vector2, col: Color) -> void:
	var x0 := int(roundf(from.x))
	var y0 := int(roundf(from.y))
	var x1 := int(roundf(to.x))
	var y1 := int(roundf(to.y))
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		ci.draw_rect(Rect2(x0, y0, 1, 1), col)
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
