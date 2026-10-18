extends Node2D
## 显像管激光的光束（laser.gd 开火时建，跟着主角的枪口走）。第二版（作者："激光跟第一个武器闪光灯太像了"）：
## 不是"一下"，是按着就一直扫的电子束——瞬间到墙、无限穿透，每 TICK 秒结算一次（线上每只怪各吃一下 damage），
## 每帧按 TURN 度/秒的转速朝 want_dir 转过去（laser.gd 每帧把目标方向写进来），所以看得到光束扫过去。
## 第一次扫到一只怪：那只闪白、"噼"一声（一只比一只高）、加顿帧（第一只 0.03 秒，之后每只 +0.015，最多 0.09）；之后每下只冒火星。
## 光束经过的 Boss 子弹一路烧掉（fizzle，碎散）。
## 画法（显像管）：红、绿、蓝三根 1 像素线上下错开，中间一根白芯；沿着光束隔几格暗一格、每帧滚动（扫描线）；粗细每帧在 3、5 之间跳（嗡嗡的）。
## 收束（松手、到时间）：像关电视——光束从远端往枪口缩，变成 1 像素的线，最后剩一个亮点，0.12 秒。
## 打到墙的地方留一小块焦黑，2 秒淡掉。

const TICK := 0.075
const MAX_LIFE := 0.5
const END_TIME := 0.12
const SCORCH_LIFE := 2.0
const HALF_WIDTH := 4.0
## 光束追目标的转速（度/秒）：慢一点，才看得出"扫过去"
const TURN := 140.0
const RANGE := 260.0

## 每一下的伤害（怒火会乘它）
var damage := 26.0
var color := Color.WHITE
## laser.gd 每帧写进来的目标方向
var want_dir := Vector2.RIGHT
var _shooter: Node2D
## 跟着主角的枪口走（回声的副本不跟）
var _follow := true
var _from := Vector2.ZERO
var _dir := Vector2.RIGHT
var _len := RANGE
var _t := 0.0
var _tick_t := 0.0
var _ending := false
var _end_t := 0.0
var _hit_once := {}
var _n_first := 0
## 焦痕（墙上的点，和打上去的时间）
var _scorch: Array = []


func setup(shooter: Node2D, dir: Vector2, dmg: float, col: Color, follow := true) -> void:
	_shooter = shooter
	_dir = dir
	want_dir = dir
	damage = dmg
	color = col
	_follow = follow
	_from = shooter.call("muzzle", 7.0, -11.0)


## 从 from 往 dir 打一条射线，看光束能射多远（墙挡；单向平台挡不住）
static func wall_distance(node: Node2D, from: Vector2, dir: Vector2, max_len: float) -> float:
	var space := node.get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(from, from + dir * max_len, 1)
	for _i in 6:
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return max_len
		if not _one_way(hit["collider"]):
			return from.distance_to(hit["position"])
		q.exclude = q.exclude + [hit["rid"]]
	return max_len


## 这一道光束会不会打到 target：和真正结算时同一套判断（细长矩形问物理，或者瞄准点在光束上）。laser.gd 挑方向用
static func would_hit(node: Node2D, from: Vector2, dir: Vector2, length: float, target: Node2D) -> bool:
	if target.has_method("aim_point"):
		var rel: Vector2 = (target.call("aim_point") as Vector2) - from
		var along := rel.dot(dir)
		if along >= 0.0 and along <= length and absf(rel.cross(dir)) < 10.0:
			return true
	var shape := RectangleShape2D.new()
	shape.size = Vector2(length, HALF_WIDTH * 2.0)
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.transform = Transform2D(dir.angle(), from + dir * (length * 0.5))
	q.collision_mask = 4
	for r in node.get_world_2d().direct_space_state.intersect_shape(q, 32):
		if r["collider"] == target:
			return true
	return false


static func _one_way(body: Object) -> bool:
	var b := body as CollisionObject2D
	if b == null or b.get_shape_owners().is_empty():
		return false
	for owner_id in b.get_shape_owners():
		var o := b.shape_owner_get_owner(owner_id)
		if not ((o is CollisionShape2D or o is CollisionPolygon2D) and o.get("one_way_collision")):
			return false
	return true


func is_ending() -> bool:
	return _ending


## 收束（松手、到时间、主角挨打）
func stop() -> void:
	if _ending:
		return
	_ending = true
	_end_t = 0.0
	Game.sfx("tvoff", -10.0, 1.3)


func _ready() -> void:
	z_index = 11
	top_level = true
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
	var light := PointLight2D.new()
	light.texture = Game.light_texture()
	light.color = Color(0.6, 1.0, 0.85)
	light.energy = 1.8
	light.texture_scale = 2.6
	light.range_item_cull_mask = 1 | 2
	light.name = "L"
	add_child(light)
	_len = wall_distance(self, _from, _dir, RANGE)


func _process(delta: float) -> void:
	_t += delta
	if _follow and is_instance_valid(_shooter) and _shooter.is_inside_tree():
		_from = _shooter.call("muzzle", 7.0, -11.0)
	elif _follow:
		stop()
	var light := get_node("L") as PointLight2D
	if not _ending:
		# 朝 want_dir 转（转速有上限：看得到光束扫过去）。人转身（目标跑到另一边）就直接镜像过去，
		# 不然要绕 180° 转 1.6 秒，整道光束都扫在空处（站桩测试里 Boss 92 秒、150 秒打不死）
		if signf(want_dir.x) != 0.0 and signf(want_dir.x) != signf(_dir.x):
			_dir = Vector2(-_dir.x, _dir.y)
		var diff := wrapf(want_dir.angle() - _dir.angle(), -PI, PI)
		_dir = _dir.rotated(clampf(diff, -deg_to_rad(TURN) * delta, deg_to_rad(TURN) * delta))
		_len = wall_distance(self, _from, _dir, RANGE)
		_tick_t -= delta
		if _tick_t <= 0.0:
			_tick_t += TICK
			_tick()
		if _t > MAX_LIFE:
			stop()
		light.position = _from + _dir * (_len * 0.5)
		light.energy = 1.6 + 0.4 * randf()
	else:
		_end_t += delta
		light.energy = 1.8 * maxf(1.0 - _end_t / END_TIME, 0.0)
	var keep := false
	for s in _scorch:
		if _t - float(s[1]) < SCORCH_LIFE:
			keep = true
	if _ending and _end_t > END_TIME and not keep:
		queue_free()
		return
	queue_redraw()


## 结算一下：线上的怪各吃一下、烧掉线上的 Boss 子弹、墙上冒火星留焦痕
func _tick() -> void:
	var space := get_world_2d().direct_space_state
	var shape := RectangleShape2D.new()
	shape.size = Vector2(_len, HALF_WIDTH * 2.0)
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.transform = Transform2D(_dir.angle(), _from + _dir * (_len * 0.5))
	q.collision_mask = 4
	var seen := {}
	var bodies: Array = []
	for r in space.intersect_shape(q, 64):
		var body: Object = r["collider"]
		if body == null or seen.has(body) or not (body as Node).is_in_group("enemy") or not body.has_method("hurt"):
			continue
		seen[body] = true
		bodies.append(body)
	# 瞄准点在光束上的也算（Boss2 总机的拨号盘是瞄准点，碰撞形状没盖到那里）
	for e in get_tree().get_nodes_in_group("enemy"):
		if seen.has(e) or not e.has_method("hurt") or not e.has_method("aim_point"):
			continue
		if e.has_method("is_targetable") and not e.call("is_targetable"):
			continue
		var rel: Vector2 = (e.call("aim_point") as Vector2) - _from
		var along := rel.dot(_dir)
		if along >= 0.0 and along <= _len and absf(rel.cross(_dir)) < 10.0:
			seen[e] = true
			bodies.append(e)
	bodies.sort_custom(func(a, b): return _from.distance_squared_to((a as Node2D).global_position) < _from.distance_squared_to((b as Node2D).global_position))
	for body in bodies:
		if is_instance_valid(body):
			_hit(body)
	for bl in get_tree().get_nodes_in_group("boss_bullet"):
		var n := bl as Node2D
		if n == null or not n.has_method("fizzle"):
			continue
		var rel := n.global_position - _from
		var along := rel.dot(_dir)
		if along >= 0.0 and along <= _len and absf(rel.cross(_dir)) < HALF_WIDTH + 2.0:
			n.call("fizzle", _dir)
	if _len < RANGE - 1.0:
		var e := (_from + _dir * _len).round()
		Game.sparks(get_parent(), e, [Color(1.0, 0.3, 0.4), Color(0.4, 1.0, 0.5), Color(0.4, 0.6, 1.0)][randi() % 3], 3, 70.0, -_dir)
		_scorch.append([e, _t])
		if _scorch.size() > 12:
			_scorch.pop_front()
	Game.add_shake(0.6)


func _hit(body: Node) -> void:
	var at: Vector2 = body.call("aim_point") if body.has_method("aim_point") else (body as Node2D).global_position
	var on_line := _from + _dir * clampf((at - _from).dot(_dir), 0.0, _len)
	var first := not _hit_once.has(body)
	body.call("hurt", damage, _dir, first)
	Game.sparks(get_parent(), on_line, [Color(1.0, 0.3, 0.4), Color(0.4, 1.0, 0.5), Color(0.4, 0.6, 1.0)][randi() % 3], 3, 90.0, _dir)
	HitFx.after_hit(body, on_line, _dir, 0.6 if first else 0.2)
	if first:
		_hit_once[body] = true
		_n_first += 1
		Game.sfx("hit", -6.0, 0.9 + 0.1 * _n_first, 0.05)
		if Engine.time_scale > 0.0 or _n_first > 1:
			Game.hitstop(minf(0.03 + 0.015 * (_n_first - 1), 0.09))
	else:
		Game.sfx("rivet_hit", -16.0, 1.3, 0.2)


func _draw() -> void:
	# 焦痕：墙上一块焦黑，最后半秒一闪一闪
	for s in _scorch:
		var age := _t - float(s[1])
		if age >= SCORCH_LIFE or (age > SCORCH_LIFE - 0.5 and int(_t * 16.0) % 2 == 0):
			continue
		draw_rect(Rect2(s[0] - Vector2(1, 1), Vector2(3, 3)), Color(0.08, 0.06, 0.07, 0.85))
	var red := Color(1.0, 0.25, 0.35)
	var green := Color(0.35, 1.0, 0.5)
	var blue := Color(0.3, 0.55, 1.0)
	var core := Color.WHITE if color == Color.WHITE else color.lerp(Color.WHITE, 0.5)
	var normal := Vector2(-_dir.y, _dir.x)
	var length := _len
	var width := 2 if (Engine.get_process_frames() % 2 == 0) else 1
	if _ending:
		# 关电视：先往枪口缩、变成 1 像素线，最后一个亮点
		var k := clampf(_end_t / END_TIME, 0.0, 1.0)
		if k > 0.75:
			draw_rect(Rect2(_from.round() - Vector2.ONE, Vector2(3, 3)), Color.WHITE)
			return
		length = _len * (1.0 - k / 0.75)
		width = 0
	var roll := Engine.get_process_frames()
	for i in int(length):
		var c := (_from + _dir * i).round()
		var dim := 0.45 if (i + roll) % 5 == 0 else 1.0
		draw_rect(Rect2(c, Vector2.ONE), Color(core, dim))
		if width >= 1:
			draw_rect(Rect2((c + normal).round(), Vector2.ONE), Color(green, 0.9 * dim))
			draw_rect(Rect2((c - normal).round(), Vector2.ONE), Color(green, 0.9 * dim))
		var off := float(width + 1)
		draw_rect(Rect2((c + normal * off).round(), Vector2.ONE), Color(red, 0.85 * dim))
		draw_rect(Rect2((c - normal * off).round(), Vector2.ONE), Color(blue, 0.85 * dim))
