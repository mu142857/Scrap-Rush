class_name PixelDraw
## 一格一格画线、弧、圆，代替 draw_line / draw_arc / draw_circle。
## 工程是 canvas_items 放大：draw_line 不给宽度时画出来只有屏幕上 1 个物理像素宽（游戏里 1/3 格），
## draw_arc / draw_circle 是平滑曲线，都和像素画对不上。这里全部换成 1×1 的 draw_rect，位置取整。
##
## 用法（在 _draw 里）：
##   PixelDraw.line(self, Vector2(-16, 0), Vector2(-20, 7), col)
##   PixelDraw.arc(self, center, r, PI * 1.15, PI * 1.45, col)
##   PixelDraw.disc(self, center, 7, fill)   PixelDraw.ring(self, center, 7, edge)


## 两点之间的直线（Bresenham），两头都画
static func line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color) -> void:
	var x0 := roundi(a.x)
	var y0 := roundi(a.y)
	var x1 := roundi(b.x)
	var y1 := roundi(b.y)
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		ci.draw_rect(Rect2(x0, y0, 1, 1), col)
		if x0 == x1 and y0 == y1:
			return
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


## 圆弧：从 a0 到 a1（弧度，和 draw_arc 一样），一格宽
static func arc(ci: CanvasItem, center: Vector2, r: float, a0: float, a1: float, col: Color) -> void:
	var steps := maxi(4, ceili(absf(a1 - a0) * maxf(r, 1.0) * 1.5))
	var last := Vector2i(1 << 30, 0)
	for i in steps + 1:
		var ang := lerpf(a0, a1, float(i) / steps)
		var p := Vector2i((center + Vector2(cos(ang), sin(ang)) * r).round())
		if p != last:
			ci.draw_rect(Rect2(p, Vector2.ONE), col)
			last = p


## 整圈
static func ring(ci: CanvasItem, center: Vector2, r: float, col: Color) -> void:
	arc(ci, center, r, 0.0, TAU, col)


## 实心圆：一行一段
static func disc(ci: CanvasItem, center: Vector2, r: float, col: Color) -> void:
	var c := center.round()
	var ri := ceili(r)
	for dy in range(-ri, ri + 1):
		var half := floori(sqrt(maxf(r * r - dy * dy, 0.0)) + 0.5)
		if r * r - dy * dy < 0.0:
			continue
		ci.draw_rect(Rect2(c.x - half, c.y + dy, half * 2 + 1, 1), col)
