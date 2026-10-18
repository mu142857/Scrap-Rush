class_name Watchman
extends EliteBase
## 守夜巨人（第二关 E2 继电器机房的精英怪）：活的、砸地的大块头（作者 10-17："加一些不是机器的、有生命的，
## 还没有那种砸地的大块头精英"）。交换局里驼背的守夜人，约 62 像素高，披着厚毛皮长袍、背上驮一大捆电话线圈，
## 两只大拳头拖到地上，帽兜里一只红眼。
## 活的感觉：站着时一呼一吸（背一起一伏），隔一会儿从帽兜里呼出一团白气；每走一步地面一震、扬灰；
## 蓄力时浑身发抖。慢慢朝主角走。招式都先冒红色"!"，砸下去震屏、地面裂开：
## - 双拳砸地：双拳举过头顶、浑身发抖 0.75 秒 → 砸在身前：拳头那一块伤 16，地面裂开、碎石飞起，
##   两道冲击波贴着地面往两边推（每道高 10，伤 12，推 180 像素或者撞墙、到台子边为止），要跳过去。
##   砸完趴着喘 0.7 秒，是打它的窗口。
## - 跳砸：蹲下发抖 0.6 秒，主角脚下先亮红色落点（落点就是它会落的地方），然后跳过去砸：落点一圈伤 18，
##   两边各推出一道短冲击波（70 像素）。跳多高看天花板（不撞头），横着最远 140 像素。
## - 扫臂（近身）：主角贴到身前 46 像素以内，前臂抡到身后 0.45 秒，再横着扫过身前（伤 14）。
## 冲击波、裂缝、落点、白气都是代码画的（不吃压暗，暗处看得清要跳的东西）。
## 贴图 watchman.png（草图/精英怪/l2_watchman.py 导出，89×70，10 帧）：
## 0 站·吸，1 站·呼，2、3 走，4 双拳举过头顶，5 砸地（跳砸落地也用），6 蹲，7 空中，8 扫臂前摇，9 扫臂。

enum { WALK, SLAM_WARN, SLAM, LEAP_WARN, LEAP_AIR, LAND, SWEEP_WARN, SWEEP, RECOVER }

const WALK_SPEED := 18.0
const STOP_DIST := 40.0
const SEE_DIST := 280.0
const STEP_TIME := 0.32
const BREATH_TIME := 0.7
const PUFF_GAP := 2.3
## 帽兜嘴边（原图朝左，相对脚底中间），白气从这里呼出来
const MOUTH := Vector2(-22, -40)
## 招与招之间歇多久（照放映机：精英的出招间隔不乘 interval_mult）
const ATTACK_GAP := 0.9  # 10-18 作者：招和招之间停太久
# —— 双拳砸地 ——
const SLAM_WARN_TIME := 0.75
const SLAM_HOLD := 0.7
## 拳头落地的位置（朝左时，相对脚底中间）和那一块的判定
const FIST_X := -30.0
const SLAM_RECT := Rect2(-42, -14, 28, 14)
const SLAM_DAMAGE := 16.0
const WAVE_DAMAGE := 12.0
const WAVE_SPEED := 150.0
const WAVE_DIST := 180.0
# —— 跳砸 ——
const LEAP_WARN_TIME := 0.6
const LEAP_REACH := 140.0
const LEAP_GRAVITY := 500.0
const LEAP_MAX_RISE := 36.0
const LEAP_MAX_VX := 260.0
const LAND_HOLD := 0.6
const LAND_RECT := Rect2(-34, -20, 68, 20)
const LAND_DAMAGE := 18.0
const LAND_WAVE_DIST := 70.0
# —— 扫臂 ——
const SWEEP_RANGE := 46.0
const SWEEP_HEIGHT := 28.0
const SWEEP_WARN_TIME := 0.45
const SWEEP_TIME := 0.2
const SWEEP_RECT := Rect2(-46, -36, 40, 26)
const SWEEP_DAMAGE := 14.0
const SWEEP_COOLDOWN := 2.2

## _unstick 往下最多探多远（个子高，头顶卡进天花板时要往下挪得多）
const UNSTICK_REACH := 140.0

var _state := WALK
var _timer := 0.0
var _cool := 1.2
var _sweep_cd := 0.0
var _next_leap := false
var _step_frame := 2
var _step_t := 0.0
var _puff_t := 1.0
var _air_t := 0.0
var _vx := 0.0
var _marker: LeapMarker


func _setup() -> void:
	elite_name = "WATCHMAN"
	intro_title = "CURFEW"
	intro_frame = 4
	fill_alpha = 0.35
	death_time = 1.1
	death_frame = 5
	death_scrap = false
	# 活的大块头：倒下是一声很沉的闷响，溅出来的是毛皮和灰（10-18 放映机会话加，监督会话同意）
	death_sfx = "land"
	death_sfx_pitch = 0.45
	death_spark_colors = [Color8(110, 96, 80), Color8(150, 140, 120)]
	death_boom_sfx = "boom"
	death_boom_pitch = 0.4
	death_spark_colors_big = [Color8(150, 140, 120), Color8(110, 96, 80)]
	texture_path = "res://art/enemies/watchman.png"
	hframes = 10
	frame_size = Vector2i(89, 70)
	body_rect = Rect2(-25, -62, 50, 62)
	contact_rect = Rect2(-20, -56, 42, 56)
	led_pixel = Vector2i(20, 27)
	led_by_frame = {1: Vector2i(20, 28), 4: Vector2i(21, 27), 5: Vector2i(16, 32), 6: Vector2i(20, 33),
		8: Vector2i(21, 27), 9: Vector2i(18, 27)}
	max_hp = 2300.0  # 10-18 作者：血不够，三把武器 20～35 秒
	contact_damage = 12.0


func _after_ready() -> void:
	_unstick()


## 出生时卡在实心里就挪出来（照 chief_operator.gd，碰撞会话 10-18：旧写法只会一路往下挪，脚压进斜坡、
## 身子插进柱子时会穿过地板掉出地图）。先原地、往上一点（脚压进地面、斜坡），再左右挪（插进柱子、墙），
## 最后才往下（头顶卡进天花板），往下最多挪到原来脚底下那块地面
func _unstick() -> void:
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = _shape.shape
	q.collision_mask = 1
	q.exclude = [get_rid()]
	var space := get_world_2d().direct_space_state
	var floor_d := UNSTICK_REACH
	var ray := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -1), global_position + Vector2(0, UNSTICK_REACH + 2.0), 1)
	var hit := space.intersect_ray(ray)
	if not hit.is_empty():
		floor_d = (hit.position as Vector2).y - global_position.y
	var tries: Array[Vector2] = []
	for dy in [0.0, -1.0, -2.0, -3.0, -4.0, -6.0, -8.0]:
		tries.append(Vector2(0, dy))
	for dx in [2.0, 4.0, 6.0, 8.0, 12.0, 16.0]:
		for dy in [0.0, -2.0, -4.0]:
			tries.append(Vector2(dx, dy))
			tries.append(Vector2(-dx, dy))
	var d := 2.0
	while d <= floor_d:
		tries.append(Vector2(0, d))
		d += 2.0
	for t in tries:
		q.transform = Transform2D(0.0, global_position + t + _shape.position)
		if space.intersect_shape(q, 1).is_empty():
			global_position += t
			return
	# 都不行：留在原地，交给物理把它挤出来


func _tick(delta: float) -> void:
	_timer -= delta
	_sweep_cd -= delta
	_puff_t -= delta
	var p := nearest_player(SEE_DIST)
	match _state:
		WALK:
			_cool -= delta
			_walk(p, delta)
			if p and is_on_floor():
				var d := p.global_position - global_position
				if _sweep_cd <= 0.0 and d.x * dir >= 0.0 and absf(d.x) <= SWEEP_RANGE and absf(d.y) <= SWEEP_HEIGHT:
					_start(SWEEP_WARN, SWEEP_WARN_TIME)
					warn(SWEEP_WARN_TIME)
					Game.sfx("charge", -12.0, 0.6)
				elif _cool <= 0.0:
					# 远了跳过去，近了砸地；同一距离段里两招轮着来
					var leap := _next_leap if absf(d.x) <= 110.0 else true
					if leap:
						_start_leap(pick_focus(p))   # 双人时轮着砸一个人
					else:
						_start(SLAM_WARN, SLAM_WARN_TIME)
						warn(SLAM_WARN_TIME)
						Game.sfx("charge", -8.0, 0.5)
						Game.sfx("jet", -18.0, 0.45)
					_next_leap = not leap
		SLAM_WARN:
			_brake(delta)
			set_frame(4)
			if _timer <= 0.0:
				_slam()
		SLAM:
			_brake(delta)
			set_frame(5)
			if _timer <= 0.0:
				_finish(0.0)
		LEAP_WARN:
			_brake(delta)
			set_frame(6)
			if _timer <= 0.0:
				_launch()
		LEAP_AIR:
			_air_t += delta
			velocity.x = _vx
			set_frame(7)
			if _air_t > 0.08 and is_on_floor():
				_land()
		LAND:
			_brake(delta)
			set_frame(5)
			if _timer <= 0.0:
				_finish(0.0)
		SWEEP_WARN:
			_brake(delta)
			set_frame(8)
			if _timer <= 0.0:
				_start(SWEEP, SWEEP_TIME)
				Game.sfx("jet", -8.0, 0.7)
				Game.dust(get_parent(), global_position + Vector2(dir * 30, 0), 4, dir)
		SWEEP:
			_brake(delta)
			set_frame(9)
			_hit_rect(SWEEP_RECT, SWEEP_DAMAGE * damage_mult())
			if _timer <= 0.0:
				_sweep_cd = SWEEP_COOLDOWN
				_start(RECOVER, 0.5)
		RECOVER:
			_brake(delta)
			set_frame(5 if _timer > 0.25 and frame == 5 else 0)
			if _timer <= 0.0:
				_state = WALK
	move_and_slide()
	if _puff_t <= 0.0 and _state in [WALK, RECOVER, SLAM, LAND]:
		_puff()


func _start(s: int, t: float) -> void:
	_state = s
	_timer = t
	velocity.x = 0.0


func _finish(rest: float) -> void:
	_cool = ATTACK_GAP
	_start(RECOVER, rest + 0.5)


## 慢慢朝主角走；站着时一呼一吸，走的时候每一步地面一震
func _walk(p: Player, delta: float) -> void:
	var move := false
	if p:
		var dx := p.global_position.x - global_position.x
		if absf(dx) > 2.0:
			dir = 1 if dx > 0.0 else -1
		move = absf(dx) > STOP_DIST and is_on_floor() and not is_on_wall() and ground_ahead(30.0)
	velocity.x = dir * WALK_SPEED * speed_mult() if move else 0.0
	if move:
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = STEP_TIME / speed_mult()
			_step_frame = 3 if _step_frame == 2 else 2
			_footfall()
		set_frame(_step_frame)
	else:
		_step_t = 0.0
		set_frame(int(_time / BREATH_TIME) % 2)


func _footfall() -> void:
	var foot := global_position + Vector2((-8.0 if _step_frame == 2 else 10.0) * -dir, 0)
	Game.dust(get_parent(), foot, 2)
	Game.add_shake(0.8)
	Game.sfx("land", -16.0, 0.45, 0.05)


## 呼出一团白气（活物）
func _puff() -> void:
	_puff_t = PUFF_GAP + randf() * 0.8
	var puff := Breath.new()
	puff.position = global_position + Vector2(MOUTH.x * -dir, MOUTH.y)
	puff.drift = Vector2(dir * 10.0, 4.0)
	get_parent().add_child(puff)


# ---------------------------------------------------------------- 砸地
func _slam() -> void:
	_start(SLAM, SLAM_HOLD)
	var fx := global_position.x + FIST_X * -dir
	var at := Vector2(fx, global_position.y)
	_hit_rect(SLAM_RECT, SLAM_DAMAGE * damage_mult())
	_quake(at, WAVE_DIST, 7.0)


## 拳头 / 身子砸在地上：震屏、轰一声、裂缝、碎石，往两边推冲击波
func _quake(at: Vector2, dist: float, shake: float) -> void:
	Game.add_shake(shake)
	Game.hitstop(0.05)
	Game.sfx("boom", -2.0, 0.75)
	Game.sfx("clang", -12.0, 0.5)
	Game.dust(get_parent(), at, 10)
	Game.sparks(get_parent(), at + Vector2(0, -2), Color8(150, 132, 112), 12, 120.0, Vector2.UP)
	var crack := Crack.new()
	crack.position = at.round()
	get_parent().add_child(crack)
	for s in [-1, 1]:
		var w := Shockwave.new()
		w.position = at.round() + Vector2(s * 6, 0)
		w.dir = s
		w.max_dist = dist
		w.damage = WAVE_DAMAGE * damage_mult()
		get_parent().add_child(w)


# ---------------------------------------------------------------- 跳砸
func _start_leap(p: Player) -> void:
	_start(LEAP_WARN, LEAP_WARN_TIME)
	warn(LEAP_WARN_TIME)
	Game.sfx("charge", -8.0, 0.55)
	var dx := clampf(p.global_position.x - global_position.x, -LEAP_REACH, LEAP_REACH)
	if absf(dx) > 2.0:
		dir = 1 if dx > 0.0 else -1
	# 跳多高看天花板：头顶往上找，留 4 像素
	var space := get_world_2d().direct_space_state
	var head := global_position + Vector2(0, body_rect.position.y)
	var q := PhysicsRayQueryParameters2D.create(head, head + Vector2(0, -LEAP_MAX_RISE - 8.0), 1)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	var rise := LEAP_MAX_RISE if hit.is_empty() else clampf(head.y - (hit["position"] as Vector2).y - 4.0, 6.0, LEAP_MAX_RISE)
	var vy := -sqrt(2.0 * LEAP_GRAVITY * rise)
	var t := 2.0 * -vy / LEAP_GRAVITY
	_vx = clampf(dx / t, -LEAP_MAX_VX, LEAP_MAX_VX)
	velocity.y = 0.0
	set_meta("leap_vy", vy)
	# 落点：照实际能跳到的水平距离标，在那一列往下找地
	var tx := global_position.x + _vx * t
	var q2 := PhysicsRayQueryParameters2D.create(Vector2(tx, global_position.y - 30.0), Vector2(tx, global_position.y + 120.0), 1)
	var hit2 := space.intersect_ray(q2)
	var land := Vector2(tx, (hit2["position"] as Vector2).y) if not hit2.is_empty() else Vector2(tx, global_position.y)
	_marker = LeapMarker.new()
	_marker.position = land.round()
	get_parent().add_child(_marker)


func _launch() -> void:
	_state = LEAP_AIR
	_air_t = 0.0
	gravity = LEAP_GRAVITY
	velocity = Vector2(_vx, get_meta("leap_vy", -150.0))
	Game.dust(get_parent(), global_position, 6)
	Game.sfx("jump", -6.0, 0.5)
	Game.add_shake(2.0)


func _land() -> void:
	gravity = 900.0
	_start(LAND, LAND_HOLD)
	if is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null
	_hit_rect(LAND_RECT, LAND_DAMAGE * damage_mult())
	_quake(global_position, LAND_WAVE_DIST, 8.0)


# ----------------------------------------------------------------
func _brake(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)


## 朝左时的判定框 r（朝右时镜像），碰到的主角、地上的马灯都挨打
func _hit_rect(r: Rect2, dmg: float) -> void:
	if dir > 0:
		r.position.x = -r.position.x - r.size.x
	var shape := RectangleShape2D.new()
	shape.size = r.size
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.transform = Transform2D(0.0, global_position + r.get_center())
	q.collision_mask = 2 | 8
	for hit in get_world_2d().direct_space_state.intersect_shape(q, 8):
		var b: Object = hit["collider"]
		if b is Player:
			(b as Player).hurt(global_position, dmg)
		elif b is Crystal:
			(b as Crystal).take_hit(global_position, dmg)


## 蓄力时浑身发抖：贴图左右抖一格
func _update_visual() -> void:
	super._update_visual()
	if _state in [SLAM_WARN, LEAP_WARN, SWEEP_WARN] and not in_intro():
		_sprite.position.x += 1.0 if int(_time * 30.0) % 2 == 0 else -1.0


func _on_die() -> void:
	gravity = 900.0
	if is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null


func _on_respawn() -> void:
	_state = WALK
	_cool = 1.2


## 冲击波：贴着地面往一个方向推的一道土浪（高 10 的碎石 + 后面拖一串灰）。跟着地面走（上下 10 以内），
## 撞墙、到台子边或推满 max_dist 就停。碰到地上的人（脚在浪里）和马灯伤一下。不吃压暗。
class Shockwave:
	extends Node2D

	const SPEED := 150.0
	const HEIGHT := 10.0
	const ROCK := Color8(176, 160, 140)
	const DUST := Color8(214, 200, 180)

	var dir := 1
	var max_dist := 180.0
	var damage := 12.0
	var _gone := 0.0
	var _t := 0.0
	var _done := false

	func _ready() -> void:
		top_level = true
		z_index = 6
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded

	func _physics_process(delta: float) -> void:
		_t += delta
		if _done:
			if _t > 0.25:
				queue_free()
			queue_redraw()
			return
		var step := SPEED * delta
		var space := get_world_2d().direct_space_state
		var nx := global_position.x + dir * step
		var wq := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -4), Vector2(nx, global_position.y - 4), 1)
		var gq := PhysicsRayQueryParameters2D.create(Vector2(nx, global_position.y - 12), Vector2(nx, global_position.y + 12), 1)
		var g := space.intersect_ray(gq)
		if not space.intersect_ray(wq).is_empty() or g.is_empty() or _gone >= max_dist:
			_stop()
			return
		global_position = Vector2(nx, (g["position"] as Vector2).y)
		_gone += step
		var shape := RectangleShape2D.new()
		shape.size = Vector2(8, HEIGHT)
		var q := PhysicsShapeQueryParameters2D.new()
		q.shape = shape
		q.transform = Transform2D(0.0, global_position + Vector2(0, -HEIGHT / 2.0))
		q.collision_mask = 2 | 8
		for hit in space.intersect_shape(q, 8):
			var b: Object = hit["collider"]
			if b is Player:
				(b as Player).hurt(global_position - Vector2(dir * 10, 0), damage)
			elif b is Crystal:
				(b as Crystal).take_hit(global_position - Vector2(dir * 10, 0), damage)
		queue_redraw()

	func _stop() -> void:
		_done = true
		_t = 0.0
		Game.dust(get_parent(), global_position, 3)

	func _draw() -> void:
		var o := global_position.round() - global_position
		var fade := 1.0 - clampf(_t / 0.25, 0.0, 1.0) if _done else 1.0 - clampf((_gone - max_dist + 40.0) / 40.0, 0.0, 0.6)
		# 浪头：中间最高，往两边低下去；一格格的碎石，顶上亮一格
		var heights := [3, 6, 10, 7, 4]
		for i in heights.size():
			var h: int = heights[i] if not _done else heights[i] / 2
			var x := (i - 2) * dir
			var jig := 1 if (i + int(_t * 30.0)) % 3 == 0 else 0
			for y in range(h - jig):
				var c := ROCK if y < h - 2 else DUST
				draw_rect(Rect2(o + Vector2(x, -1 - y), Vector2.ONE), Color(c, fade))
		# 浪后面拖一串灰，越往后越矮越淡
		if not _done:
			for k in range(3, 18):
				if k % 2 == 0:
					continue
				var h2 := maxi(0, 3 - k / 6)
				for y in h2:
					draw_rect(Rect2(o + Vector2(-dir * k, -1 - y), Vector2.ONE), Color(DUST, fade * (1.0 - k / 18.0) * 0.8))


## 砸出来的裂缝：从落点往两边裂开几道锯齿缝，刚砸完缝里透出橙光，1.6 秒慢慢暗下去
class Crack:
	extends Node2D

	const LIFE := 1.6
	var _t := 0.0
	var _lines: Array = []

	func _ready() -> void:
		top_level = true
		z_index = 5
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for s in [-1, 1]:
			for n in 2:
				var pts: Array[Vector2] = [Vector2.ZERO]
				var p := Vector2.ZERO
				var length := rng.randi_range(14, 26) if n == 0 else rng.randi_range(6, 12)
				for k in length:
					p += Vector2(s, 0)
					if rng.randf() < 0.3:
						p.y = clampf(p.y + (-1 if rng.randf() < 0.5 else 1), -2 if n == 1 else 0, 0)
					pts.append(p)
				_lines.append(pts)

	func _physics_process(delta: float) -> void:
		_t += delta
		if _t >= LIFE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := _t / LIFE
		var glow := Color(1.0, 0.6, 0.3, 0.9 * (1.0 - k))
		var dark := Color(0.08, 0.06, 0.05, 0.85 * (1.0 - k * k))
		for pts in _lines:
			var n: int = pts.size()
			var shown := int(n * clampf(_t / 0.12, 0.0, 1.0))
			for i in shown:
				var p: Vector2 = pts[i]
				draw_rect(Rect2(p + Vector2(0, -1), Vector2.ONE), dark)
				if i < n * (1.0 - k):
					draw_rect(Rect2(p + Vector2(0, -2), Vector2.ONE), glow)


## 跳砸的落点：地上一道红色的括号 [ ]，上方一个往下的箭头，一闪一闪；落地时由巨人删掉
class LeapMarker:
	extends Node2D

	const HALF := 18.0
	var _t := 0.0

	func _ready() -> void:
		top_level = true
		z_index = 7
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded

	func _physics_process(delta: float) -> void:
		_t += delta
		if _t > 4.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var col := EnemyBase.LED_COLOR if int(_t * 10.0) % 2 == 0 else EnemyBase.LED_COLOR.darkened(0.45)
		draw_rect(Rect2(-HALF, -1, HALF * 2.0 + 1.0, 1), Color(col, 0.85))
		# 两头竖起来的括号角
		draw_rect(Rect2(-HALF, -4, 1, 3), col)
		draw_rect(Rect2(-HALF + 1.0, -4, 1, 1), col)
		draw_rect(Rect2(HALF, -4, 1, 3), col)
		draw_rect(Rect2(HALF - 1.0, -4, 1, 1), col)
		# 往下的箭头，一上一下地跳
		var bob := float(int(_t * 6.0) % 2)
		for i in 3:
			draw_rect(Rect2(-i, -10 + i + bob, i * 2 + 1, 1), col)
		draw_rect(Rect2(0, -14 + bob, 1, 4), col)


## 呼出来的一团白气：几颗淡白的点往前飘、慢慢散开变淡（活物）
class Breath:
	extends Node2D

	const LIFE := 1.1
	var drift := Vector2(10, 4)
	var _t := 0.0
	var _dots: Array[Vector2] = []

	func _ready() -> void:
		top_level = true
		z_index = 4
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded
		for i in 5:
			_dots.append(Vector2(randf_range(-2, 2), randf_range(-1, 1)))

	func _physics_process(delta: float) -> void:
		_t += delta
		if _t >= LIFE:
			queue_free()
			return
		global_position += drift * delta
		queue_redraw()

	func _draw() -> void:
		var k := _t / LIFE
		var spread := 1.0 + k * 3.0
		for d in _dots:
			draw_rect(Rect2((d * spread).round() + Vector2(0, -k * 4.0).round(), Vector2.ONE),
					Color(0.85, 0.85, 0.82, 0.45 * (1.0 - k)))
