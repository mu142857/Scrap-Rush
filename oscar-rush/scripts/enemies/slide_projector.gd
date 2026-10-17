class_name SlideProjector
extends EnemyBase
## 幻灯机（策划案第九节 16，弩手）：远程，血 200。和主角保持 80～140 像素，太近就往后退。
## 一道红色瞄准线跟着你 1.0 秒，然后锁住不动、闪 0.4 秒，再射出一发很快的光弹，直线飞，碰到伤 10。
## 射完歇 1.5 秒（乘 interval_mult）。瞄准、锁定时挨一下就打断，这一发不射了。
## 帧：0、1 走路，2 瞄准，3 开火（往后坐）。贴图由 草图/小怪/export_scav_slide_reel.py 导出。

enum { MOVE, AIM, LOCK, FIRE }

const MOVE_SPEED := 30.0
const NEAR := 80.0
const FAR := 140.0
## 看得见主角才开始瞄：水平 260、高度差 120 以内，中间没有墙
const SEE_X := 260.0
const SEE_Y := 120.0
const AIM_TIME := 1.0
const LOCK_TIME := 0.4
const FIRE_TIME := 0.18
const REST_TIME := 1.5
const BOLT_SPEED := 330.0
const BOLT_DAMAGE := 10.0
## 瞄准线最多抬/压这么多（不朝自己头顶、脚下打）
const MAX_ANGLE := 0.96
const LINE_LEN := 320.0
## 镜头口，相对脚底（朝左时）
const MUZZLE := Vector2(-9, -7)
const WALK_FRAME_TIME := 0.16

var _state := MOVE
var _timer := 0.0
var _cool := 0.0
var _target: Player = null
var _aim_dir := Vector2.LEFT
var _line: Node2D
var _line_end := Vector2.ZERO


func _setup() -> void:
	texture_path = "res://art/enemies/slide_projector.png"
	hframes = 4
	frame_size = Vector2i(20, 13)
	body_rect = Rect2(-8, -12, 16, 12)
	led_pixel = Vector2i(1, 5)
	# 开火帧镜头往后坐了一格，而且镜头口整圈是白的
	led_by_frame = {3: Vector2i(-1, -1)}
	max_hp = 200.0
	contact_damage = 10.0


func _after_ready() -> void:
	# 瞄准线画在世界坐标上，不吃场景压暗
	_line = Node2D.new()
	_line.top_level = true
	_line.z_index = 4
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_line.material = unshaded
	_line.draw.connect(_draw_line)
	_line.visible = false
	add_child(_line)
	_cool = randf_range(0.6, 1.2)


func _tick(delta: float) -> void:
	_timer -= delta
	_cool -= delta
	match _state:
		MOVE:
			_keep_distance()
			if _cool <= 0.0 and is_on_floor():
				var p := nearest_player(SEE_X + SEE_Y)
				if _sees(p):
					_target = p
					_state = AIM
					_timer = AIM_TIME
					Game.sfx("tvclick", -10.0, 1.3, 0.05)
		AIM:
			_brake(delta)
			set_frame(2)
			if not is_instance_valid(_target):
				_cancel(0.5)
			else:
				var dx := _target.global_position.x - global_position.x
				if absf(dx) > 2.0:
					dir = 1 if dx > 0.0 else -1
				_aim_at(_target.global_position + Vector2(0, -7))
				if _timer <= 0.0:
					_state = LOCK
					_timer = LOCK_TIME
					Game.sfx("ready", -6.0, 1.9, 0.05)
		LOCK:
			_brake(delta)
			set_frame(2)
			if _timer <= 0.0:
				_fire()
		FIRE:
			_brake(delta)
			set_frame(3)
			if _timer <= 0.0:
				_state = MOVE
				_cool = REST_TIME * interval_mult()
	move_and_slide()
	_line.visible = _state == AIM or _state == LOCK
	if _line.visible:
		_line_end = _ray_end()
		_line.queue_redraw()


## 离主角太近就往后退，太远就往前挪，中间站着不动；一直面朝主角
func _keep_distance() -> void:
	var p := nearest_player()
	var move := 0.0
	if p:
		var dx := p.global_position.x - global_position.x
		if absf(dx) > 2.0:
			dir = 1 if dx > 0.0 else -1
		if absf(dx) < NEAR:
			move = -dir
		elif absf(dx) > FAR and absf(dx) < SEE_X * 1.5:
			move = dir
	if move != 0.0 and is_on_floor() and (not _ground_at(move) or _wall_at(move)):
		move = 0.0
	if not is_knocked():
		velocity.x = move_toward(velocity.x, move * MOVE_SPEED * speed_mult(), 500.0 * get_physics_process_delta_time())
	if absf(velocity.x) > 2.0:
		set_frame(int(_time / WALK_FRAME_TIME) % 2)
	else:
		set_frame(0)


func _aim_at(point: Vector2) -> void:
	var d := point - _muzzle()
	if d.length() < 1.0:
		return
	# 只往自己朝的那边打，角度夹在 ±55° 里
	var a := clampf(atan2(d.y, absf(d.x)), -MAX_ANGLE, MAX_ANGLE)
	_aim_dir = Vector2(cos(a) * dir, sin(a))


func _fire() -> void:
	_state = FIRE
	_timer = FIRE_TIME
	var b := Bolt.new()
	b.vel = _aim_dir * BOLT_SPEED
	b.damage = BOLT_DAMAGE * damage_mult()
	b.position = _muzzle()
	get_parent().add_child(b)
	Game.sfx("shoot", -6.0, 1.6, 0.05)
	Game.sparks(get_parent(), _muzzle(), Color8(255, 120, 90), 4, 50.0, _aim_dir)


func _cancel(rest: float) -> void:
	_state = MOVE
	_cool = rest
	_target = null


func _brake(delta: float) -> void:
	if not is_knocked():
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)


func _on_hurt(_damage: float, _full: bool) -> void:
	if _state == AIM or _state == LOCK:
		_cancel(0.8)


func _on_die() -> void:
	_line.visible = false


func _on_respawn() -> void:
	_cancel(1.0)


func _muzzle() -> Vector2:
	return global_position + Vector2(MUZZLE.x * -dir, MUZZLE.y)


func _sees(p: Player) -> bool:
	if p == null or not is_instance_valid(p):
		return false
	var d := p.global_position - global_position
	if absf(d.x) > SEE_X or absf(d.y) > SEE_Y:
		return false
	var q := PhysicsRayQueryParameters2D.create(_muzzle(), p.global_position + Vector2(0, -7), 1)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


## 瞄准线打到墙为止
func _ray_end() -> Vector2:
	var from := _muzzle()
	var to := from + _aim_dir * LINE_LEN
	var q := PhysicsRayQueryParameters2D.create(from, to, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	return to if hit.is_empty() else hit["position"]


func _ground_at(side: float, dist := 10.0) -> bool:
	var from := global_position + Vector2(side * dist, -2)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 8), 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _wall_at(side: float) -> bool:
	var from := global_position + Vector2(0, -6)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(side * 12.0, 0), 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


## 一格一格的虚线：瞄准时红、暗红相间；锁定后整条一闪一闪
func _draw_line() -> void:
	var from := _muzzle().round()
	var to := _line_end.round()
	var n := int(maxf(absf(to.x - from.x), absf(to.y - from.y)))
	if n <= 0:
		return
	var bright := LED_COLOR
	var dark := Color8(140, 42, 30)
	var lock_on := _state == LOCK and int((LOCK_TIME - _timer) / 0.06) % 2 == 0
	if _state == LOCK and not lock_on:
		return
	for i in range(1, n + 1):
		var p := from.lerp(to, float(i) / n).round()
		var c: Color
		if _state == LOCK:
			c = bright.lerp(Color.WHITE, 0.35)
		else:
			c = bright if (i + int(_time * 30.0)) % 2 == 0 else dark
			c.a = 0.75
		_line.draw_rect(Rect2(p, Vector2.ONE), c)


## 光弹：直线飞，碰到人、地上的马灯伤 10，碰到墙就没
class Bolt:
	extends Area2D

	var vel := Vector2.ZERO
	var damage := 10.0
	var _life := 1.6

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2 | 8
		z_index = 4
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 2.0
		cs.shape = c
		add_child(cs)
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded
		var glow := PointLight2D.new()
		glow.texture = Game.light_texture()
		glow.color = EnemyBase.LED_COLOR
		glow.energy = 0.8
		glow.texture_scale = 0.4
		add_child(glow)
		body_entered.connect(_on_body)

	func _physics_process(delta: float) -> void:
		_life -= delta
		if _life <= 0.0:
			queue_free()
			return
		# 快：每帧 5 像素多，用射线找墙，免得穿过薄墙
		var step := vel * delta
		var q := PhysicsRayQueryParameters2D.create(global_position, global_position + step, 1)
		var hit := get_world_2d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			_pop(hit["position"])
			return
		position += step
		queue_redraw()

	func _on_body(b: Node) -> void:
		if b is Player:
			(b as Player).hurt(global_position - vel.normalized() * 8.0, damage)
		elif b is Crystal:
			var cr := b as Crystal
			if cr.carrier != null:
				return
			cr.take_hit(global_position - vel.normalized() * 8.0, damage)
		else:
			return
		_pop(global_position)

	func _pop(at: Vector2) -> void:
		Game.sparks(get_parent(), at, Color8(255, 110, 80), 5, 60.0)
		queue_free()

	## 头上一格白，后面拖一截红尾巴
	func _draw() -> void:
		draw_set_transform(global_position.round() - global_position)
		var d := vel.normalized()
		for i in 7:
			var p := (-d * i).round()
			var c: Color
			if i == 0:
				c = Color(1.0, 0.92, 0.85)
			elif i < 3:
				c = EnemyBase.LED_COLOR.lerp(Color.WHITE, 0.3)
			else:
				c = Color(EnemyBase.LED_COLOR, 1.0 - (i - 2) / 5.0)
			draw_rect(Rect2(p, Vector2.ONE), c)
