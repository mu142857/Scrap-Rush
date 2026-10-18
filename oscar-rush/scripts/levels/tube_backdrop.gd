class_name TubeBackdrop
extends Node2D
## 第二关开场「气动管冲刺」的多层视差背景（10-18 作者："第二关开始的移动的场景的背景太单调，比起第一关的视差背景差太多了，
## 没有质感了"）。贴图是 草图/第二关/tube_backdrop_art.py 画的五张能左右无缝接上的循环图，位置表在 tube_backdrop_data.gd。
## 从远到近（倍速 = 跟着赛道走的速度，赛道 = 1）：
##   0 窗外的夜 0.03  1 大厅的墙、拱窗、接线板 0.12  2 柱子、电缆、吊灯、继电器柜 0.3
##   3 钢梁、蒸汽管、阀门、压力表、竖着的别的气动管 0.6  ——以上在三条道后面——
##   4 镜头前擦过的大钢箍、粗管弯头、电缆剪影 1.9（压在三条道前面；道那一段只留很淡的影子）
## 另外这里画会动的：接线板和继电器的小灯一闪一闪、吊灯的暖光晕、压力表指针抖、别的气动管里的胶囊和信件筒上下飞，
## 还有压在最前面的：每隔 LAMP_GAP 像素一盏管道灯掠过（一道暖光扫过三条道，玻璃管上亮一下），玻璃反光、偶尔一团蒸汽、一串火花。
## 用法（tube_run.gd 里）：_ready 里 add_child(TubeBackdrop.new())，物理帧里调 scroll(dist, speed, delta)。
## 只管画面，不碰赛道和碰撞。

const D := preload("res://scripts/levels/tube_backdrop_data.gd")
const VIEW_W := 480.0
const VIEW_H := 270.0
const LANES: Array[float] = [104.0, 140.0, 176.0]
const BAND := Vector2(93.0, 187.0)
## 管道灯的间距（赛道像素）：底速 250 时约 1.7 秒一盏
const LAMP_GAP := 420.0
const LAMP_R := 38.0
const LAMP_PEAK := 0.11
const WARM := Color(1.0, 0.74, 0.42)
const LAMP_ON := Color8(236, 178, 86)
const LAMP_DIM := Color8(70, 50, 36)
const RED_ON := Color8(230, 90, 60)
const RED_DIM := Color8(70, 34, 28)

var dist := 0.0
var speed := 250.0

var _t := 0.0
var _layers: Array[Node2D] = []
var _fx: Array[LayerFx] = []
var _front_add: FrontAdd
var _front: Front
var _rng := RandomNumberGenerator.new()
## 蒸汽团 {p, v, r, t, life}、火花 {p, v, t, life}
var _puffs: Array = []
var _sparks: Array = []
var _puff_cd := 1.5
var _spark_cd := 2.2


func _ready() -> void:
	_rng.seed = 2210
	var front_root := Node2D.new()
	front_root.z_index = 5                       # 压在三条道（Track，z 0）前面
	add_child(front_root)
	for i in D.LAYERS.size():
		var l: Array = D.LAYERS[i]
		var root := Node2D.new()
		root.modulate = l[3]
		if l[4]:
			front_root.add_child(root)
		else:
			root.z_index = -24 + i
			add_child(root)
		var tex: Texture2D = load(l[0])
		for k in 2:
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			s.position.x = k * float(l[1])
			root.add_child(s)
		var fx := LayerFx.new()
		fx.bd = self
		fx.layer = i
		fx.w = float(l[1])
		root.add_child(fx)
		_layers.append(root)
		_fx.append(fx)
	_front_add = FrontAdd.new()
	_front_add.bd = self
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_front_add.material = add
	front_root.add_child(_front_add)
	_front = Front.new()
	_front.bd = self
	front_root.add_child(_front)


## 每个物理帧调一次：dist = 赛道走了多远（像素），speed = 当前速度（像素/秒）
func scroll(d: float, spd: float, delta: float) -> void:
	dist = d
	speed = spd
	_t += delta
	for i in _layers.size():
		var l: Array = D.LAYERS[i]
		_layers[i].position.x = -fposmod(d * float(l[2]), float(l[1]))
		_fx[i].queue_redraw()
	_tick_fx(delta)
	_front_add.queue_redraw()
	_front.queue_redraw()


func _tick_fx(delta: float) -> void:
	# 蒸汽：从上面的弯头 / 下面的蒸汽管那一带喷出来一小团，被风往后吹、慢慢散开（不进三条道）
	_puff_cd -= delta
	if _puff_cd <= 0.0:
		_puff_cd = _rng.randf_range(1.2, 2.8)
		var top := _rng.randf() < 0.5
		var y := _rng.randf_range(62.0, 80.0) if top else _rng.randf_range(200.0, 222.0)
		var p := Vector2(_rng.randf_range(260.0, 470.0), y)
		for k in 4:
			_puffs.append({"p": p + Vector2(k * 4.0, _rng.randf_range(-2.0, 2.0)), "v": Vector2(-speed * 0.9, 10.0 if top else -10.0),
				"r": 2.0 + k * 0.5, "t": -k * 0.04, "life": _rng.randf_range(0.6, 0.9)})
	# 火花：下面那根蒸汽管的法兰漏电，啪地蹦一小串
	_spark_cd -= delta
	if _spark_cd <= 0.0:
		_spark_cd = _rng.randf_range(1.8, 3.6)
		var sp := Vector2(_rng.randf_range(200.0, 470.0), _rng.randf_range(222.0, 236.0))
		for k in 7:
			var a := _rng.randf_range(-PI * 0.9, -PI * 0.1)
			_sparks.append({"p": sp, "v": Vector2(cos(a), sin(a)) * _rng.randf_range(40.0, 110.0) + Vector2(-speed * 0.6, 0.0),
				"t": 0.0, "life": _rng.randf_range(0.25, 0.5)})
	for e in _puffs:
		e["t"] += delta
		e["p"] += e["v"] * delta
		e["r"] += 9.0 * delta
	_puffs = _puffs.filter(func(e): return e["t"] < e["life"])
	for e in _sparks:
		e["t"] += delta
		e["v"].y += 320.0 * delta
		e["p"] += e["v"] * delta
	_sparks = _sparks.filter(func(e): return e["t"] < e["life"] and e["p"].y < BAND.y + 90.0)


## 一颗灯这一刻亮不亮：每颗灯有自己的相位和节奏（按位置算，换场景也一样）
func lamp_on(x: int, y: int, kind: int) -> bool:
	var h := float((x * 73856093) ^ (y * 19349663)) * 0.0000001
	match kind:
		0:   # 插孔灯：平时灭，偶尔亮一阵（有人接通了）
			return fposmod(_t * 0.23 + h, 1.0) < 0.22
		1:   # 插孔灯：平时亮，偶尔灭一下
			return fposmod(_t * 0.31 + h, 1.0) > 0.12
		2:   # 继电器琥珀灯：咔哒咔哒快闪
			return fposmod(_t * 2.6 + h, 1.0) < 0.6
		3:   # 继电器红灯：慢闪
			return fposmod(_t * 1.1 + h, 1.0) < 0.5
		5:   # 铁塔红灯：一秒亮一下
			return fposmod(_t, 1.2) < 0.5
	return true


## 每一层自己的会动的东西（跟着那一层一起卷）
class LayerFx extends Node2D:
	var bd: TubeBackdrop
	var layer := 0
	var w := 960.0

	func _draw() -> void:
		var ox: float = (get_parent() as Node2D).position.x
		for k in 2:
			var base := k * w
			# 只画在画面里的
			var lo := -ox - base - 8.0
			var hi := lo + TubeBackdrop.VIEW_W + 16.0
			_blinks(base, lo, hi)
			match layer:
				2:
					_glows(base, lo, hi)
				3:
					_tubes(base, lo, hi)
					_gauges(base, lo, hi)
				4:
					_hoop_shadows(base, lo, hi)

	func _blinks(base: float, lo: float, hi: float) -> void:
		var arr: Array = TubeBackdrop.D.BLINKS[layer]
		for i in range(0, arr.size(), 3):
			var x: int = arr[i]
			if x < lo or x > hi:
				continue
			var y: int = arr[i + 1]
			var kind: int = arr[i + 2]
			var on := bd.lamp_on(x, y, kind)
			var col: Color
			if kind == 3 or kind == 5:
				col = TubeBackdrop.RED_ON if on else TubeBackdrop.RED_DIM
			else:
				col = TubeBackdrop.LAMP_ON if on else TubeBackdrop.LAMP_DIM
			draw_rect(Rect2(base + x, y, 1, 1), col)
			if on and kind == 5:
				draw_rect(Rect2(base + x - 1, y - 1, 3, 3), Color(1.0, 0.35, 0.25, 0.25))

	## 吊灯：灯泡底下一圈暖光晕，再往下一道很淡的光锥
	func _glows(base: float, lo: float, hi: float) -> void:
		var arr: Array = TubeBackdrop.D.GLOWS
		for i in range(0, arr.size(), 2):
			var x := float(arr[i])
			if x < lo - 30.0 or x > hi + 30.0:
				continue
			var c := Vector2(base + x, float(arr[i + 1]) + 1.0)
			var flick := 0.9 + 0.1 * sin(bd._t * 23.0 + x)
			PixelDraw.disc(self, c, 14.0, Color(1.0, 0.75, 0.45, 0.05 * flick))
			PixelDraw.disc(self, c, 7.0, Color(1.0, 0.8, 0.5, 0.09 * flick))
			for yy in range(int(c.y) + 3, int(c.y) + 60, 2):
				var half := 3.0 + (yy - c.y) * 0.45
				draw_rect(Rect2(roundf(c.x - half), yy, roundf(half * 2.0), 2), Color(1.0, 0.78, 0.5, 0.025 * flick))

	## 竖着穿过三条道后面的别的气动管：每根里一上一下两件东西飞过去（黄铜胶囊 / 牛皮纸信件筒）
	func _tubes(base: float, lo: float, hi: float) -> void:
		var arr: Array = TubeBackdrop.D.TUBES
		for i in arr.size():
			var x := float(arr[i])
			if x < lo - 10.0 or x > hi + 10.0:
				continue
			for j in 2:
				var up := (i + j) % 2 == 0
				var v := 150.0 + 40.0 * ((i * 3 + j) % 3)
				var y := fposmod(bd._t * v + 97.0 * i + 160.0 * j, TubeBackdrop.VIEW_H + 120.0) - 40.0
				if up:
					y = TubeBackdrop.VIEW_H - y
				var cx := base + x - 3.0
				if (i + j) % 3 == 0:
					# 信件筒：牛皮纸色，中间一道红封条
					draw_rect(Rect2(cx, y, 6, 12), Color8(150, 120, 80))
					draw_rect(Rect2(cx, y, 1, 12), Color8(186, 156, 106))
					draw_rect(Rect2(cx, y + 5, 6, 2), Color8(150, 56, 40))
				else:
					# 黄铜胶囊：两头暗、中间一圈亮
					draw_rect(Rect2(cx, y, 6, 12), Color8(134, 117, 63))
					draw_rect(Rect2(cx, y, 1, 12), Color8(170, 150, 92))
					draw_rect(Rect2(cx, y, 6, 2), Color8(90, 78, 42))
					draw_rect(Rect2(cx, y + 10, 6, 2), Color8(90, 78, 42))
				# 身后拖一条很淡的影子（速度感）
				draw_rect(Rect2(cx + 1, y + (12.0 if up else -10.0), 4, 10), Color(0.9, 0.8, 0.6, 0.08))

	## 压力表指针：各自停在不同的刻度，一直在抖
	func _gauges(base: float, lo: float, hi: float) -> void:
		var arr: Array = TubeBackdrop.D.GAUGES
		for i in range(0, arr.size(), 2):
			var x := float(arr[i])
			if x < lo - 10.0 or x > hi + 10.0:
				continue
			var c := Vector2(base + x, float(arr[i + 1]))
			var a := deg_to_rad(150.0 + 40.0 * (i % 5)) + 0.18 * sin(bd._t * (6.0 + i)) + 0.05 * sin(bd._t * 31.0 + i)
			PixelDraw.line(self, c.round(), (c + Vector2(cos(a), sin(a)) * 4.0).round(), Color8(110, 36, 28))
			draw_rect(Rect2(c.round(), Vector2(1, 1)), Color8(60, 50, 40))

	## 近景大钢箍在三条道那一段的淡影子（贴图里只画了道外面实的两截）
	func _hoop_shadows(base: float, lo: float, hi: float) -> void:
		var arr: Array = TubeBackdrop.D.NEAR_HOOPS
		var hw := float(TubeBackdrop.D.NEAR_HOOP_W)
		for xi in arr:
			var x := float(xi)
			if x + hw < lo or x > hi:
				continue
			draw_rect(Rect2(base + x + 2, TubeBackdrop.BAND.x - 2, hw - 4, TubeBackdrop.BAND.y - TubeBackdrop.BAND.x + 5),
				Color(0.04, 0.03, 0.03, 0.22))


## 压在最前面、加色混合的光：管道灯扫过去的一道暖光、玻璃管上的反光
class FrontAdd extends Node2D:
	var bd: TubeBackdrop

	func _draw() -> void:
		var gap := TubeBackdrop.LAMP_GAP
		var off := fposmod(bd.dist, gap)
		var x := -off + 60.0
		while x < TubeBackdrop.VIEW_W + TubeBackdrop.LAMP_R:
			_lamp_light(x)
			x += gap
		# 玻璃反光：每条道各自隔一段距离一道斜的亮条，比赛道快（玻璃的另一面在动）
		for li in TubeBackdrop.LANES.size():
			var ly: float = TubeBackdrop.LANES[li]
			var p := 610.0 + 70.0 * li
			var gx := -fposmod(bd.dist * 2.3 + 190.0 * li, p) + TubeBackdrop.VIEW_W + 40.0
			while gx > -20.0:
				for k in 8:
					draw_rect(Rect2(roundf(gx + k * 0.6), ly - 7 + k, 2, 1), Color(1, 0.95, 0.85, 0.16))
					draw_rect(Rect2(roundf(gx + 5 + k * 0.6), ly - 7 + k, 1, 1), Color(1, 0.95, 0.85, 0.08))
				gx -= p

	## 一盏灯打下来的光：竖着一道（中间亮两边暗），扫到的玻璃管上沿亮一下
	func _lamp_light(x: float) -> void:
		var r := TubeBackdrop.LAMP_R
		var dx := -r
		while dx < r:
			var k := 1.0 - absf(dx) / r
			var a := TubeBackdrop.LAMP_PEAK * k * k
			draw_rect(Rect2(roundf(x + dx), 8, 2, TubeBackdrop.VIEW_H - 8), Color(TubeBackdrop.WARM, a))
			dx += 2.0
		for ly in TubeBackdrop.LANES:
			var hw := roundf(r * 0.55)
			draw_rect(Rect2(roundf(x) - hw, ly - 7, hw * 2.0, 1), Color(1.0, 0.85, 0.6, 0.35))
			draw_rect(Rect2(roundf(x) - hw * 0.5, ly - 6, hw, 1), Color(1.0, 0.85, 0.6, 0.15))
		PixelDraw.disc(self, Vector2(roundf(x), 9), 10.0, Color(1.0, 0.8, 0.5, 0.18))


## 压在最前面、普通混合：管道灯的灯头、蒸汽、火花
class Front extends Node2D:
	var bd: TubeBackdrop

	func _draw() -> void:
		var gap := TubeBackdrop.LAMP_GAP
		var x := -fposmod(bd.dist, gap) + 60.0
		while x < TubeBackdrop.VIEW_W + 12.0:
			var cx := roundf(x)
			# 管道灯：顶上一根短吊杆、一个铁丝罩、里面一颗暖白灯泡
			draw_rect(Rect2(cx, 0, 1, 4), Color8(40, 34, 30))
			draw_rect(Rect2(cx - 3, 4, 7, 2), Color8(60, 52, 40))
			draw_rect(Rect2(cx - 2, 6, 5, 4), Color8(250, 214, 150))
			draw_rect(Rect2(cx - 1, 7, 3, 2), Color8(255, 244, 214))
			draw_rect(Rect2(cx - 3, 6, 1, 4), Color8(60, 52, 40))
			draw_rect(Rect2(cx + 3, 6, 1, 4), Color8(60, 52, 40))
			draw_rect(Rect2(cx - 3, 10, 7, 1), Color8(60, 52, 40))
			x += gap
		for e in bd._puffs:
			if e["t"] < 0.0:
				continue
			var k: float = 1.0 - e["t"] / e["life"]
			PixelDraw.disc(self, (e["p"] as Vector2).round(), e["r"], Color(0.82, 0.8, 0.78, 0.32 * k))
		for e in bd._sparks:
			var k: float = 1.0 - e["t"] / e["life"]
			var p: Vector2 = (e["p"] as Vector2).round()
			draw_rect(Rect2(p, Vector2(1, 1)), Color(1.0, 0.9, 0.6, k))
			draw_rect(Rect2(p + Vector2(1, 0), Vector2(1, 1)), Color(1.0, 0.6, 0.3, 0.6 * k))
