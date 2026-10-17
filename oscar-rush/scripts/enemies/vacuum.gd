class_name Vacuum
extends EliteBase
## 吸尘器（策划案第九节，第一关精英怪 5）：把你、光球、地上的马灯都往嘴里吸，马灯真的会被吸走。
## 平时慢慢朝主角挪。一个阶段，两招接着放，都先冒红色"!"：
## - 吸（2.5 秒）：吸嘴前方 120×40 的范围里，主角被往吸嘴拉（约 60 像素/秒），光球的轨迹往吸嘴弯，
##   地上的马灯被拉过去，碰到吸嘴就挂在嘴上，每秒掉 5 点血；打吸尘器 3 下或者打死它，马灯掉回地上。
## - 噗：吸完把灰喷出来，一扇碎屑往前飞，碰到伤 8。
## 碰到身子（包括吸嘴）伤 10。
## 主角被拉是直接挪位置（move_and_collide），不是改 velocity.x：主角自己每帧会把 velocity.x
## 用 move_toward 拉回摇杆想要的速度，外面加的 60 像素/秒在同一帧就被吃掉了。
## 贴图 vacuum.png（草图/精英怪/export_piano_vacuum.py 导出）：
## 0、1 走，2 预警（吸头抬到一半），3、4 吸，5 噗（嘴张大），6 喷完往后缩。

enum State { MOVE, SUCK_WARN, SUCK, SPIT_WARN, SPIT, RECOVER }

const MOVE_SPEED := 16.0
const WALK_FRAME_TIME := 0.2
## 离主角这么近就不再往前挪
const STOP_DIST := 34.0
const MOVE_TIME := Vector2(2.0, 2.8)
## 主角在前面这么远以内才开始吸
const SUCK_RANGE := 190.0
const SUCK_WARN := 0.6
const SUCK_TIME := 2.5
const ZONE_LENGTH := 120.0
const ZONE_HEIGHT := 40.0
## 不跟情绪档位变快：提着灯走 90 像素/秒，拉力再大就走不出去了
const PULL_PLAYER := 60.0
const PULL_CRYSTAL := 75.0
## 光球往吸嘴拐的角速度（弧度/秒）
const BEND := 4.0
## 马灯离吸嘴这么近就被吸住
const GRAB_DIST := 9.0
const HELD_DRAIN := 5.0
const HELD_HITS := 3
const SPIT_WARN := 0.5
const SPIT_TIME := 0.25
const DEBRIS := 7
const DEBRIS_SPREAD := 0.5
const DEBRIS_SPEED := Vector2(120.0, 170.0)
const DEBRIS_DAMAGE := 8.0
const RECOVER_TIME := 0.9
## 吸嘴（抬起时）相对脚底中点的位置，朝左
const MOUTH := Vector2(-18, -14)
## 吸头平放在地上（走路、预警）时，嘴的前端
const MOUTH_FLOOR := Vector2(-21, -2)

var state := State.MOVE
var _state_t := 0.0
var _move_time := 2.4
var _suck_dir := -1
var _sound: AudioStreamPlayer
var _held: Crystal = null
var _held_hits := 0
var _drain_t := 0.0
## 刚吐出来的马灯短时间内不再被身子碰到
var _spat_t := 0.0
var _suck_fx: CPUParticles2D


func _setup() -> void:
	elite_name = "VACUUM"
	texture_path = "res://art/enemies/vacuum.png"
	hframes = 7
	frame_size = Vector2i(46, 20)
	body_rect = Rect2(-22, -19, 44, 19)
	led_pixel = Vector2i(20, 4)
	max_hp = 1200.0
	contact_damage = 10.0
	_move_time = 1.6


func _after_ready() -> void:
	# 吸的时候嘴前面一股灰往嘴里收
	_suck_fx = CPUParticles2D.new()
	_suck_fx.emitting = false
	_suck_fx.amount = 40
	_suck_fx.lifetime = 0.6
	_suck_fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_suck_fx.emission_rect_extents = Vector2(4, ZONE_HEIGHT / 2.0 - 4.0)
	_suck_fx.spread = 8.0
	_suck_fx.gravity = Vector2.ZERO
	_suck_fx.scale_amount_min = 1.0
	_suck_fx.scale_amount_max = 1.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.54, 0.52, 0.49, 0.0))
	ramp.set_color(1, Color(0.54, 0.52, 0.49, 0.8))
	_suck_fx.color_ramp = ramp
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_suck_fx.material = mat
	add_child(_suck_fx)


func _tick(delta: float) -> void:
	_state_t += delta
	_spat_t -= delta
	match state:
		State.MOVE:
			_move(delta)
			var p := nearest_player()
			if _state_t >= _move_time * interval_mult() and is_on_floor() and p \
					and absf(p.global_position.x - global_position.x) < SUCK_RANGE \
					and absf(p.global_position.y - global_position.y) < 60.0:
				_face(p)
				_suck_dir = dir
				warn(SUCK_WARN)
				_enter(State.SUCK_WARN)
		State.SUCK_WARN:
			_brake(delta)
			set_frame(2)
		State.SUCK:
			_brake(delta)
			set_frame(3 + int(_state_t / 0.08) % 2)
			_suck(delta)
		State.SPIT_WARN:
			_brake(delta)
			# 鼓着一口灰：缩回去的吸头一抖一抖
			set_frame(6 if int(_state_t / 0.07) % 2 == 0 else 3)
		State.SPIT:
			_brake(delta)
			set_frame(5)
		State.RECOVER:
			_brake(delta)
			set_frame(6 if _state_t < 0.3 else (2 if _state_t < 0.55 else 0))
	match state:
		State.SUCK_WARN:
			if _state_t >= SUCK_WARN:
				_enter(State.SUCK)
		State.SUCK:
			if _state_t >= SUCK_TIME:
				warn(SPIT_WARN)
				_enter(State.SPIT_WARN)
		State.SPIT_WARN:
			if _state_t >= SPIT_WARN:
				_spit()
				_enter(State.SPIT)
		State.SPIT:
			if _state_t >= SPIT_TIME:
				_enter(State.RECOVER)
		State.RECOVER:
			if _state_t >= RECOVER_TIME:
				_enter(State.MOVE)
	move_and_slide()
	_hold_crystal(delta)


func _enter(s: State) -> void:
	state = s
	_state_t = 0.0
	_suck_fx.emitting = s == State.SUCK
	if s == State.MOVE:
		_move_time = randf_range(MOVE_TIME.x, MOVE_TIME.y)
	elif s == State.SUCK:
		_suck_fx.position = Vector2(MOUTH.x * -_suck_dir + _suck_dir * 40.0, MOUTH.y)
		_suck_fx.direction = Vector2(-_suck_dir, 0)
		_suck_fx.initial_velocity_min = 55.0
		_suck_fx.initial_velocity_max = 75.0
		# 一口气吸 2.5 秒：喷气声（2 秒一圈）放慢到 0.8 倍正好 2.5 秒
		_sound = Game.sfx("jet", -8.0, 0.8)
	else:
		if is_instance_valid(_sound):
			_sound.stop()
		if s == State.SPIT_WARN:
			Game.sfx("charge", -14.0, 0.5)


func _move(delta: float) -> void:
	var p := nearest_player()
	var want := 0.0
	if p:
		var dx := p.global_position.x - global_position.x
		_face(p)
		if absf(dx) > STOP_DIST:
			want = dir * MOVE_SPEED * speed_mult()
	if want != 0.0 and is_on_floor() and (is_on_wall() or not ground_ahead(24.0)):
		want = 0.0
	if not is_knocked():
		velocity.x = move_toward(velocity.x, want, 200.0 * delta)
	set_frame(int(_time / WALK_FRAME_TIME) % 2 if absf(velocity.x) > 2.0 else 0)


func _brake(delta: float) -> void:
	if not is_knocked():
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)


func _face(p: Player) -> void:
	if absf(p.global_position.x - global_position.x) > 2.0:
		dir = 1 if p.global_position.x > global_position.x else -1


## 吸嘴相对原点的位置（跟着朝向镜像）：3~6 帧吸头抬着，0~2 帧趴在地上
func _mouth_local() -> Vector2:
	var m := MOUTH if frame >= 3 else MOUTH_FLOOR
	return Vector2(m.x * -dir, m.y)


func mouth_point() -> Vector2:
	return global_position + _mouth_local()


## 吸的范围：吸嘴前方 ZONE_LENGTH，从脚底往上 ZONE_HEIGHT
func _zone() -> Rect2:
	var m := mouth_point()
	var x0 := m.x if _suck_dir > 0 else m.x - ZONE_LENGTH
	return Rect2(x0, global_position.y - ZONE_HEIGHT, ZONE_LENGTH, ZONE_HEIGHT)


func _suck(delta: float) -> void:
	var zone := _zone()
	var mouth := mouth_point()
	for n in get_tree().get_nodes_in_group("player"):
		var p := n as Player
		if p == null or not zone.has_point(p.global_position + Vector2(0, -8)):
			continue
		var dx := mouth.x - p.global_position.x
		if absf(dx) > 1.0:
			var step := signf(dx) * minf(PULL_PLAYER * delta, absf(dx))
			p.move_and_collide(Vector2(step, 0))
	# 光球放在关卡节点下面，和主角同一层
	var levels := {}
	for n in get_tree().get_nodes_in_group("player"):
		levels[n.get_parent()] = true
	for level in levels:
		for o in (level as Node).get_children():
			var orb := o as Orb
			if orb and zone.has_point(orb.global_position):
				var want := (mouth - orb.global_position).angle()
				var diff := wrapf(want - orb.velocity.angle(), -PI, PI)
				orb.velocity = orb.velocity.rotated(clampf(diff, -BEND * delta, BEND * delta))
	if _held != null:
		return
	for n in get_tree().get_nodes_in_group("crystal"):
		var c := n as Crystal
		if c == null or c.carrier != null or not zone.grow(4.0).has_point(c.global_position + Vector2(0, -4)):
			continue
		var to := mouth - (c.global_position + Vector2(0, -4))
		if to.length() < GRAB_DIST or _touching(c):
			_grab(c)
			return
		c.velocity = to.normalized() * PULL_CRYSTAL


func _touching(c: Crystal) -> bool:
	return c in _contact.get_overlapping_bodies()


func _grab(c: Crystal) -> void:
	_held = c
	_held_hits = 0
	_drain_t = 0.0
	# 挂在嘴上的时候不让马灯自己掉下去；碰撞层关掉，免得被身子当成"碰到"
	c.set_physics_process(false)
	c.collision_layer = 0
	c.velocity = Vector2.ZERO
	Game.sfx("lantern_pick", -4.0, 0.7)
	Game.sfx("crack", -8.0, 0.8)
	Game.add_shake(2.0)


func _hold_crystal(delta: float) -> void:
	if _held == null:
		return
	if not is_instance_valid(_held):
		_held = null
		return
	# 主角把灯从嘴上拿走了
	if _held.carrier != null:
		_held.set_physics_process(true)
		_held = null
		return
	# 抬着的嘴：挂在嘴口；趴着的吸头：被压在吸头前端底下拖着走
	var hang := Vector2(-dir * 2.0, 5.0) if frame >= 3 else Vector2(-dir * 2.0, 2.0)
	_held.global_position = (mouth_point() + hang).round()
	_held.queue_redraw()
	_drain_t += delta
	if _drain_t >= 0.5:
		_drain_t -= 0.5
		Run.damage_crystal(HELD_DRAIN * 0.5 * damage_mult())
		Game.sparks(get_parent(), _held.global_position + Vector2(0, -5), Crystal.GLASS, 3, 40.0)
		Game.sfx("crack", -16.0, 1.2, 0.1)


## 把马灯吐回地上，往前抛一点。quiet：关卡卸载时只把马灯恢复原样
func _release(quiet := false) -> void:
	if _held == null:
		return
	var c := _held
	_held = null
	if not is_instance_valid(c):
		return
	c.set_physics_process(true)
	if c.carrier == null:
		c.collision_layer = 8
	if quiet:
		return
	if c.carrier == null:
		c.global_position = mouth_point() + Vector2(dir * 6.0, 4.0)
		c.velocity = Vector2(dir * 90.0, -110.0)
	_spat_t = 0.8
	Game.sfx("lantern_drop", -4.0, 0.9)


func _on_hurt(_damage: float, _full: bool) -> void:
	if _held != null:
		_held_hits += 1
		if _held_hits >= HELD_HITS:
			_release()


func _on_die() -> void:
	_release()
	_suck_fx.emitting = false
	if is_instance_valid(_sound):
		_sound.stop()


func _exit_tree() -> void:
	_release(true)


func _on_respawn() -> void:
	_enter(State.MOVE)


## 噗：一扇碎屑从吸嘴往前飞
func _spit() -> void:
	var m := mouth_point()
	var fwd := float(_suck_dir)
	for i in DEBRIS:
		var a := lerpf(-DEBRIS_SPREAD, DEBRIS_SPREAD, float(i) / (DEBRIS - 1)) - 0.12
		var d := Debris.new()
		d.velocity = Vector2(fwd, 0).rotated(a * fwd) * randf_range(DEBRIS_SPEED.x, DEBRIS_SPEED.y)
		d.damage = DEBRIS_DAMAGE * damage_mult()
		d.position = m
		get_parent().add_child(d)
	Game.sparks(get_parent(), m, Color8(0x8a, 0x84, 0x7c), 12, 110.0, Vector2(fwd, 0))
	Game.sfx("jet", -6.0, 1.6)
	Game.sfx("hit", -10.0, 0.6)
	Game.add_shake(2.0)
	velocity.x = -fwd * 40.0


## 身子碰到伤人；吸的时候地上的马灯不挨打（要被吸进嘴里），挂在嘴上的和刚吐出来的也不挨打
func _contact_damage() -> void:
	if not _contact.monitoring or contact_damage <= 0.0:
		return
	var dmg := contact_damage * damage_mult()
	for b in _contact.get_overlapping_bodies():
		if b is Player:
			(b as Player).hurt(global_position, dmg)
		elif b is Crystal and b != _held and _spat_t <= 0.0 and state != State.SUCK:
			(b as Crystal).take_hit(global_position, dmg)


## 喷出来的一块碎屑：受一点重力，碰到墙或地就碎，碰到主角伤人，碰到地上的马灯也伤
class Debris:
	extends Node2D

	const LIFE := 0.9
	const GRAVITY := 160.0
	const COLORS := [Color8(0x8a, 0x84, 0x7c), Color8(0x6e, 0x68, 0x62), Color8(0x5c, 0x57, 0x52)]

	var velocity := Vector2.ZERO
	var damage := 8.0
	var _t := 0.0
	var _col: Color

	func _ready() -> void:
		z_index = 4
		_col = COLORS[randi() % COLORS.size()]
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded

	func _physics_process(delta: float) -> void:
		_t += delta
		if _t >= LIFE:
			queue_free()
			return
		velocity.y += GRAVITY * delta
		var to := global_position + velocity * delta
		var q := PhysicsRayQueryParameters2D.create(global_position, to, 1)
		if not get_world_2d().direct_space_state.intersect_ray(q).is_empty():
			Game.sparks(get_parent(), global_position, _col, 3, 30.0)
			queue_free()
			return
		global_position = to
		var me := Rect2(global_position - Vector2(1, 1), Vector2(3, 3))
		for n in get_tree().get_nodes_in_group("player"):
			var p := n as Player
			if p and me.intersects(Rect2(p.global_position + Vector2(-3, -16), Vector2(6, 16))):
				if p.hurt(global_position, damage):
					queue_free()
					return
		for n in get_tree().get_nodes_in_group("crystal"):
			var c := n as Crystal
			if c and c.carrier == null and c.is_physics_processing() \
					and me.intersects(Rect2(c.global_position + Vector2(-2.5, -8), Vector2(5, 8))):
				c.take_hit(global_position, damage)
				queue_free()
				return
		queue_redraw()

	func _draw() -> void:
		var a := clampf((LIFE - _t) / 0.2, 0.0, 1.0)
		draw_set_transform(global_position.round() - global_position)
		draw_rect(Rect2(-1, -1, 2, 2), Color(_col, a))
		draw_rect(Rect2(-1 - signf(velocity.x), -1, 1, 1), Color(_col, a * 0.4))
