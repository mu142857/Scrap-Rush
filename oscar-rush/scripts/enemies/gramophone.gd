class_name Gramophone
extends EliteBase
## 留声机（第二关精英怪，从策划案第九节原设计 B3 留声机来）：大喇叭朝前，转盘上放着唱片，唱臂会动。
## 红灯在喇叭的喉咙深处。和主角保持一段距离（远了靠近、近了后退），两招轮着放，都先冒红色"!"：
## - 唱针横扫：唱臂伸长，唱针贴着地面从脚下一直划到场子那头（撞墙或者到坑边停），要跳过去。
##   唱针头宽 6、高 8，碰到伤 12；伸出去的唱臂不伤人。划完抬起来收回去。
## - 声波：喇叭放出 3 圈往外扩的声波（空心圆弧，只往前半边放，越扩越淡），碰到伤 8、情绪 +5。
##   三圈的缺口在同一个方向，缺口落在地面上的那一段（离主角现在站的地方 50 像素）先用淡绿点标出来，
##   走过去站着，三圈都从身边钻过去。躲到留声机背后也安全。
##   （试过三圈缺口来回换位置：前一圈还没扩到时下一圈的缺口已经要你站别处，两头顾不上，改成同一处。）
## 贴图 gramophone.png（草图/精英怪/l2_switch_gramophone.py 导出），6 帧：
## 0、1 走（唱片转）；2 横扫预警（唱臂抬起）；3 横扫（唱臂甩到前面朝下）；4 声波预警（喇叭口亮）；5 声波（喇叭口张大）。

enum State { MOVE, SWEEP_WARN, SWEEP, WAVE_WARN, WAVE, RECOVER }

const MOVE_SPEED := 13.0
const WALK_FRAME_TIME := 0.25
## 主角比这个近就后退，比 FAR 远就靠近
const NEAR := 50.0
const FAR := 110.0
const MOVE_TIME := Vector2(2.4, 3.0)
const ATTACK_RANGE := 240.0
const SWEEP_WARN := 0.8
## 横扫最长等多久（唱针一般 2 秒多就收回来了）
const SWEEP_MAX := 4.5
const WAVE_WARN := 0.8
const RINGS := 3
const RING_GAP := 0.8
const RECOVER_TIME := 0.9
## 帧内像素（朝左）：横扫时的臂尖、喇叭口中心
const ARM_TIP := Vector2i(10, 30)
const MOUTH := Vector2i(6, 11)
## 声波缺口离主角站的地方多远、地面上那一段的一半宽
const ZONE_STEP := 50.0
const ZONE_HALF := 20.0

var state := State.MOVE
var _state_t := 0.0
var _move_time := 1.4
var _next := 0
var _attack_dir := -1
var _needle: Needle = null
var _rings_left := 0
## 声波缺口落在地面上的位置（离喇叭口的前向距离）
var _zone := 80.0
## 声波缺口标在哪层地面上（主角当时站的地面）
var _zone_floor := 0.0


func _setup() -> void:
	elite_name = "GRAMOPHONE"
	intro_title = "NOW PLAYING"
	intro_frame = 5
	texture_path = "res://art/enemies/gramophone.png"
	hframes = 6
	frame_size = Vector2i(54, 46)
	# 身子连喇叭一起算（光球打喇叭也算），碰到伤人只算柜子和腿
	body_rect = Rect2(-21, -45, 42, 45)
	contact_rect = Rect2(-13, -35, 28, 35)
	led_pixel = Vector2i(7, 11)
	max_hp = 1150.0
	contact_damage = 10.0


func _tick(delta: float) -> void:
	_state_t += delta
	match state:
		State.MOVE:
			_move(delta)
			set_frame(int(_time / WALK_FRAME_TIME) % 2)
			var p := nearest_player(ATTACK_RANGE)
			if _state_t >= _move_time and is_on_floor() and p \
					and absf(p.global_position.y - global_position.y) < 80.0:
				_start_attack(p)
		State.SWEEP_WARN:
			_brake(delta)
			set_frame(2)
			if _state_t >= SWEEP_WARN:
				_sweep()
				_enter(State.SWEEP)
		State.SWEEP:
			_brake(delta)
			set_frame(3)
			if not is_instance_valid(_needle) or _state_t >= SWEEP_MAX:
				_enter(State.RECOVER)
		State.WAVE_WARN:
			_brake(delta)
			set_frame(4)
			if _state_t >= WAVE_WARN:
				_rings_left = RINGS
				_enter(State.WAVE)
		State.WAVE:
			_brake(delta)
			set_frame(5 if fmod(_state_t, RING_GAP) < 0.35 else 4)
			if _rings_left > 0 and _state_t >= (RINGS - _rings_left) * RING_GAP:
				_ring(RINGS - _rings_left)
				_rings_left -= 1
			if _rings_left == 0 and _state_t >= (RINGS - 1) * RING_GAP + 0.5:
				_enter(State.RECOVER)
		State.RECOVER:
			_brake(delta)
			set_frame(int(_time / WALK_FRAME_TIME) % 2)
			if _state_t >= RECOVER_TIME:
				_enter(State.MOVE)
	move_and_slide()


func _enter(s: State) -> void:
	state = s
	_state_t = 0.0
	if s == State.MOVE:
		_move_time = randf_range(MOVE_TIME.x, MOVE_TIME.y)


func _start_attack(p: Player) -> void:
	_face(p)
	_attack_dir = dir
	if _next == 0:
		warn(SWEEP_WARN)
		_enter(State.SWEEP_WARN)
		Game.sfx("tvclick", -6.0, 0.7)
	else:
		warn(WAVE_WARN)
		_enter(State.WAVE_WARN)
		_plan_zones(p)
		Game.sfx("charge", -10.0, 0.9)
	_next = 1 - _next


func _move(delta: float) -> void:
	var p := nearest_player()
	if p == null:
		_brake(delta)
		return
	_face(p)
	var dx := absf(p.global_position.x - global_position.x)
	var want := 0
	if dx > FAR:
		want = dir
	elif dx < NEAR:
		want = -dir                         # 面朝主角往后退
	var free := want != 0 and _ground_at(want, 24.0) and not _wall_at(want)
	if free:
		velocity.x = want * MOVE_SPEED * speed_mult()
	else:
		_brake(delta)


func _brake(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)


func _face(p: Player) -> void:
	if absf(p.global_position.x - global_position.x) > 2.0:
		dir = 1 if p.global_position.x > global_position.x else -1


func _ground_at(side: int, dist: float) -> bool:
	var from := global_position + Vector2(side * dist, -2)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 8), 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _wall_at(side: int) -> bool:
	var from := global_position + Vector2(0, -8)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(side * 26.0, 0), 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


## 帧里的像素（原图朝左）→ 相对脚底中间的位置，朝右时镜像
func _frame_pos(px: Vector2i) -> Vector2:
	var col := px.x if dir < 0 else frame_size.x - 1 - px.x
	return Vector2(col - frame_size.x / 2, px.y - frame_size.y)


func arm_tip() -> Vector2:
	return global_position.round() + _frame_pos(ARM_TIP)


func mouth() -> Vector2:
	return global_position.round() + _frame_pos(MOUTH)


## 唱针横扫：从前脚外面贴着地面划出去
func _sweep() -> void:
	var n := Needle.new()
	n.elite = self
	n.dir = _attack_dir
	get_parent().add_child(n)
	n.global_position = Vector2(roundf(global_position.x + _attack_dir * 18.0), global_position.y)
	_needle = n
	Game.sfx("scrape", -4.0, 0.8)
	Game.add_shake(1.5)


## 声波缺口：离主角现在站的地方 ZONE_STEP（优先往远处挪，远处没地就往近处），三圈都用这一处
func _plan_zones(p: Player) -> void:
	var m := mouth()
	var a := clampf((p.global_position.x - m.x) * _attack_dir, 30.0, 140.0)
	var floor_y := p.global_position.y if p.is_on_floor() else global_position.y
	var b := a + ZONE_STEP if a + ZONE_STEP <= 150.0 else a - ZONE_STEP
	if not _floor_near(m.x + _attack_dir * b, floor_y):
		b = a - ZONE_STEP if b > a else a + ZONE_STEP
		if b < 24.0 or not _floor_near(m.x + _attack_dir * b, floor_y):
			b = a
	_zone = b
	_zone_floor = floor_y


func _floor_near(x: float, y: float) -> bool:
	var q := PhysicsRayQueryParameters2D.create(Vector2(x, y - 4.0), Vector2(x, y + 4.0), 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _ring(i: int) -> void:
	var r := SoundRing.new()
	r.dir = _attack_dir
	r.center = mouth()
	r.floor_y = _zone_floor
	r.zone = Vector2(_zone - ZONE_HALF, _zone + ZONE_HALF)
	get_parent().add_child(r)
	Game.sfx("bell", -8.0, 0.55 + 0.08 * i)
	Game.sfx("voice", -10.0, 0.6)
	Game.add_shake(1.5)


func _on_die() -> void:
	if is_instance_valid(_needle):
		_needle.lift()


func _on_respawn() -> void:
	_enter(State.MOVE)


## 预警时琴身抖、一闪一闪发红（照钢琴）
func _update_visual() -> void:
	super._update_visual()
	var warn_t := -1.0
	match state:
		State.SWEEP_WARN:
			warn_t = _state_t / SWEEP_WARN
		State.WAVE_WARN:
			warn_t = _state_t / WAVE_WARN
	if warn_t >= 0.0:
		var amp := 1.0 if warn_t < 0.6 else 2.0
		_sprite.position.x += amp if int(_state_t * 30.0) % 2 == 0 else -amp
		var pulse := 0.5 + 0.5 * sin(_state_t * (14.0 + 20.0 * warn_t))
		_sprite.modulate = Color.WHITE.lerp(Color(1.8, 0.75, 0.6), pulse * (0.4 + 0.6 * warn_t))
	else:
		_sprite.modulate = Color.WHITE


## 伸长的唱臂 + 贴地划过去的唱针。原点 = 唱针尖（地面上）。
## 往前划：跟着地面走（往上 8、往下 12 像素以内的台阶跟过去），撞墙、到坑边、划满 REACH 就抬起来收回去。
## 只有唱针头伤人；收回去的时候不伤人。
class Needle:
	extends Node2D

	const SPEED := 150.0
	const RETRACT_SPEED := 420.0
	const REACH := 320.0
	const DAMAGE := 12.0
	## 唱针头的判定：宽 6、贴地往上 8（跳得过去）
	const HEAD := Rect2(-3, -8, 6, 8)
	const ARM := Color8(0x8a, 0x84, 0x7c)
	const ARM_DARK := Color8(0x5c, 0x57, 0x52)
	const GROOVE := Color(1.0, 0.75, 0.5)

	var elite: Gramophone
	var dir := -1
	var _travel := 0.0
	var _back := false
	var _start_x := 0.0
	var _t := 0.0
	var _spark_t := 0.0

	func _ready() -> void:
		z_index = 4
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded
		_start_x = global_position.x

	func lift() -> void:
		if not _back:
			_back = true
			Game.sfx("tvclick", -8.0, 1.2)

	func _physics_process(delta: float) -> void:
		_t += delta
		if not is_instance_valid(elite) or elite.dead:
			queue_free()
			return
		if _back:
			var home := elite.arm_tip()
			global_position.x = move_toward(global_position.x, home.x, RETRACT_SPEED * delta)
			global_position.y = move_toward(global_position.y, home.y, RETRACT_SPEED * 0.5 * delta)
			if absf(global_position.x - home.x) < 2.0:
				queue_free()
				return
			queue_redraw()
			return
		var step := SPEED * delta
		var x := global_position.x
		var y := global_position.y
		var nx := x + dir * step
		var space := elite.get_world_2d().direct_space_state
		var wall := PhysicsRayQueryParameters2D.create(Vector2(x, y - 6.0), Vector2(nx + dir * 3.0, y - 6.0), 1)
		var fy := _floor_y(nx, y - 9.0, 21.0)
		if not space.intersect_ray(wall).is_empty() or is_nan(fy) or _travel >= REACH:
			Game.sparks(get_parent(), global_position + Vector2(0, -2), GROOVE, 6, 60.0, Vector2.UP)
			lift()
			queue_redraw()
			return
		global_position = Vector2(nx, fy)
		_travel += step
		_spark_t -= delta
		if _spark_t <= 0.0:
			_spark_t = 0.07
			Game.sparks(get_parent(), global_position + Vector2(-dir * 2.0, -1), GROOVE, 1, 40.0, Vector2(-dir, -1).normalized())
		_hit()
		queue_redraw()

	func _floor_y(x: float, from_y: float, depth: float) -> float:
		var q := PhysicsRayQueryParameters2D.create(Vector2(x, from_y), Vector2(x, from_y + depth), 1)
		var hit := get_world_2d().direct_space_state.intersect_ray(q)
		if hit.is_empty() or (hit.normal as Vector2).y > -0.5:
			return NAN
		return (hit.position as Vector2).y

	func _hit() -> void:
		var r := Rect2(global_position + HEAD.position, HEAD.size)
		for n in get_tree().get_nodes_in_group("player"):
			var p := n as Player
			if p and r.intersects(Rect2(p.global_position + Vector2(-3, -16), Vector2(6, 16))):
				p.hurt(global_position + Vector2(-dir * 6.0, 0), DAMAGE * EnemyBase.damage_mult())
		for n in get_tree().get_nodes_in_group("crystal"):
			var c := n as Crystal
			if c and c.carrier == null and r.intersects(Rect2(c.global_position + Vector2(-2.5, -8), Vector2(5, 8))):
				c.take_hit(global_position + Vector2(-dir * 6.0, 0), DAMAGE * EnemyBase.damage_mult())

	func _draw() -> void:
		draw_set_transform(global_position.round() - global_position)
		var me := global_position.round()
		var tip := elite.arm_tip() - me
		var lift_y := -10.0 if _back else 0.0
		# 划过的地方留一道发烫的唱片纹，慢慢变淡
		if not _back:
			var x0 := minf(_start_x - me.x, 0.0)
			var x1 := maxf(_start_x - me.x, 0.0)
			draw_rect(Rect2(x0, -1, x1 - x0, 1), Color(GROOVE, 0.35))
		# 唱臂：从臂尖斜着落到离地 5 像素，再贴着地面伸到唱针头
		var knee := Vector2(tip.x + dir * 6.0, -5.0 + lift_y)
		var head := Vector2(0, -6.0 + lift_y)
		_line(tip, knee, ARM)
		_line(knee, head, ARM)
		_line(knee + Vector2(0, 1), head + Vector2(0, 1), ARM_DARK)
		# 唱头：一小块，底下一根针尖着地
		draw_rect(Rect2(-2, -8 + lift_y, 5, 3), ARM)
		draw_rect(Rect2(-2, -8 + lift_y, 5, 1), Color8(0xa8, 0xa2, 0x98))
		draw_rect(Rect2(0, -5 + lift_y, 1, 5), Color(1.0, 0.92, 0.8))
		if not _back and int(_t * 20.0) % 2 == 0:
			draw_rect(Rect2(-1, -1, 3, 1), Color(GROOVE, 0.9))

	func _line(a: Vector2, b: Vector2, col: Color) -> void:
		var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
		for i in n + 1:
			var t := float(i) / maxf(n, 1)
			draw_rect(Rect2(a.lerp(b, t).round(), Vector2.ONE), col)


## 一圈往外扩的声波（空心圆弧，只往前半边），越扩越淡。缺口对着地面上的一段（zone，离喇叭口的前向距离），
## 那一段地面上先用淡绿点标出来。碰到伤 8、情绪 +5，每圈每人最多打一下。
class SoundRing:
	extends Node2D

	const SPEED := 65.0
	const MAX_R := 160.0
	## 扩到这么大以后不再伤人（已经很淡了）
	const HARM_R := 140.0
	const BAND := 2.5
	## 往前张开的半角（弧度）：从正上方稍过一点到正下方稍过一点
	const ARC := 1.83
	const DAMAGE := 8.0
	const EMOTION := 5.0
	const COLOR := Color(1.0, 0.86, 0.62)
	const SAFE := Color(0.6, 1.0, 0.6)

	var dir := -1
	var center := Vector2.ZERO
	var floor_y := 0.0
	## 缺口落在地面上的那一段：离喇叭口的前向距离（近, 远）
	var zone := Vector2(60, 96)
	var _r := 3.0
	var _gap := Vector2.ZERO
	var _hit := {}

	func _ready() -> void:
		z_index = 8
		top_level = true
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded
		global_position = Vector2.ZERO
		# 缺口的角度范围：主角站在 zone 里时，从头顶（远端）到脚底（近端）都要在缺口里
		var dy_feet := floor_y - center.y
		var dy_head := floor_y - 16.0 - center.y
		_gap = Vector2(atan2(dy_head, maxf(zone.y, 4.0)), atan2(dy_feet, maxf(zone.x, 4.0)))
		if _gap.x > _gap.y:
			_gap = Vector2(_gap.y, _gap.x)

	## 世界坐标 → 前向角（正前方 0，往下为正）
	func _angle(pt: Vector2) -> float:
		var v := pt - center
		return atan2(v.y, v.x * dir)

	func _in_gap(a: float) -> bool:
		return a >= _gap.x and a <= _gap.y

	func _physics_process(delta: float) -> void:
		_r += SPEED * delta
		if _r >= MAX_R:
			queue_free()
			return
		if _r < HARM_R:
			for n in get_tree().get_nodes_in_group("player"):
				var p := n as Player
				if p == null or _hit.has(p.get_instance_id()):
					continue
				for h in [2.0, 8.0, 14.0]:
					var pt := p.global_position + Vector2(0, -h)
					var a := _angle(pt)
					if absf(pt.distance_to(center) - _r) <= BAND and absf(a) <= ARC and not _in_gap(a):
						_hit[p.get_instance_id()] = true
						if p.hurt(center, DAMAGE * EnemyBase.damage_mult()):
							Run.add_emotion(EMOTION)
						break
		queue_redraw()

	func _draw() -> void:
		var alpha := clampf(1.0 - _r / MAX_R, 0.0, 1.0)
		# 缺口落在地面上的那一段：淡绿点，圈快到的时候闪
		var reach := zone.x - (_r - 10.0)
		if reach > -20.0:
			var blink := reach < 30.0 and int(_r / 4.0) % 2 == 0
			var col := Color(SAFE, 0.8 if blink else 0.45)
			for d in range(int(zone.x), int(zone.y) + 1, 4):
				draw_rect(Rect2(roundf(center.x + dir * d), floor_y - 1, 2, 1), col)
		# 圈：一格一个点，同一个像素只画一次
		var pts := {}
		var steps := int(ceilf(2.0 * ARC * _r * 1.4)) + 8
		for i in steps + 1:
			var a := -ARC + 2.0 * ARC * i / steps
			if _in_gap(a):
				continue
			var p := (center + Vector2(cos(a) * dir, sin(a)) * _r).round()
			pts[p] = true
		var c := Color(COLOR, 0.85 * alpha)
		for p in pts:
			draw_rect(Rect2(p, Vector2.ONE), c)
		# 内侧再淡一圈，看起来有厚度
		if _r > 6.0:
			var inner := {}
			for i in steps + 1:
				var a := -ARC + 2.0 * ARC * i / steps
				if _in_gap(a):
					continue
				var p := (center + Vector2(cos(a) * dir, sin(a)) * (_r - 2.0)).round()
				if not pts.has(p):
					inner[p] = true
			for p in inner:
				draw_rect(Rect2(p, Vector2.ONE), Color(COLOR, 0.3 * alpha))
