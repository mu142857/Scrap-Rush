class_name Audience
extends EnemyBase
## 观众（第二关披袍人形小怪，成群，血 100）：裹着胶片当袍子，胶片带上一排齿孔。
## 平时缩成一团坐着不动（像放映厅里坐着的人）。主角走近、挨打、旁边的观众站起来，或者坐够了，就站起来：
## - 站起来以后摇摇晃晃朝主角走，离得够近就蹲一下（0.35 秒），整个扑过去（往前上方跳），落地歇一下。
## - 一只站起来，附近 80 像素里坐着的同伴也跟着站起来（各自晚 0.1～0.4 秒），所以一群会突然一起扑过来。
## 坐着和站着的碰撞框不一样高。碰到伤 10。
## 帧：0、1 坐着（喘气），2 站起来一半，3、4 走，5 蹲下蓄力，6 扑。贴图由 草图/小怪/l2_robed.py 导出。

enum { SIT, RISE, CHASE, CROUCH, LUNGE, LAND }

const WAKE_X := 100.0
const WAKE_Y := 40.0
## 坐着最多坐这么久就自己站起来（不然一波一直不清场）
const SIT_MAX := Vector2(3.0, 5.0)
const RISE_TIME := 0.35
const WALK_SPEED := 34.0
const WALK_FRAME_TIME := 0.2
const LUNGE_RANGE := 76.0
const CROUCH_TIME := 0.35
const LUNGE_SPEED := Vector2(165.0, -150.0)
const LAND_TIME := 0.5
const COOLDOWN := 1.6
const CALL_RADIUS := 80.0
const SIT_RECT := Rect2(-7, -12, 14, 12)
const STAND_RECT := Rect2(-6, -19, 12, 19)

var _state := SIT
var _timer := 0.0
var _cool := 0.0
var _sit_left := 4.0
var _wake_delay := -1.0
var _air := false


func _setup() -> void:
	texture_path = "res://art/enemies/audience.png"
	hframes = 9
	frame_size = Vector2i(20, 23)
	body_rect = SIT_RECT
	# led_pixel 是前面那只眼睛：LivingFx 把红灯换成两只会眨、会看人的暖白眼睛（裹着胶片的活人）
	led_pixel = Vector2i(8, 12)
	led_by_frame = {1: Vector2i(8, 11), 2: Vector2i(10, 9), 3: Vector2i(9, 4), 4: Vector2i(11, 3),
			5: Vector2i(10, 6), 6: Vector2i(6, 4), 7: Vector2i(12, 5), 8: Vector2i(10, 14)}
	max_hp = 95.0  # 10-18 按每场同屏怪数重平衡（作者：一关比一关难），原来 100；表见 夜间打磨/商店经济压力马灯_报告.md 第 27 节
	contact_damage = 10.0
	knockback = Vector2(70.0, 30.0)
	# 活人：死的时候是倒地的闷响，溅出来的是琥珀色的胶片碎屑和灰（不是金属碎屑）
	death_sfx = "land"
	death_sfx_pitch = 0.6
	death_spark_colors = [Color8(150, 112, 72), Color8(116, 88, 66)]


func _after_ready() -> void:
	add_to_group("audience")
	_unstick()
	# 活物感：会眨的眼睛、挨打后仰（帧 7）、死了瘫倒（帧 8）、暗处亮层
	LivingFx.attach(self, 7, 8)
	_sit_left = randf_range(SIT_MAX.x, SIT_MAX.y)
	var p := nearest_player()
	if p and absf(p.global_position.x - global_position.x) > 1.0:
		dir = 1 if p.global_position.x > global_position.x else -1


## 出生时头顶卡在天花板里就往下挪（遭遇战有统一处理，天桥画框里走出来的也保险一下）
func _unstick() -> void:
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = _shape.shape
	q.collision_mask = 1
	q.exclude = [get_rid()]
	var space := get_world_2d().direct_space_state
	# 往下最多挪到原来脚底下那块地面（不能穿过地板，碰撞会话 10-18 报过整只掉出地图）
	var floor_d := 80.0
	var ray := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -1), global_position + Vector2(0, 82), 1)
	var hit := space.intersect_ray(ray)
	if not hit.is_empty():
		floor_d = (hit.position as Vector2).y - global_position.y
	# 先原地、往上一点（脚压进了地面、斜坡），再左右挪（身子侧面插进柱子、墙），最后往下（头顶卡进天花板）
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


## 坐着和站着的碰撞框（身体和碰到伤人的框一起换）
func _set_rect(r: Rect2) -> void:
	(_shape.shape as RectangleShape2D).size = r.size
	_shape.position = r.get_center()
	var cs := _contact.get_child(0) as CollisionShape2D
	(cs.shape as RectangleShape2D).size = r.size
	cs.position = r.get_center()
	body_rect = r


func _tick(delta: float) -> void:
	_timer -= delta
	_cool -= delta
	match _state:
		SIT:
			_brake(delta)
			set_frame(int(_time / 0.5) % 2)
			_sit_left -= delta
			if _wake_delay >= 0.0:
				_wake_delay -= delta
				if _wake_delay < 0.0:
					_stand_up()
			elif _sit_left <= 0.0 or _player_near():
				_stand_up()
		RISE:
			_brake(delta)
			set_frame(2)
			if _timer <= 0.0:
				_state = CHASE
				_set_rect(STAND_RECT)
				_cool = randf_range(0.2, 0.6)
		CHASE:
			_chase(delta)
			var p := nearest_player()
			if p and _cool <= 0.0 and is_on_floor():
				var d := p.global_position - global_position
				if absf(d.x) <= LUNGE_RANGE and absf(d.y) <= 30.0:
					_state = CROUCH
					_timer = CROUCH_TIME
					Game.sfx("scrape", -14.0, 1.7, 0.1)
		CROUCH:
			_brake(delta)
			set_frame(5)
			if _timer <= 0.0:
				_state = LUNGE
				_air = false
				velocity = Vector2(dir * LUNGE_SPEED.x * speed_mult(), LUNGE_SPEED.y)
				Game.sfx("jump", -10.0, 0.7, 0.1)
				Game.dust(get_parent(), global_position, 3, -dir)
		LUNGE:
			set_frame(6)
			if not is_on_floor():
				_air = true
			elif _air:
				_state = LAND
				_timer = LAND_TIME
				Game.dust(get_parent(), global_position, 3)
				Game.sfx("land", -12.0, 1.3, 0.1)
		LAND:
			_brake(delta)
			set_frame(5)
			if _timer <= 0.0:
				_state = CHASE
				_cool = COOLDOWN * interval_mult()
	move_and_slide()
	# 扑出去撞墙就落下来
	if _state == LUNGE and is_on_wall():
		velocity.x = 0.0


func _player_near() -> bool:
	for n in get_tree().get_nodes_in_group("player"):
		var d := (n as Node2D).global_position - global_position
		if absf(d.x) <= WAKE_X and absf(d.y) <= WAKE_Y:
			return true
	return false


func _stand_up() -> void:
	if _state != SIT:
		return
	_state = RISE
	_timer = RISE_TIME
	var p := nearest_player()
	if p and absf(p.global_position.x - global_position.x) > 1.0:
		dir = 1 if p.global_position.x > global_position.x else -1
	Game.sfx("static", -16.0, 1.4, 0.1)
	# 叫醒附近坐着的同伴
	for n in get_tree().get_nodes_in_group("audience"):
		var a := n as Audience
		if a and a != self and not a.dead and a._state == SIT and a._wake_delay < 0.0 \
				and a.global_position.distance_to(global_position) <= CALL_RADIUS:
			a._wake_delay = randf_range(0.1, 0.4)


func _chase(delta: float) -> void:
	var p := nearest_player()
	var move := 0.0
	if p:
		var dx := p.global_position.x - global_position.x
		if absf(dx) > 2.0:
			dir = 1 if dx > 0.0 else -1
		if absf(dx) > 6.0:
			move = dir
	if move != 0.0 and is_on_floor() and (not _ground_at(move) or _wall_at(move)):
		move = 0.0
	if not is_knocked():
		velocity.x = move_toward(velocity.x, move * WALK_SPEED * speed_mult(), 400.0 * delta)
	set_frame(3 + int(_time / WALK_FRAME_TIME) % 2)


func _brake(delta: float) -> void:
	if not is_knocked() and is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)


func _on_hurt(_damage: float, _full: bool) -> void:
	_stand_up()


func _ground_at(side: float) -> bool:
	var from := global_position + Vector2(side * 8.0, -2)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 8), 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _wall_at(side: float) -> bool:
	var from := global_position + Vector2(0, -8)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(side * 10.0, 0), 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _on_respawn() -> void:
	_state = SIT
	_set_rect(SIT_RECT)
	_sit_left = randf_range(SIT_MAX.x, SIT_MAX.y)
	_wake_delay = -1.0
