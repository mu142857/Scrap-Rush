class_name Scavenger
extends EnemyBase
## 拾荒者（策划案第九节 7）：推着小车的偷灯贼，中怪，血 200。
## 平时朝主角走；地上有放下的马灯就先去偷：走到灯旁边举夹子（预警 0.4 秒），夹住以后灯挂在车斗上，
## 往离主角远的方向跑。打死它、或者偷灯时打中它 2 下，马灯掉回地上。追上去直接按拿灯键也能抢回来。
## 它只偷灯，不砸灯：碰到人伤 10，碰到地上的马灯不扣血。
## 帧：0、1 走路，2 预警（夹子举起来），3 夹，4、5 拖着灯跑。贴图由 草图/小怪/export_scav_slide_reel.py 导出。

enum { WALK, WINDUP, GRAB, CARRY, STUN }

const WALK_SPEED := 35.0
const RUN_SPEED := 70.0
## 看得见地上的马灯：水平 240、高度差 28 以内
const LAMP_SEE_X := 240.0
const LAMP_SEE_Y := 28.0
## 走到离灯这么近就举夹子；夹的那一下够得着的范围
const REACH := 16.0
const GRAB_X := 22.0
const GRAB_Y := 14.0
const WINDUP_TIME := 0.4
const GRAB_TIME := 0.25
const STUN_TIME := 0.8
## 灯掉了以后过这么久才再去偷（不然刚掉就又夹回去）
const STEAL_COOLDOWN := 1.5
const HITS_TO_DROP := 2
## 马灯挂在车斗上方：相对脚底，车斗顶边在 -10
const LAMP_SPOT := Vector2(0, -10)
const WALK_FRAME_TIME := 0.14
const RUN_FRAME_TIME := 0.08

var _state := WALK
var _timer := 0.0
var _cooldown := 0.0
var _lamp: Crystal = null
var _hits := 0


func _setup() -> void:
	texture_path = "res://art/enemies/scavenger.png"
	hframes = 6
	frame_size = Vector2i(36, 14)
	body_rect = Rect2(-6, -10, 12, 10)
	led_pixel = Vector2i(13, 6)
	max_hp = 200.0
	contact_damage = 10.0


func _tick(delta: float) -> void:
	_timer -= delta
	_cooldown -= delta
	match _state:
		WALK:
			_walk()
		WINDUP:
			_brake(delta)
			set_frame(2)
			if not _lamp_free(_lamp):
				_state = WALK
			elif _timer <= 0.0:
				_grab()
		GRAB:
			_brake(delta)
			set_frame(3)
			if _timer <= 0.0:
				_state = WALK
		CARRY:
			_carry()
		STUN:
			_brake(delta)
			set_frame(0)
			if _timer <= 0.0:
				_state = WALK
	move_and_slide()
	if _state == CARRY:
		_hold_lamp()


## 有能偷的灯就去偷，没有就朝主角走
func _walk() -> void:
	var tx := NAN
	_lamp = _find_lamp() if _cooldown <= 0.0 else null
	if _lamp:
		var dx := _lamp.global_position.x - global_position.x
		if absf(dx) <= REACH and is_on_floor():
			dir = 1 if dx > 0.0 else (-1 if dx < 0.0 else dir)
			_state = WINDUP
			_timer = WINDUP_TIME / speed_mult()
			Game.sfx("ready", -10.0, 1.4, 0.05)
			return
		tx = _lamp.global_position.x
	else:
		var p := nearest_player()
		if p:
			tx = p.global_position.x
	var move := 0.0
	if not is_nan(tx) and absf(tx - global_position.x) > 3.0:
		dir = 1 if tx > global_position.x else -1
		move = dir
	if is_on_floor() and (is_on_wall() or not ground_ahead(8.0)):
		move = 0.0
	if not is_knocked():
		velocity.x = move_toward(velocity.x, move * WALK_SPEED * speed_mult(), 600.0 * get_physics_process_delta_time())
	if absf(velocity.x) > 2.0:
		set_frame(int(_time / WALK_FRAME_TIME) % 2)
	else:
		set_frame(0)


func _grab() -> void:
	_state = GRAB
	_timer = GRAB_TIME
	Game.sfx("scrape", -8.0, 1.5, 0.08)
	if not _lamp_free(_lamp):
		return
	var d := _lamp.global_position - global_position
	if absf(d.x) > GRAB_X or absf(d.y) > GRAB_Y:
		return
	# 夹住了
	_state = CARRY
	_hits = 0
	Game.sfx("clang", -8.0, 1.6, 0.05)
	Game.sparks(get_parent(), _lamp.global_position + Vector2(0, -4), Color8(255, 211, 138), 4, 50.0)
	_hold_lamp()


## 拖着灯往离主角远的方向跑；跑到墙边、台子边就停在那里（被堵住了）
func _carry() -> void:
	if not is_instance_valid(_lamp) or _lamp.carrier != null:
		# 主角追上来把灯拿走了（或者灯被关卡收走了）
		_lamp = null
		_state = STUN
		_timer = STUN_TIME * 0.5
		_cooldown = STEAL_COOLDOWN
		return
	var p := nearest_player()
	if p and absf(p.global_position.x - global_position.x) > 1.0:
		dir = 1 if global_position.x > p.global_position.x else -1
	var move := float(dir)
	if is_on_floor() and (is_on_wall() or not ground_ahead(10.0)):
		move = 0.0
	if not is_knocked():
		velocity.x = move_toward(velocity.x, move * RUN_SPEED * speed_mult(), 900.0 * get_physics_process_delta_time())
	if absf(velocity.x) > 2.0:
		set_frame(4 + int(_time / RUN_FRAME_TIME) % 2)
	else:
		set_frame(4)


## 灯每帧摆到车斗上方，速度清零
func _hold_lamp() -> void:
	if not is_instance_valid(_lamp) or _lamp.carrier != null:
		return
	_lamp.global_position = global_position + LAMP_SPOT
	_lamp.velocity = Vector2.ZERO


## 灯掉回地上：从车斗上往外弹一点
func _release() -> void:
	if is_instance_valid(_lamp) and _lamp.carrier == null:
		_lamp.global_position = global_position + LAMP_SPOT
		_lamp.velocity = Vector2(-dir * 30.0, -90.0)
		Game.sfx("lantern_drop", -6.0, 1.0, 0.05)
	_lamp = null
	_cooldown = STEAL_COOLDOWN


func _brake(delta: float) -> void:
	if not is_knocked():
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)


func _on_hurt(_damage: float, _full: bool) -> void:
	match _state:
		CARRY:
			_hits += 1
			if _hits >= HITS_TO_DROP and hp > 0.0:
				_release()
				_state = STUN
				_timer = STUN_TIME
		WINDUP:
			# 举夹子的时候挨一下：这次不夹了
			_state = STUN
			_timer = STUN_TIME * 0.5


func _on_die() -> void:
	if _state == CARRY:
		_release()
	_state = WALK


func _on_respawn() -> void:
	_state = WALK
	_lamp = null
	_cooldown = 0.0


## 只偷不砸：碰到人伤人，碰到马灯不扣血（底子默认两样都碰）
func _contact_damage() -> void:
	if not _contact.monitoring or contact_damage <= 0.0:
		return
	var dmg := contact_damage * damage_mult()
	for b in _contact.get_overlapping_bodies():
		if b is Player:
			(b as Player).hurt(global_position, dmg)


func _find_lamp() -> Crystal:
	var best: Crystal = null
	var bd := LAMP_SEE_X
	for c in get_tree().get_nodes_in_group("crystal"):
		var cr := c as Crystal
		if not _lamp_free(cr):
			continue
		var d := cr.global_position - global_position
		if absf(d.y) > LAMP_SEE_Y or absf(d.x) > bd:
			continue
		# 灯在台子边外面（够不着的坑里、别的台子上）就不去
		if not _ground_at(signf(d.x), absf(d.x)) and absf(d.x) > REACH:
			continue
		bd = absf(d.x)
		best = cr
	return best


## 放在地上、没人拿着、也没别的拾荒者正拖着的灯
func _lamp_free(cr: Crystal) -> bool:
	if cr == null or not is_instance_valid(cr) or cr.carrier != null or not cr.visible:
		return false
	for e in get_tree().get_nodes_in_group("enemy"):
		var s := e as Scavenger
		if s and s != self and s._state == CARRY and s._lamp == cr:
			return false
	return true


## side 方向 dist 远的地方脚下有没有地
func _ground_at(side: float, dist: float) -> bool:
	var from := global_position + Vector2(side * dist, -2)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 10), 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()
