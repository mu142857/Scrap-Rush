extends Node2D
## 唱片回旋镖扔出去的一张黑胶唱片（record.gd 扔，总机台/留声机会话 10-18 写）。
## 一趟：往前飞 OUT_DIST 像素、越飞越慢 → 停一下 → 掉头加速飞回扔它的人手里（回程穿墙，保证回得来）。
## 去程碰到墙或天花板会弹一次（像台球），第二次碰墙就直接往回飞；碰到地面贴着地滑（矮怪也割得到）。
## 割：去程、回程各对每只怪割一下（穿透，不停）；Boss 和精英块头大，唱片压在身上时每 RECUT 秒再割一下，每趟最多 BIG_CUTS 下。
## 不顿帧（唱片一直在飞，顿帧会卡），被割的怪往唱片飞的方向推一点、抖一下，切线方向迸一串火星。
## ghost = 磁带回声扔的幽灵唱片：青紫色，不回来，去程飞完就散。

const OUT_DIST := 130.0
const OUT_SPEED := 560.0
## 掉头后加速度、回程最快多快
const BACK_ACCEL := 1100.0
const BACK_SPEED := 470.0
const BACK_TURN := 9.0
## 去程到头停多久再往回飞
const HANG := 0.06
## 离扔它的人多近算接住
const CATCH_R := 10.0
## 离手这么近就不再带惯性，直接飞进手里
const SNAP_R := 40.0
const RECUT := 0.25
const BIG_CUTS := 1
## 去程朝扔出去时瞄的那只怪拐弯（像回旋镖划弧线）：每秒最多转多少弧度；离目标多近就不再拐
const CURVE := 3.2
## 同一张唱片对同一只怪，两刀之间至少隔多久（不分去回）。贴墙扔时一趟很短，没有这条会在大块头身上割得太勤
## （10-18 测：没有它时老电视 39 秒就死，比别的武器快一半）
const SAME_GAP := 0.2
## 回程飞太久（人跑远了、掉下去了）就散掉
const MAX_LIFE := 4.0
## 唱片的颜色：黑胶、纹路、红标签（照商店图标 tools/draw_shop.py 的 PIXEL_ICONS["record"]）
const VINYL := Color8(22, 20, 24)
const GROOVE := Color8(70, 66, 74)
const SHINE := Color8(170, 165, 180)
const LABEL_DARK := Color8(140, 42, 30)
const LABEL := Color8(255, 71, 48)
const GHOST := Color(0.55, 0.85, 1.0)

var damage := 32.0
var thrower: Node2D
## 扔它的那份 handler（接住时通知它）
var handler: RefCounted
## 扔出去时瞄的那只怪（去程朝它拐弯）
var target: Node2D
var ghost := false
var tint := Color.WHITE

var _vel := Vector2.ZERO
var _speed0 := OUT_SPEED
var _dist0 := OUT_DIST
var _travel := 0.0
var _back := false
var _hang := -1.0
var _bounced := false
var _life := 0.0
var _spin := 0.0
var _whir_t := 0.0
## 这一趟（去 / 回）已经割过的怪：{怪: [割了几下, 下次能割的时间]}
var _cut := {}
## 这张唱片上次割每只怪的时间（不随去回清空）：{怪: 时间}
var _last_cut := {}
var _trail: Array[Vector2] = []
var _fade := -1.0
## 割的判定框（宽 10、高 9，比画出来的唱片大一圈，好打中）
var _hit_shape: RectangleShape2D


func setup(pos: Vector2, dir: Vector2, speed_mult: float, dmg: float, by: Node2D, h: RefCounted) -> void:
	global_position = pos
	_speed0 = OUT_SPEED * speed_mult
	# 快的那张飞得也远一点（扔出去的速度 +20%，距离 +10%）
	_dist0 = OUT_DIST * (1.0 + 0.5 * (speed_mult - 1.0))
	_vel = dir.normalized() * _speed0
	damage = dmg
	thrower = by
	handler = h


func _ready() -> void:
	_hit_shape = RectangleShape2D.new()
	_hit_shape.size = Vector2(10, 9)
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
	z_index = 7


func is_back() -> bool:
	return _back


func _physics_process(delta: float) -> void:
	_life += delta
	if _fade >= 0.0:
		_fade += delta
		if _fade > 0.2:
			queue_free()
		queue_redraw()
		return
	if _life > MAX_LIFE or (not ghost and not is_instance_valid(thrower)):
		_vanish()
		return
	var speed := _vel.length()
	_spin += delta * (10.0 + speed * 0.06)
	if _hang >= 0.0:
		# 去程到头：停一下（还在转），然后往回飞
		_hang -= delta
		if _hang < 0.0:
			if ghost:
				_vanish()
				return
			_back = true
			_cut.clear()
			_vel = Vector2.ZERO
	elif not _back:
		_steer(delta)
		_fly_out(delta)
	else:
		if _fly_back(delta):
			return
	_trail.push_front(global_position)
	if _trail.size() > 4:
		_trail.pop_back()
	_cut_overlaps()
	# 转盘的"呜"：越快音越高，减速时往下掉、回来加速时往上升
	_whir_t -= delta
	if _whir_t <= 0.0 and not ghost:
		_whir_t = 0.13
		Game.sfx("record_whir", -20.0, 0.7 + _vel.length() / 600.0)
	queue_redraw()


## 去程朝目标拐弯：还没割到它、它还活着时，速度方向往它那边转一点（速度大小不变）
func _steer(delta: float) -> void:
	if not is_instance_valid(target) or target.get("dead") == true or _cut.has(target):
		return
	var aim: Vector2 = target.call("aim_point") if target.has_method("aim_point") else target.global_position + Vector2(0, -12)
	var to := aim - global_position
	if to.length() < 6.0:
		return
	var a := _vel.angle_to(to)
	_vel = _vel.rotated(clampf(a, -CURVE * delta, CURVE * delta))


## 去程：匀减速，飞满 _dist0 就停。碰到墙 / 天花板弹一次（反射），第二次就直接掉头；碰到地面贴着地滑
func _fly_out(delta: float) -> void:
	var decel := _speed0 * _speed0 / (2.0 * _dist0)
	var speed := maxf(_vel.length() - decel * delta, 0.0)
	_vel = _vel.normalized() * speed
	var step := _vel * delta
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + step + step.normalized() * 4.0, 1)
	var hit := space.intersect_ray(q)
	if not hit.is_empty() and not _one_way(hit.get("collider")):
		var n: Vector2 = hit["normal"]
		if n.y < -0.7:
			# 碰到地面：贴着地面滑（朝矮怪斜着扔下去也割得到），不算弹
			_vel.y = 0.0
			if absf(_vel.x) < 1.0:
				_hang = HANG
				return
			global_position = Vector2(global_position.x + _vel.x * delta, (hit["position"] as Vector2).y - 3.0)
			_travel += absf(_vel.x * delta)
			if _travel >= _dist0:
				_hang = HANG
			if randf() < 0.5:
				Game.sparks(get_parent(), hit["position"], Color(1.0, 0.85, 0.6), 1, 50.0, Vector2(-signf(_vel.x), -1))
			return
		Game.sparks(get_parent(), hit["position"], Color(1.0, 0.85, 0.6), 4, 70.0, n)
		Game.sfx("record_catch", -14.0, 0.7)
		if _bounced:
			_hang = 0.0
			return
		_bounced = true
		_vel = _vel.bounce(n)
		global_position = (hit["position"] as Vector2) + n * 3.0
		return
	global_position += step
	_travel += step.length()
	if speed <= 1.0 or _travel >= _dist0:
		_hang = HANG


## 回程：朝扔它的人加速飞（追着人走），穿墙。接住就没了。返回 true 表示已经没了
func _fly_back(delta: float) -> bool:
	var home := thrower.global_position + Vector2(0, -10)
	var to := home - global_position
	if to.length() < CATCH_R:
		if handler and handler.has_method("caught"):
			handler.call("caught", self)
		queue_free()
		return true
	if to.length() < SNAP_R:
		# 快到手边：直接朝手飞，不再带惯性（不然人一跳，唱片会绕着人打转、半天接不住）
		_vel = to.normalized() * maxf(_vel.length(), 320.0)
		global_position += _vel * delta if (_vel * delta).length() < to.length() else to
		return false
	# 速度慢慢加上去；方向转得很快（每秒最多 BACK_TURN 弧度）——人跑开了唱片也是追着人回来，不会绕一个大圈
	var speed := move_toward(_vel.length(), BACK_SPEED, BACK_ACCEL * delta)
	var dir := _vel.normalized() if _vel.length() > 1.0 else to.normalized()
	dir = dir.rotated(clampf(dir.angle_to(to), -BACK_TURN * delta, BACK_TURN * delta))
	_vel = dir * speed
	global_position += _vel * delta
	return false


## 割压在唱片下面的怪：每趟每只一下；大块头每 RECUT 秒一下、最多 BIG_CUTS 下
func _cut_overlaps() -> void:
	if _fade >= 0.0:
		return
	# 不用 get_overlapping_bodies：Boss 是 StaticBody2D，唱片每帧直接挪位置时重叠列表一直是空的（10-18 测出来的）。
	# 和蒸汽锤一样，每帧拿形状直接问物理
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = _hit_shape
	q.transform = Transform2D(0.0, global_position)
	q.collision_mask = 4
	q.collide_with_areas = false
	var bodies: Array = []
	for r in get_world_2d().direct_space_state.intersect_shape(q, 16):
		var c: Object = r["collider"]
		if c != null and not bodies.has(c):
			bodies.append(c)
	for body in bodies:
		if not (body.is_in_group("enemy") and body.has_method("hurt")):
			continue
		if body.has_method("is_targetable") and not body.call("is_targetable"):
			continue
		var big: bool = body.has_method("start_fight") or body.has_method("in_intro") or body.get("big") == true
		var rec: Array = _cut.get(body, [0, 0.0])
		if rec[0] >= (BIG_CUTS if big else 1) or _life < rec[1]:
			continue
		if _life < float(_last_cut.get(body, -1.0)) + SAME_GAP:
			continue
		_last_cut[body] = _life
		_cut[body] = [rec[0] + 1, _life + RECUT]
		_cut_one(body as Node2D)


func _cut_one(body: Node2D) -> void:
	var dir := _vel.normalized() if _vel.length() > 1.0 else Vector2.RIGHT
	body.call("hurt", damage, dir, false)
	# 被割的怪往唱片飞的方向推一点（小怪），切线方向迸一串火星
	if body is CharacterBody2D and not body.has_method("in_intro") and not body.has_method("start_fight") and body.get("big") != true:
		(body as CharacterBody2D).velocity += Vector2(dir.x * 50.0, -20.0)
	var col := GHOST if ghost else Color(1.0, 0.8, 0.45)
	Game.sparks(get_parent(), global_position, col, 5, 110.0, dir)
	Game.sfx("record_cut", -7.0 if not ghost else -12.0, 1.0 + randf_range(-0.08, 0.08))
	var killed := HitFx.after_hit(body, global_position, dir, 0.3)
	if killed and handler and handler.has_method("on_kill"):
		handler.call("on_kill", self)


## 单向平台挡不住唱片（和铆钉、光球一样）。不写 Player 类名（见 weapon_handler.gd 的约定）
static func _one_way(body: Object) -> bool:
	var b := body as CollisionObject2D
	if b == null or b.get_shape_owners().is_empty():
		return false
	for owner_id in b.get_shape_owners():
		var o := b.shape_owner_get_owner(owner_id)
		if not ((o is CollisionShape2D or o is CollisionPolygon2D) and o.get("one_way_collision")):
			return false
	return true


## 散掉（回声唱片飞完、人没了）：淡一下就没了，碎几颗火星
func _vanish() -> void:
	if _fade >= 0.0:
		return
	_fade = 0.0
	Game.sparks(get_parent(), global_position, GHOST if ghost else Color(0.7, 0.7, 0.75), 4, 50.0)
	if not ghost and handler and handler.has_method("caught"):
		handler.call("caught", self, true)


## 连杀时唱片亮一下（record.gd 调）
var _glint := 0.0
func glint() -> void:
	_glint = 1.0


func _process(delta: float) -> void:
	_glint = maxf(_glint - delta * 4.0, 0.0)


## 一张斜着看的唱片：11×4 的扁椭圆（暗处也要看得见：一圈浅灰的边、一道跟着转的反光、中间亮红标签），
## 身后拖两道淡淡的旋转残影（10-18 实拍发现原来 7×3 的黑胶在暗房间里几乎看不见，放大一圈）
const SHAPE := [[-3, -2, 7], [-5, -1, 11], [-5, 0, 11], [-3, 1, 7]]


func _draw() -> void:
	draw_set_transform(global_position.round() - global_position)
	var a := 1.0 if _fade < 0.0 else clampf(1.0 - _fade / 0.2, 0.0, 1.0)
	# 残影：前几帧的位置，越往后越淡（暖色，看得出转着飞）
	for i in range(1, _trail.size()):
		var q := (_trail[i] - global_position).round()
		var ca := (0.34 - i * 0.08) * a
		if ca <= 0.0:
			continue
		var c := Color(GHOST, ca) if ghost else Color(1.0, 0.78, 0.55, ca)
		draw_rect(Rect2(q + Vector2(-4, -1), Vector2(9, 2)), c)
	if ghost:
		for r in SHAPE:
			draw_rect(Rect2(r[0], r[1], r[2], 1), Color(GHOST, 0.6 * a))
		draw_rect(Rect2(-1, -1, 3, 2), Color(1, 1, 1, 0.7 * a))
		return
	# 浅灰的外圈（先画大一圈当边），再画黑胶
	var rim := Color(SHINE, 0.75 * a)
	draw_rect(Rect2(-4, -3, 9, 1), rim)
	draw_rect(Rect2(-6, -2, 13, 4), rim)
	draw_rect(Rect2(-4, 2, 9, 1), rim)
	for r in SHAPE:
		draw_rect(Rect2(r[0], r[1], r[2], 1), Color(VINYL, a))
	# 一圈纹路
	draw_rect(Rect2(-4, -1, 1, 2), Color(GROOVE, a))
	draw_rect(Rect2(4, -1, 1, 2), Color(GROOVE, a))
	# 反光：一道亮条从左到右扫过去（转盘在转），4 帧一圈
	var f := int(_spin) % 4
	var sx := -4 + f * 2
	draw_rect(Rect2(sx, -2 if f < 2 else 1, 2, 1), Color(1.0, 0.97, 0.9, (0.75 + 0.25 * _glint) * a))
	# 红标签：中间 3×2，亮的那一格跟着转
	var lab := [LABEL_DARK, LABEL_DARK, LABEL_DARK]
	lab[f % 3] = LABEL
	for i in 3:
		draw_rect(Rect2(-1 + i, -1, 1, 2), Color(lab[i] if tint == Color.WHITE else tint, a))
	draw_rect(Rect2(0, -1, 1, 1), Color(1.0, 0.9, 0.75, a))
	if _glint > 0.0:
		draw_rect(Rect2(-6, -2, 13, 4), Color(1.0, 0.95, 0.8, 0.45 * _glint * a))
