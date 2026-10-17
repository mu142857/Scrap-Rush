class_name Usher
extends EnemyBase
## 引座员（第二关披袍人形小怪，远程，血 100）：黑斗篷、圆帽兜上一顶小圆帽，手里提一支手电。
## 和主角保持 90～150 像素，太近就往后退。看得见主角就举手电照过去：
## - 照：一道淡淡的光锥跟着主角 0.6 秒，然后锁住不动、一闪一闪 0.35 秒（这时候走出光锥就躲开了），
##   再"啪"地亮一下 0.2 秒：光锥里的主角挨 8。光锥半角约 9°，长 170。
## - 照的时候挨一下就打断。歇 1.8 秒（乘 interval_mult）再照。
## 帧：0~3 走（斗篷下摆飘），4 举手电瞄，5 亮（往后一挫）。贴图由 草图/小怪/l2_robed.py 导出。
## 光锥是代码画的（unshaded，暗处很显眼），手电那里另外挂一盏小灯，平时照着脚前的地面。

enum { MOVE, AIM, LOCK, FLASH }

const MOVE_SPEED := 28.0
const WALK_FRAME_TIME := 0.15
const NEAR := 90.0
const FAR := 150.0
## 看得见主角才照：水平 220、高度差 90 以内，中间没有墙
const SEE_X := 220.0
const SEE_Y := 90.0
const AIM_TIME := 0.6
const LOCK_TIME := 0.35
const FLASH_TIME := 0.2
const REST_TIME := 1.8
const CONE_LEN := 170.0
const CONE_HALF := 0.16
const FLASH_DAMAGE := 8.0
const MAX_ANGLE := 0.8
## 手电口（原图朝左，相对脚底中点）：平举时
const LAMP := Vector2(-11, -14)
const BEAM_COLOR := Color(1.0, 0.9, 0.7)

var _state := MOVE
var _timer := 0.0
var _cool := 1.0
var _target: Player = null
var _aim := Vector2.LEFT
var _hit_done := false
var _beam: Node2D
var _light: PointLight2D


func _setup() -> void:
	texture_path = "res://art/enemies/usher.png"
	hframes = 6
	frame_size = Vector2i(22, 27)
	body_rect = Rect2(-8, -24, 16, 24)
	led_pixel = Vector2i(10, 6)
	led_by_frame = {1: Vector2i(10, 5), 2: Vector2i(10, 5), 5: Vector2i(11, 6)}
	max_hp = 100.0
	contact_damage = 10.0


func _after_ready() -> void:
	_unstick()
	_beam = Node2D.new()
	_beam.top_level = true
	_beam.z_index = 4
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_beam.material = unshaded
	_beam.draw.connect(_draw_beam)
	add_child(_beam)
	# 手电的光：平时一小团照着脚前，照人时顺着光锥打出去
	_light = PointLight2D.new()
	_light.texture = Game.light_texture()
	_light.color = BEAM_COLOR
	_light.energy = 0.35
	_light.texture_scale = 0.35
	add_child(_light)
	_cool = randf_range(0.8, 1.5)


## 出生时头顶卡在天花板里就往下挪（遭遇战有统一处理，天桥画框里走出来的也保险一下）
func _unstick() -> void:
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = _shape.shape
	q.collision_mask = 1
	q.exclude = [get_rid()]
	var space := get_world_2d().direct_space_state
	for i in 30:
		q.transform = Transform2D(0.0, global_position + _shape.position)
		if space.intersect_shape(q, 1).is_empty():
			return
		global_position.y += 2.0


func _tick(delta: float) -> void:
	_timer -= delta
	_cool -= delta
	match _state:
		MOVE:
			_keep_distance(delta)
			if _cool <= 0.0 and is_on_floor():
				var p := nearest_player(SEE_X + SEE_Y)
				if _sees(p):
					_target = p
					_state = AIM
					_timer = AIM_TIME
					Game.sfx("tvclick", -8.0, 0.8, 0.05)
		AIM:
			_brake(delta)
			set_frame(4)
			if not is_instance_valid(_target):
				_cancel()
			else:
				var dx := _target.global_position.x - global_position.x
				if absf(dx) > 2.0:
					dir = 1 if dx > 0.0 else -1
				_aim_at(_target.global_position + Vector2(0, -8))
				if _timer <= 0.0:
					_state = LOCK
					_timer = LOCK_TIME
					Game.sfx("ready", -8.0, 1.5, 0.05)
		LOCK:
			_brake(delta)
			set_frame(4)
			if _timer <= 0.0:
				_state = FLASH
				_timer = FLASH_TIME
				_hit_done = false
				Game.sfx("tvon", -6.0, 1.6)
				Game.sfx("shoot", -10.0, 0.7)
		FLASH:
			_brake(delta)
			set_frame(5)
			if not _hit_done:
				_flash_hit()
			if _timer <= 0.0:
				_state = MOVE
				_cool = REST_TIME * interval_mult()
	move_and_slide()
	_update_light()
	_beam.queue_redraw()


func _keep_distance(delta: float) -> void:
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
		velocity.x = move_toward(velocity.x, move * MOVE_SPEED * speed_mult(), 400.0 * delta)
	if absf(velocity.x) > 2.0:
		set_frame(int(_time / WALK_FRAME_TIME) % 4)
	else:
		set_frame(0)


func _brake(delta: float) -> void:
	if not is_knocked():
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)


func _lamp() -> Vector2:
	return global_position.round() + Vector2(LAMP.x * -dir, LAMP.y)


func _aim_at(point: Vector2) -> void:
	var d := point - _lamp()
	if d.length() < 1.0:
		return
	var a := clampf(atan2(d.y, absf(d.x)), -MAX_ANGLE, MAX_ANGLE)
	_aim = Vector2(cos(a) * dir, sin(a))


func _sees(p: Player) -> bool:
	if p == null:
		return false
	var d := p.global_position - global_position
	if absf(d.x) > SEE_X or absf(d.y) > SEE_Y:
		return false
	var q := PhysicsRayQueryParameters2D.create(_lamp(), p.global_position + Vector2(0, -8), 1)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


## 光锥打到墙就停：返回这一次实际的长度
func _cone_len() -> float:
	var from := _lamp()
	var q := PhysicsRayQueryParameters2D.create(from, from + _aim * CONE_LEN, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	return CONE_LEN if hit.is_empty() else from.distance_to(hit.position)


func _flash_hit() -> void:
	var from := _lamp()
	var reach := _cone_len()
	for n in get_tree().get_nodes_in_group("player"):
		var p := n as Player
		if p == null:
			continue
		# 主角身上取三个点（头、腰、脚），哪个在光锥里都算
		for off in [Vector2(0, -14), Vector2(0, -8), Vector2(0, -2)]:
			var d: Vector2 = p.global_position + off - from
			if d.length() <= reach and absf(_aim.angle_to(d)) <= CONE_HALF + 3.0 / maxf(d.length(), 1.0):
				if p.hurt(from, FLASH_DAMAGE * damage_mult()):
					_hit_done = true
				break


func _cancel() -> void:
	_state = MOVE
	_cool = 0.6


func _on_hurt(_damage: float, _full: bool) -> void:
	if _state == AIM or _state == LOCK:
		_cancel()


func _update_light() -> void:
	match _state:
		AIM, LOCK:
			_light.position = (_lamp() - global_position) + _aim * 30.0
			_light.energy = 0.5
		FLASH:
			_light.position = (_lamp() - global_position) + _aim * 50.0
			_light.energy = 1.6
		_:
			_light.position = Vector2(-dir * 14.0, -2)
			_light.energy = 0.35
	_light.visible = not dead


## 光锥：从手电口张开的扇形，一列一列 1 格宽的竖条（边是像素台阶）。瞄的时候淡，锁住一闪一闪，亮的时候很亮
func _draw_beam() -> void:
	if dead or not (_state in [AIM, LOCK, FLASH]):
		return
	var a := 0.1
	if _state == LOCK:
		a = 0.1 if int(_timer / 0.06) % 2 == 0 else 0.22
	elif _state == FLASH:
		a = 0.5 * clampf(_timer / FLASH_TIME, 0.3, 1.0)
	var from := _lamp()
	var reach := _cone_len()
	var a0 := _aim.rotated(-CONE_HALF)
	var a1 := _aim.rotated(CONE_HALF)
	var n := int(absf(_aim.x) * reach)
	var s := signf(_aim.x)
	for i in n:
		var x := from.x + s * (float(i) + 0.5)
		var k := absf(x - from.x)
		var y0 := from.y + a0.y / maxf(absf(a0.x), 0.05) * k
		var y1 := from.y + a1.y / maxf(absf(a1.x), 0.05) * k
		var top := roundf(minf(y0, y1))
		var bot := roundf(maxf(y0, y1)) + 1.0
		# 远处越来越淡
		var fade := 1.0 - 0.6 * float(i) / maxf(float(n), 1.0)
		_beam.draw_rect(Rect2(floorf(x), top, 1, bot - top), Color(BEAM_COLOR, a * fade))
	# 手电口一个亮点
	_beam.draw_rect(Rect2(from.round() + Vector2(-1 if s < 0 else 0, -1), Vector2(2, 2)), Color(1, 1, 1, minf(1.0, a * 3.0)))


func _ground_at(side: float) -> bool:
	var from := global_position + Vector2(side * 8.0, -2)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 8), 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _wall_at(side: float) -> bool:
	var from := global_position + Vector2(0, -8)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(side * 10.0, 0), 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _on_die() -> void:
	_light.visible = false


func _on_respawn() -> void:
	_state = MOVE
	_cool = 1.0
