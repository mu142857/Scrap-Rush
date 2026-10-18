extends Node2D
## 第二关的"活气"（10-18 夜间打磨）：让场景自己动一动，再藏几个能互动的小东西。都不影响主线玩法。
##
##   插孔灯 / 继电器灯   机房墙上的小灯自己亮起、熄灭（位置是 level2_map.py 画墙时记下来的 D.BLINKS）
##   吊灯               每间机房和放映室顶上一盏，轻轻摇；被打中会晃得厉害，再慢慢停下
##   银幕               放映厅的银幕上闪着老电影（胶片上那 11 格致敬镜头轮流放），带划痕、灰点、明暗跳动
##   胶片上的影子        镜头在天桥上时，偶尔一只大飞蛾的影子从胶片上掠过（扑放映机的灯）
##   墙上的油灯（3 盏）  打碎了掉一滴灯油（LampOil，给马灯回一点血）
##   墙上的电话（4 部）  打一下就响（遭遇战没在打的时候）；电话簿仓库那部连打三下，像投币电话退币一样吐出一个零件
##
## 只在镜头附近才更新和重画；灯光也按画面开关（和 level2.gd 的 _cull_lights 一样）。

const D := preload("res://scripts/levels/level2_data.gd")
const FILM_TEX := preload("res://art/levels/level2_film.png")

## 吊灯：挂点（天花板底面）、线长。R3 正中是挂钟，灯挪到左边书架上方
const HANGING := [
	[Vector2(230, 440), 14.0], [Vector2(716, 340), 12.0], [Vector2(150, 150), 14.0],
	[Vector2(780, 200), 16.0], [Vector2(2900, 214), 12.0],
]
## 墙上的油灯（挂在墙上的位置）
const OIL_LAMPS: Array[Vector2] = [Vector2(590, 372), Vector2(92, 178), Vector2(574, 236)]
## 连打三下会吐零件的电话（D.PHONES 的下标）和它下面的地面
const PAYPHONE := 2
const PAYPHONE_FLOOR := 250.0
## 银幕（level2_map.py 的 sx0, sy0, sw, sh）里放电影的那块：胶片一格 90×64，放大 3 倍
const SCREEN := Rect2(3370, 190, 296, 214)
const FRAME := Vector2(90, 64)
const FRAME_SCALE := 3.0

var level: Node2D
var _view := Rect2()
var _view_t := 0.0
var _lights: Array[PointLight2D] = []
var _phones: Array = []


func _ready() -> void:
	z_index = -16
	var blinks := Blinks.new()
	add_child(blinks)
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	for h in HANGING:
		var lamp := HangingLamp.new()
		lamp.position = h[0]
		lamp.cord = h[1]
		add_child(lamp)
		_lights.append(lamp.light)
	for p in OIL_LAMPS:
		var oil := OilLamp.new()
		oil.position = p
		add_child(oil)
		_lights.append(oil.light)
	for i in D.PHONES.size():
		var ph := Phone.new()
		ph.position = D.PHONES[i]
		ph.index = i
		ph.life = self
		add_child(ph)
		_phones.append(ph)
	var screen := Screen.new()
	screen.material = unshaded
	add_child(screen)
	var shadow := FilmShadow.new()
	shadow.material = unshaded
	shadow.life = self
	add_child(shadow)
	# 银幕那盏灯跟着画面一起闪
	for n in get_parent().get_children():
		if n is PointLight2D and (n as PointLight2D).position.distance_to(Vector2(3518, 297)) < 1.0:
			screen.light = n
	# 蒸汽锤是一圈范围攻击、不是飞出去的东西，打不到 Area2D：它出现时自己量一下距离
	get_tree().node_added.connect(_on_node_added)


func _process(delta: float) -> void:
	_view_t -= delta
	if _view_t <= 0.0:
		_view_t = 0.1
		var cam: Camera2D = level.get("_cam") if level else null
		if cam and cam.has_method("view_rect"):
			_view = cam.call("view_rect")
		for l in _lights:
			if is_instance_valid(l):
				var r := l.texture_scale * 32.0
				l.enabled = l.visible and _view.grow(16.0 + r).has_point(l.global_position)


## 某个点在不在画面附近（margin 像素以内）
func near_view(p: Vector2, margin := 24.0) -> bool:
	return _view.grow(margin).has_point(p)


## 这部电话现在能不能响：它那场遭遇战没在打（还没开始，或者打完了）
func phone_free(i: int) -> bool:
	var encs: Array = level.get("_encounters") if level else []
	if i >= encs.size():
		return true
	var e: Node = encs[i]
	return not e.get("started") or e.get("cleared")


func _on_node_added(n: Node) -> void:
	if n is SteamBlast:
		_steam_check.call_deferred(n)


func _steam_check(n: Node) -> void:
	if not is_instance_valid(n):
		return
	var at: Vector2 = (n as Node2D).global_position
	for c in get_children():
		if c.has_method("knock") and (c as Node2D).global_position.distance_to(at) < SteamBlast.RADIUS:
			c.call("knock", ((c as Node2D).global_position - at).normalized())


## ---------------------------------------------------------------- 插孔灯、继电器灯
## 灭着的偶尔亮一阵，亮着的偶尔灭一下。继电器灯快（一闪一闪），插孔灯慢（接通一阵再断开）。
## 亮的用不吃压暗的材质画在 _lit 里，灭的画在自己身上（吃压暗，和墙上原来的灭灯一样暗）
class Blinks extends Node2D:
	var _lit: Node2D
	var _state := PackedByteArray()    # 0 原样 1 亮 2 灭
	var _until := PackedFloat32Array()
	var _t := 0.0
	var _tick := 0.0
	var _dirty := true

	func _ready() -> void:
		_state.resize(D.BLINKS.size())
		_until.resize(D.BLINKS.size())
		_lit = Node2D.new()
		var m := CanvasItemMaterial.new()
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		_lit.material = m
		_lit.draw.connect(_draw_lit)
		add_child(_lit)

	func _process(delta: float) -> void:
		var life: Node = get_parent()
		_t += delta
		_tick -= delta
		for i in _state.size():
			if _state[i] != 0 and _t >= _until[i]:
				_state[i] = 0
				_dirty = true
		if _tick <= 0.0:
			_tick = 0.07
			# 每次挑几盏在画面里的灯换一下状态
			for k in 3:
				var i := randi() % D.BLINKS.size()
				var b: Vector3i = D.BLINKS[i]
				if _state[i] != 0 or not life.near_view(Vector2(b.x, b.y)):
					continue
				var relay := b.z >= 2
				if b.z == 0 or b.z == 4:
					_state[i] = 1
					_until[i] = _t + (randf_range(0.1, 0.5) if relay else randf_range(0.6, 3.0))
				elif randf() < 0.5:
					_state[i] = 2
					_until[i] = _t + (randf_range(0.08, 0.3) if relay else randf_range(0.3, 1.2))
				_dirty = true
		if _dirty:
			_dirty = false
			queue_redraw()
			_lit.queue_redraw()

	func _draw() -> void:
		for i in _state.size():
			if _state[i] == 2:
				var b: Vector3i = D.BLINKS[i]
				draw_rect(Rect2(b.x, b.y, 1, 1), D.BLINK_COLORS[0])

	func _draw_lit() -> void:
		for i in _state.size():
			if _state[i] == 1:
				var b: Vector3i = D.BLINKS[i]
				var col: Color = D.BLINK_COLORS[2] if b.z == 3 else D.BLINK_COLORS[1]
				_lit.draw_rect(Rect2(b.x, b.y, 1, 1), col)


## ---------------------------------------------------------------- 吊灯
## 一根线、黄铜灯罩、暖黄的泡。慢慢摆（各盏周期不同），灯光跟着泡走。打中就猛地晃一下，几秒后慢慢停
class HangingLamp extends Node2D:
	const BASE_SWING := 0.07
	var cord := 14.0
	var light: PointLight2D
	var _t := 0.0
	var _period := 3.0
	var _kick := 0.0
	var _kick_dir := 1.0
	var _bulb: Node2D

	func _init() -> void:
		light = PointLight2D.new()
		light.texture = Game.light_texture()
		light.color = Color(1.0, 0.82, 0.58)
		light.energy = 0.42

	func _ready() -> void:
		_t = randf() * 10.0
		_period = randf_range(2.6, 3.6)
		# 顶灯照亮房间深处（原来 level2.gd 里每间房一盏固定的顶灯，现在挂在这盏吊灯上）
		var room_w := 220.0
		for r in D.ROOMS:
			if (r["rect"] as Rect2).grow(20.0).has_point(position):
				room_w = (r["rect"] as Rect2).size.x
		light.texture_scale = room_w * 0.6 / 32.0
		add_child(light)
		_bulb = Node2D.new()
		var m := CanvasItemMaterial.new()
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		_bulb.material = m
		_bulb.draw.connect(_draw_bulb)
		add_child(_bulb)
		LifeHit.area(self, Vector2(10, cord + 8), Vector2(0, cord * 0.5 + 2))

	func knock(dir: Vector2) -> void:
		_kick = 0.42
		_kick_dir = signf(dir.x) if dir.x != 0.0 else 1.0
		Game.sfx("clang", -18.0, 1.6, 0.1)

	func _angle() -> float:
		var a := BASE_SWING * sin(_t * TAU / _period)
		return a + _kick * _kick_dir * sin(_t * 5.5)

	func _tip() -> Vector2:
		return Vector2(0, cord).rotated(-_angle())

	func _process(delta: float) -> void:
		var life: Node = get_parent()
		if not life.near_view(global_position, 40.0):
			return
		_t += delta
		_kick = move_toward(_kick, 0.0, delta * 0.12)
		var tip := _tip()
		light.position = tip + Vector2(0, 4)
		light.energy = 0.42 + 0.02 * sin(_t * 23.0)
		queue_redraw()
		_bulb.queue_redraw()

	func _draw() -> void:
		var tip := _tip()
		PixelDraw.line(self, Vector2.ZERO, tip, Color8(70, 64, 58))
		var p := tip.round()
		draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 1)), Color8(150, 128, 80))
		draw_rect(Rect2(p + Vector2(-3, 1), Vector2(7, 2)), Color8(120, 100, 62))
		draw_rect(Rect2(p + Vector2(-3, 1), Vector2(7, 1)), Color8(170, 148, 96))

	func _draw_bulb() -> void:
		var p := _tip().round()
		_bulb.draw_rect(Rect2(p + Vector2(-1, 3), Vector2(3, 2)), Color8(240, 200, 130))
		_bulb.draw_rect(Rect2(p + Vector2(0, 3), Vector2(1, 1)), Color8(255, 240, 205))


## ---------------------------------------------------------------- 墙上的油灯
## 铁托架上一只玻璃罩，里面一小簇火苗。打碎：玻璃碴往外溅、火灭了，掉一滴灯油
class OilLamp extends Node2D:
	var light: PointLight2D
	var _broken := false
	var _t := 0.0
	var _flame: Node2D

	func _init() -> void:
		light = PointLight2D.new()
		light.texture = Game.light_texture()
		light.color = Color(1.0, 0.76, 0.46)
		light.energy = 0.55
		light.texture_scale = 40.0 / 32.0
		light.position = Vector2(0, -6)

	func _ready() -> void:
		add_child(light)
		_t = randf() * 5.0
		_flame = Node2D.new()
		var m := CanvasItemMaterial.new()
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		_flame.material = m
		_flame.draw.connect(_draw_flame)
		add_child(_flame)
		LifeHit.area(self, Vector2(8, 12), Vector2(0, -5))

	func knock(dir: Vector2) -> void:
		if _broken:
			return
		_broken = true
		light.visible = false
		light.enabled = false
		Game.sfx("crack", -8.0, 1.5, 0.1)
		Game.sparks(get_parent(), global_position + Vector2(0, -6), Color(0.85, 0.9, 0.95), 8, 80.0, dir)
		Game.sparks(get_parent(), global_position + Vector2(0, -6), Color(1.0, 0.7, 0.35), 5, 50.0)
		var oil := LampOil.new()
		oil.position = global_position + Vector2(0, -4)
		oil.set("_vel", Vector2(dir.x * 30.0, -90.0))
		get_parent().get_parent().add_child.call_deferred(oil)
		queue_redraw()
		_flame.queue_redraw()

	func _process(delta: float) -> void:
		if _broken or not get_parent().near_view(global_position):
			return
		_t += delta
		light.energy = 0.55 + 0.06 * sin(_t * 9.0) + 0.04 * sin(_t * 23.0)
		if int(_t * 8.0) != int((_t - delta) * 8.0):
			_flame.queue_redraw()

	func _draw() -> void:
		# 托架：从墙上伸出来的一根铁条 + 底座
		draw_rect(Rect2(-4, 1, 6, 1), Color8(60, 54, 50))
		draw_rect(Rect2(-2, 0, 5, 1), Color8(96, 82, 60))
		if _broken:
			draw_rect(Rect2(-2, -2, 1, 2), Color8(150, 160, 165))
			draw_rect(Rect2(2, -1, 1, 1), Color8(150, 160, 165))
			return
		# 玻璃罩：两边亮一点的竖边，顶上一个小盖
		draw_rect(Rect2(-2, -9, 1, 9), Color8(150, 160, 165))
		draw_rect(Rect2(2, -9, 1, 9), Color8(110, 118, 124))
		draw_rect(Rect2(-1, -10, 3, 1), Color8(96, 82, 60))

	func _draw_flame() -> void:
		if _broken:
			return
		var h := 3 + int(_t * 8.0) % 2
		_flame.draw_rect(Rect2(-1, -1 - h, 3, h), Color8(240, 168, 80))
		_flame.draw_rect(Rect2(0, -h, 1, h - 1), Color8(255, 236, 190))


## ---------------------------------------------------------------- 墙上的电话
## 被打中就响一阵（遭遇战没在打的时候）。PAYPHONE 那部连着打三下吐一个零件，只吐一次
class Phone extends Node2D:
	var index := 0
	var life: Node
	var _cool := 0.0
	var _knocks := 0
	var _paid := false

	func _ready() -> void:
		LifeHit.area(self, Vector2(12, 16), Vector2(0, -6))

	func _process(delta: float) -> void:
		_cool -= delta

	func knock(_dir: Vector2) -> void:
		if _cool > 0.0 or not life.phone_free(index):
			return
		_cool = 0.9
		var ring := RingFx.new()
		ring.position = position
		get_parent().get_parent().add_child(ring)
		if index == PAYPHONE and not _paid:
			_knocks += 1
			if _knocks >= 3:
				_paid = true
				Game.sfx("ding", -6.0, 1.3)
				var item: Node2D = Pickup.new()
				item.set("kind", "part")
				item.position = Vector2(position.x + 8.0, PAYPHONE_FLOOR)
				get_parent().get_parent().add_child.call_deferred(item)


## 给能被子弹打中的东西加一个判定区（铆钉、光球都在第 16 层）
class LifeHit:
	static func area(owner_node: Node2D, size: Vector2, offset: Vector2) -> void:
		var a := Area2D.new()
		a.collision_layer = 0
		a.collision_mask = 16
		a.monitorable = false
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = size
		cs.shape = r
		cs.position = offset
		a.add_child(cs)
		owner_node.add_child(a)
		a.area_entered.connect(func(shot: Area2D):
			var v: Variant = shot.get("velocity")
			var dir: Vector2 = (v as Vector2).normalized() if v is Vector2 else Vector2.RIGHT
			owner_node.call("knock", dir))



## 电话响的样子沿用关卡里的 RingFx、零件沿用 Pickup（都在 level2.gd 里）
const RingFx := preload("res://scripts/levels/level2.gd").RingFx
const Pickup := preload("res://scripts/levels/level2.gd").Pickup


## ---------------------------------------------------------------- 银幕
## 先放几秒倒计时片头（就是墙上画的那张），然后胶片上那 11 格轮流放，每格几秒。
## 老电影的样子：整体亮度跳、偶尔一格整体暗、上下抖一像素、竖的划痕、灰点；切镜头时闪一下白
class Screen extends Node2D:
	const SHOW := 3.4
	var light: PointLight2D
	var _t := 0.0
	var _scene := -1
	var _until := 3.0
	var _flick := 0.0
	var _k := 1.0
	var _weave := 0
	var _scratch: Array = []
	var _dust: Array = []
	var _white := 0.0

	func _process(delta: float) -> void:
		var life: Node = get_parent()
		if not life.near_view(SCREEN.get_center(), SCREEN.size.x * 0.5):
			return
		_t += delta
		_white = maxf(0.0, _white - delta * 6.0)
		if _t >= _until:
			if _scene >= 0 and randf() < 0.25:
				_scene = -1                     # 偶尔回到片头
				_until = _t + 2.0
			else:
				_scene = randi() % 11 if _scene < 0 else (_scene + 1) % 11
				_until = _t + SHOW
			_white = 1.0
		_flick -= delta
		if _flick <= 0.0:
			_flick = randf_range(0.05, 0.11)
			_k = 1.0 - randf() * 0.12
			if randf() < 0.05:
				_k = 0.7
			_weave = 1 if randf() < 0.1 else 0
			_scratch.clear()
			for i in (randi() % 3):
				_scratch.append([randi() % int(FRAME.x * FRAME_SCALE), randi() % 40, 30 + randi() % 150])
			_dust.clear()
			for i in (randi() % 5):
				_dust.append(Vector2(randi() % int(FRAME.x * FRAME_SCALE), randi() % int(FRAME.y * FRAME_SCALE)))
			if light:
				light.energy = 0.8 * _k + 0.3 * _white
		queue_redraw()

	func _draw() -> void:
		var size := FRAME * FRAME_SCALE
		var o := (SCREEN.position + (SCREEN.size - size) * 0.5).round() + Vector2(0, _weave)
		if _scene >= 0:
			var src := Rect2(92 * _scene + 2, 13, FRAME.x, FRAME.y)
			var col := Color(_k, _k * 0.97, _k * 0.9, 0.85)
			draw_texture_rect_region(FILM_TEX, Rect2(o, size), src, col)
		var line_col := Color(1.0, 0.95, 0.85, 0.35) if _scene >= 0 else Color(0.1, 0.08, 0.06, 0.3)
		for s in _scratch:
			draw_rect(Rect2(o.x + s[0], o.y + s[1], 1, s[2]), line_col)
		for d in _dust:
			draw_rect(Rect2(o + d, Vector2(2, 1 + randi() % 2)), Color(0.08, 0.06, 0.05, 0.5))
		if _white > 0.0:
			draw_rect(Rect2(o, size), Color(1.0, 0.95, 0.85, 0.35 * _white))


## ---------------------------------------------------------------- 胶片上掠过的影子
## 镜头在天桥上时，每隔 7~15 秒一只大飞蛾的影子从胶片上斜着飞过去（翅膀一扇一扇），像飞蛾在扑放映机的灯。
## 半透明的深褐色，盖在胶片上、人和怪下面，不挡东西
class FilmShadow extends Node2D:
	const COL := Color(0.08, 0.05, 0.04, 0.45)
	var life: Node
	var _wait := 4.0
	var _on := false
	var _pos := Vector2.ZERO
	var _vel := Vector2.ZERO
	var _t := 0.0
	var _size := 1.0

	func _ready() -> void:
		z_index = 3     # 胶片在 -14，这里是 -16 + 3 = -13

	func _process(delta: float) -> void:
		var view: Rect2 = life.get("_view")
		if not _on:
			if view.get_center().x < D.A_X1 or view.get_center().x > D.B_X0:
				return
			_wait -= delta
			if _wait > 0.0:
				return
			_on = true
			_t = 0.0
			_size = randf_range(0.8, 1.3)
			var right := randf() < 0.5
			_pos = Vector2(view.end.x + 40.0 if right else view.position.x - 40.0,
					randf_range(D.FILM_TOP + 10.0, D.FILM_BOT - 30.0))
			_vel = Vector2(-1.0 if right else 1.0, randf_range(-0.15, 0.15)) * randf_range(150.0, 220.0)
		_t += delta
		_pos += _vel * delta + Vector2(0, sin(_t * 9.0) * 0.6)
		if _t > 0.3 and not view.grow(60.0).has_point(_pos):
			_on = false
			_wait = randf_range(7.0, 15.0)
		queue_redraw()

	func _draw() -> void:
		if not _on:
			return
		# 只画在胶片那一条上下（影子投在胶片上）
		var top := float(D.FILM_TOP)
		var bot := float(D.FILM_BOT)
		var c := _pos.round()
		# 扇翅膀：从正面看翅膀宽度一缩一张
		var f := 0.35 + 0.65 * absf(sin(_t * 18.0))
		var w := 24.0 * _size
		var h := 20.0 * _size
		# 每一行算两片翅膀（前翅大、偏上；后翅小、偏下）在右边占的那一段，左边对称
		var wings := [[w * 0.5 * f, -h * 0.18, w * 0.52 * f, h * 0.42], [w * 0.32 * f, h * 0.26, w * 0.34 * f, h * 0.3]]
		for dy in range(-int(h * 0.6) - 1, int(h * 0.6) + 2):
			var y := c.y + dy
			if y < top or y >= bot:
				continue
			var x0 := INF
			var x1 := -INF
			for e in wings:
				var k: float = (dy - e[1]) / e[3]
				if absf(k) < 1.0:
					var half: float = e[2] * sqrt(1.0 - k * k)
					x0 = minf(x0, e[0] - half)
					x1 = maxf(x1, e[0] + half)
			x0 = maxf(roundf(x0), 2.0)
			x1 = roundf(x1)
			if x1 > x0:
				draw_rect(Rect2(c.x + x0, y, x1 - x0, 1), COL)
				draw_rect(Rect2(c.x - x1 + 1, y, x1 - x0, 1), COL)
			# 身子：中间 3 格宽，上下比翅膀短一点
			if absf(dy) <= h * 0.42:
				draw_rect(Rect2(c.x - 1, y, 3, 1), COL)
		# 两根触角
		for side in [-1.0, 1.0]:
			for i in range(1, 6):
				var p := c + Vector2(side * i, -h * 0.42 - i)
				if p.y >= top and p.y < bot:
					draw_rect(Rect2(p, Vector2.ONE), COL)
