class_name TeslaArc
extends Node2D
## 特斯拉电弧钳 TESLA TONGS 的一道电弧（设计稿：夜间打磨/新武器设计.md 第 4 节）。
## 按住武器键每 INTERVAL 秒放一道，不用瞄准：自动劈钳口 RANGE 内最近的怪（要有视线，隔墙劈不到），
## 再从它跳到 JUMP 内最近的下一只，最多跳 JUMPS 次（打 4 只），每跳一次伤害降一档（DAMAGE）。
## - 小怪被电麻 STUN 秒：原地停住、抖、发蓝；连着电就一直麻。精英和 Boss 不麻，只抖一下。
## - 保险丝甲虫被电到当场炸（它自己的连锁爆炸照旧）。
## - Boss 块头大、金属多："导电"，第一下按 BOSS_DAMAGE 算；Boss 场里的小东西（总机的插头、老电视的分身）能当跳板。
## - 打击感：钳口一亮、人身上亮一下；电弧是锯齿像素线（隔约 3 帧重折一次），淡蓝白芯、淡蓝边，
##   每跳一段晚 HOP_DELAY 秒出现（看得出"跳过去"）；被电的怪蓝白一闪、冒蓝火星；"噼"一跳高一档（上行音阶）；
##   第一只顿 0.02 秒，后面不顿；电死的怪冒一股黑烟；连杀时外圈亮一点。（10-18 作者"太晃眼睛"：去掉全屏蓝闪、整体暗一档）
##
## 用法（player.gd，游戏设计会话挂）：
##   if TeslaArc.target_from(self, muzzle) == null: 只在钳口冒点小火花（TeslaArc.fizzle），不算一道
##   var arc := TeslaArc.new(); arc.setup(self, muzzle, strip_color)
##   Mutations.on_attack(self, arc)        # 怒火乘 damage_mult；磁带回声用 TeslaArc.echo(...)
##   get_parent().add_child(arc)           # 进场景树的那一帧找链、开始结算
## 伤害在 add_child 之后按跳的先后结算，所以变异要在 add_child 之前算（和蒸汽锤一样）。

const INTERVAL := 0.3
const RANGE := 120.0
const RANGE_BOSS := 150.0
const JUMP := 60.0
const JUMPS := 3
const DAMAGE := [32.0, 26.0, 20.0, 16.0]
const BOSS_DAMAGE := 40.0   # 设计稿 45；实测 Boss1/2/3 37/42/55 秒偏快，压到 40
const STUN := 0.15
## 每跳一段晚多久出现；整道电弧在最后一跳以后再亮多久
const HOP_DELAY := 0.035
const GLOW := 0.1
## 10-18 作者"特斯拉有点太晃眼睛"：芯子从纯白降一档、外圈更淡、去掉全屏蓝闪、电弧隔几帧才重折一次
const CORE := Color(0.82, 0.9, 1.0, 0.9)
const EDGE := Color(0.55, 0.8, 1.0)
const SPARK := Color(0.6, 0.85, 1.0)
const SMOKE := Color(0.18, 0.17, 0.2)
## 连杀：上一只电死以后多久之内再电死一只，电弧就粗一格
const STREAK_TIME := 1.5

static var _last_kill := -10.0

var shooter: Node2D
var from := Vector2.ZERO
var color := EDGE
## 变异"怒火"会乘这个（Mutations._damage_mul 先找 damage_mult）
var damage_mult := 1.0
## 打了几只（_ready 里找好链以后才有）
var hits := 0

var _targets: Array[Node2D] = []
var _points: Array[Vector2] = []
var _t := 0.0
var _done_hits := 0
var _thick := 1
var _streak := false
## 电弧折线隔多少物理帧重折一次（120 帧/秒：6 帧 ≈ 0.05 秒，屏幕上 3 帧左右）
const REJAG_FRAMES := 6
var _seed := 0


func setup(p: Node2D, muzzle: Vector2, col := EDGE) -> void:
	shooter = p
	from = muzzle
	color = col.lerp(EDGE, 0.6)


## 钳口 RANGE 内最近、看得见的怪；没有就返回 null（player 用它决定放不放、朝哪边）
static func target_from(p: Node2D, muzzle: Vector2) -> Node2D:
	return _nearest(p, muzzle, RANGE, [], true)


## 没有目标时按着：钳口之间冒两三颗小电火花，轻轻"滋"一声
static func fizzle(parent: Node, muzzle: Vector2) -> void:
	Game.sparks(parent, muzzle, SPARK, 2, 40.0)
	Game.sfx("buzz", -22.0, 2.2, 0.2)


## 磁带回声：同一条链 0.3 秒后再电一次（伤害乘 mult），mutations.gd 调
static func echo(p: Node2D, muzzle_offset: Vector2, mult: float, col: Color) -> TeslaArc:
	if not is_instance_valid(p):
		return null
	var arc := TeslaArc.new()
	arc.setup(p, p.global_position + muzzle_offset, col)
	arc.damage_mult = mult
	arc.set_meta("mutation_copy", true)
	p.get_parent().add_child(arc)
	return arc


func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	z_index = 9
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = m
	_seed = randi()
	# 连杀：不再加粗一格（太晃），外圈亮一点就够
	_thick = 1
	_streak = _now() - _last_kill < STREAK_TIME
	_find_chain()
	hits = _targets.size()
	if hits == 0:
		fizzle(get_parent(), from)
		queue_free()
		return
	_points.append(from)
	for t in _targets:
		_points.append(_aim(t))
	# 出手：钳口炸亮、"啪"＋"滋——"、画面发蓝一闪、人身上亮一下
	Game.sfx("crack", -9.0, 1.7, 0.1)
	Game.sfx("buzz", -10.0, 1.5, 0.1)
	Game.sparks(get_parent(), from, SPARK, 3, 60.0, (_points[1] - from).normalized())
	if is_instance_valid(shooter) and "_release_flash" in shooter:
		shooter.set("_release_flash", maxf(float(shooter.get("_release_flash")), 0.25))
	var l := PointLight2D.new()
	l.texture = Game.light_texture()
	l.color = Color(0.6, 0.8, 1.0)
	l.energy = 0.7
	l.texture_scale = 0.7
	l.position = from
	l.name = "L"
	add_child(l)
	_hit(0)


func _physics_process(delta: float) -> void:
	_t += delta
	# 每一跳晚 HOP_DELAY 秒结算
	while _done_hits < _targets.size() and _t >= _done_hits * HOP_DELAY:
		_hit(_done_hits)
	# 电弧跟着还活着的目标走
	for i in _targets.size():
		if is_instance_valid(_targets[i]) and not _targets[i].get("dead"):
			_points[i + 1] = _aim(_targets[i])
	var light := get_node_or_null("L") as PointLight2D
	if light:
		light.energy = 0.7 * maxf(1.0 - _t / (GLOW + HOP_DELAY * hits), 0.0)
	if _t > GLOW + HOP_DELAY * hits:
		queue_free()
		return
	queue_redraw()


## 找链：第一只从钳口找，之后每只从上一只身上找；同一只不打两次
func _find_chain() -> void:
	var at := from
	var used: Array = []
	for i in JUMPS + 1:
		var r := RANGE if i == 0 else JUMP
		var t := _nearest(shooter, at, r, used, i == 0)
		if t == null:
			break
		_targets.append(t)
		used.append(t)
		at = _aim(t)


static func _nearest(p: Node2D, at: Vector2, r: float, used: Array, first: bool) -> Node2D:
	if p == null or not p.is_inside_tree():
		return null
	var space := p.get_world_2d().direct_space_state
	var best: Node2D = null
	var bd := INF
	for e in p.get_tree().get_nodes_in_group("enemy"):
		var en := e as Node2D
		if en == null or used.has(en) or en.get("dead") == true:
			continue
		if en.has_method("is_targetable") and not en.call("is_targetable"):
			continue
		var pt := _aim(en)
		var d := at.distance_to(pt)
		var lim := RANGE_BOSS if (first and en.has_method("start_fight")) else r
		if d > lim or d >= bd:
			continue
		if not _clear(space, at, pt):
			continue
		best = en
		bd = d
	return best


## 视线：单向平台不挡（和子弹、自动瞄准一样）
static func _clear(space: PhysicsDirectSpaceState2D, a: Vector2, b: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(a, b, 1)
	for _i in 4:
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return true
		if not Player.is_one_way_body(hit["collider"]):
			return false
		q.exclude = q.exclude + [hit["rid"]]
	return false


static func _aim(n: Node2D) -> Vector2:
	return n.call("aim_point") if n.has_method("aim_point") else n.global_position


func _hit(i: int) -> void:
	_done_hits = i + 1
	var t := _targets[i]
	if not is_instance_valid(t) or t.get("dead") == true:
		return
	var pos := _aim(t)
	var prev := _points[i]
	var dir := (pos - prev).normalized()
	var boss := t.has_method("start_fight")
	var elite := t is EliteBase
	var dmg: float = (BOSS_DAMAGE if boss and i == 0 else DAMAGE[mini(i, DAMAGE.size() - 1)]) * damage_mult
	# 保险丝甲虫：一电就炸（它自己的熔丝、连锁照旧）
	if t is FuseBeetle and t.get("_burning") != true:
		dmg = maxf(dmg, float(t.get("hp")) + 1.0)
	t.call("hurt", dmg, dir, false)
	# "噼"：一跳高一档，上行音阶（1、2、3、5 度）
	var steps := [1.0, 1.122, 1.26, 1.498]
	Game.sfx("rivet_hit", -8.0, 1.6 * steps[mini(i, 3)], 0.02)
	Game.sparks(get_parent(), pos, SPARK, 3, 70.0, dir)
	if i == 0:
		Game.hitstop(0.02)
	var killed := HitFx.after_hit(t, pos, dir, 0.25)
	if killed or t.get("dead") == true:
		_last_kill = _now()
		# 电死：冒一小股黑烟
		Game.sparks(get_parent(), pos, SMOKE, 5, 30.0, Vector2.UP)
		return
	# 麻：小怪原地停住、抖、发蓝；精英、Boss 只抖一下
	if is_instance_valid(t):
		TeslaStun.apply(t, 0.0 if (boss or elite) else STUN)


func _now() -> float:
	return Engine.get_physics_frames() / float(Engine.physics_ticks_per_second)


## 锯齿像素电弧：每帧重折一次（同一帧里固定，换帧再随机），白芯、外面一圈淡蓝
func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + int(Engine.get_physics_frames() / REJAG_FRAMES)
	var shown := mini(_done_hits, _targets.size())
	for i in shown:
		var a := _points[i]
		var b := _points[i + 1]
		var pts := _jag(a, b, rng)
		var fade := 1.0 if _t < GLOW else 0.6
		for k in pts.size() - 1:
			_line(pts[k], pts[k + 1], Color(color, (0.42 if _streak else 0.3) * fade), 1, true)
		for k in pts.size() - 1:
			_line(pts[k], pts[k + 1], Color(CORE, fade), _thick, false)
		# 每个落点一小团亮
		draw_rect(Rect2(b.round(), Vector2.ONE), Color(CORE, 0.8 * fade))
	# 钳口炸亮
	if _t < 0.04:
		draw_rect(Rect2(from.round() - Vector2(1, 1), Vector2(3, 3)), Color(color, 0.45))
		draw_rect(Rect2(from.round(), Vector2.ONE), CORE)


## 把 a→b 折成一串点：每 6 像素一折，横着偏 ±3（两头不偏）
func _jag(a: Vector2, b: Vector2, rng: RandomNumberGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = [a]
	var len := a.distance_to(b)
	var n := maxi(int(len / 6.0), 1)
	var nrm := (b - a).normalized().orthogonal()
	for k in range(1, n):
		var p := a.lerp(b, float(k) / n) + nrm * rng.randf_range(-3.0, 3.0)
		out.append(p)
	out.append(b)
	return out


## 一格一格画直线（Bresenham），不用 draw_line（canvas_items 缩放下会变平滑）。halo = 在上下左右各偏一格画外圈
func _line(a: Vector2, b: Vector2, col: Color, thick: int, halo: bool) -> void:
	var x0 := int(roundf(a.x))
	var y0 := int(roundf(a.y))
	var x1 := int(roundf(b.x))
	var y1 := int(roundf(b.y))
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	var guard := 0
	while guard < 400:
		guard += 1
		if halo:
			for o in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				draw_rect(Rect2(Vector2(x0, y0) + o, Vector2.ONE), col)
		else:
			draw_rect(Rect2(Vector2(x0, y0), Vector2(thick, thick)), col)
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


## 被电麻：挂在怪身上的小节点。麻着的时候把怪按在原地（只管左右，掉落照常），贴图左右抖、发蓝。
## 再被电一下就续上。stun = 0 时只抖 0.08 秒、发蓝一闪（精英、Boss）。
class TeslaStun extends Node:
	const TINT := Color(0.8, 0.9, 1.25)
	var stun := 0.0
	var shake := 0.0
	var _x := 0.0
	var _hold := false

	static func apply(target: Node2D, t: float) -> void:
		var s: TeslaStun = null
		for c in target.get_children():
			if c is TeslaStun:
				s = c
		if s == null:
			s = TeslaStun.new()
			s.name = "TeslaStun"
			target.add_child(s)
		s.shake = maxf(s.shake, 0.08)
		if t > 0.0:
			if s.stun <= 0.0:
				s._x = target.global_position.x
			s.stun = maxf(s.stun, t)

	func _physics_process(delta: float) -> void:
		var e := get_parent() as Node2D
		if e == null or e.get("dead") == true:
			queue_free()
			return
		# Boss 没有 _sprite（get 回来是 null，不能直接 as），就只停不抖
		var sv = e.get("_sprite")
		var spr: Sprite2D = sv if sv is Sprite2D else null
		if stun > 0.0:
			stun -= delta
			e.global_position.x = _x
			if "velocity" in e:
				var v: Vector2 = e.get("velocity")
				e.set("velocity", Vector2(0.0, v.y))
		shake -= delta
		if spr:
			var on := stun > 0.0 or shake > 0.0
			if on:
				spr.position.x += 1.0 if Engine.get_physics_frames() % 2 == 0 else -1.0
			spr.self_modulate = TINT if on and Engine.get_physics_frames() % 12 < 6 else Color.WHITE
		if stun <= 0.0 and shake <= 0.0:
			if spr:
				spr.self_modulate = Color.WHITE
			queue_free()
