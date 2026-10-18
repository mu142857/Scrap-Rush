class_name Flea
extends EnemyBase
## 弹簧跳蚤：铁皮罐头坐在弹簧上，朝主角弹过来。蹲下时落点就定了，地上亮一个小红标记，
## 用来教玩家掐蓄力的时机。主角不在附近就原地偶尔小跳。
## 帧：0 待机，1 蹲（弹簧压扁），2 起跳（脚下有尘），3 空中。贴图由 草图/小怪/export_shaver_flea.py 导出。

enum { IDLE, CROUCH, AIR, REST }

const SEE_DIST := 180.0
const CROUCH_TIME := 0.4
const REST_TIME := 0.6
const JUMP_VY := -260.0
const JUMP_GRAVITY := 700.0
const MAX_JUMP_X := 120.0
## 落点最多比自己高这么多（起跳最高约 48）
const MAX_RISE := 44.0
## 原地小跳
const HOP_VY := -120.0
const HOP_CROUCH := 0.15
const HOP_INTERVAL := Vector2(1.5, 3.0)

var _state := IDLE
var _timer := 0.0
var _big := false
var _vx := 0.0
var _air_time := 0.0
var _land := Vector2.ZERO
var _marker: Node2D


func _setup() -> void:
	texture_path = "res://art/enemies/flea.png"
	hframes = 4
	frame_size = Vector2i(11, 18)
	body_rect = Rect2(-4, -14, 8, 14)
	led_by_frame = {0: Vector2i(3, 10), 1: Vector2i(3, 13), 2: Vector2i(3, 4), 3: Vector2i(3, 4)}
	max_hp = 95.0  # 10-18 按每场同屏怪数重平衡（作者：一关比一关难），原来 100；表见 夜间打磨/商店经济压力马灯_报告.md 第 27 节
	contact_damage = 10.0
	gravity = JUMP_GRAVITY


func _after_ready() -> void:
	# 落点标记：挂在世界坐标上，不吃场景压暗
	_marker = Node2D.new()
	_marker.top_level = true
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_marker.material = unshaded
	_marker.draw.connect(_draw_marker)
	_marker.visible = false
	add_child(_marker)
	_timer = randf_range(HOP_INTERVAL.x, HOP_INTERVAL.y)
	# 夜间打磨：挨打顿一格、死时抖一下碎几块（见 elite_fx.gd，和第二关的小怪一样）
	EliteFx.attach_small(self, 5)


func _tick(delta: float) -> void:
	_timer -= delta
	match _state:
		IDLE:
			_brake(delta)
			set_frame(0)
			if is_on_floor():
				var p := nearest_player(SEE_DIST)
				if p and _plan_jump(p):
					_crouch(true)
				elif _timer <= 0.0:
					_crouch(false)
		CROUCH:
			_brake(delta)
			set_frame(1)
			if _timer <= 0.0:
				_launch()
		AIR:
			_air_time += delta
			if not is_knocked():
				velocity.x = _vx
			set_frame(2 if _air_time < 0.1 else 3)
		REST:
			_brake(delta)
			# 落地那一下先压扁一帧
			set_frame(1 if _timer > REST_TIME / speed_mult() - 0.08 else 0)
			if _timer <= 0.0:
				_state = IDLE
				_timer = randf_range(HOP_INTERVAL.x, HOP_INTERVAL.y)
	move_and_slide()
	if _state == AIR and _air_time > 0.05 and is_on_floor():
		_on_land()
	if _marker.visible:
		_marker.queue_redraw()


func _crouch(big: bool) -> void:
	_state = CROUCH
	_big = big
	_timer = CROUCH_TIME / speed_mult() if big else HOP_CROUCH
	_marker.visible = big
	if big:
		_marker.global_position = _land.round()
		# 大跳之前：头顶红"!"（落点标记照旧）
		EliteFx.mark(self, _timer)


func _launch() -> void:
	_state = AIR
	_air_time = 0.0
	if _big:
		velocity = Vector2(_vx, JUMP_VY)
		Game.sfx("jump", -8.0, 1.5, 0.08)
	else:
		_vx = 0.0
		velocity = Vector2(0.0, HOP_VY)
	Game.dust(get_parent(), global_position, 2)


func _on_land() -> void:
	_marker.visible = false
	velocity.x = 0.0
	if _big:
		Game.dust(get_parent(), global_position, 5)
		Game.add_shake(1.5)
		Game.sfx("land", -6.0, 0.8, 0.1)
		_state = REST
		_timer = REST_TIME / speed_mult()
	else:
		Game.dust(get_parent(), global_position, 2)
		_state = IDLE
		_timer = randf_range(HOP_INTERVAL.x, HOP_INTERVAL.y)


## 定落点：主角脚下那一列（水平最多 120），往下找地；那里是坑就往自己这边挪，直到找到地。
## 落点比自己高太多就不跳。算好飞行时间，水平速度 = 距离 / 时间。
func _plan_jump(p: Player) -> bool:
	var x := global_position.x
	var tx := clampf(p.global_position.x, x - MAX_JUMP_X, x + MAX_JUMP_X)
	var space := get_world_2d().direct_space_state
	for i in 16:
		var from := Vector2(tx, global_position.y - MAX_RISE)
		var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 240), 1)
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			var t := _flight_time((hit["position"] as Vector2).y - global_position.y)
			if t <= 0.0:
				return false
			_land = Vector2(tx, (hit["position"] as Vector2).y)
			_vx = (tx - x) / t
			if absf(tx - x) > 1.0:
				dir = 1 if tx > x else -1
			return true
		if absf(tx - x) < 1.0:
			return false
		tx = move_toward(tx, x, 8.0)
	return false


## 起跳后落到比自己低 dy（往上是负）的地面要多久；够不着返回 -1。
## 和底子一样算重力：下落速度封顶 400。起跳那一步还没吃重力，按物理步长把初速往上修半步，
## 不然落点会比标记远 2～3 像素。
func _flight_time(dy: float) -> float:
	var vy := JUMP_VY - 0.5 * JUMP_GRAVITY * get_physics_process_delta_time()
	var disc := vy * vy + 2.0 * JUMP_GRAVITY * dy
	if disc < 0.0:
		return -1.0
	var t := (-vy + sqrt(disc)) / JUMP_GRAVITY
	var t_cap := (400.0 - vy) / JUMP_GRAVITY
	if t <= t_cap:
		return t
	var y_cap := vy * t_cap + 0.5 * JUMP_GRAVITY * t_cap * t_cap
	return t_cap + (dy - y_cap) / 400.0


func _brake(delta: float) -> void:
	if not is_knocked():
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)


func _on_hurt(_damage: float, _full: bool) -> void:
	# 蹲着的时候挨一下没蓄满的：这一跳取消
	if _state == CROUCH:
		_marker.visible = false
		_state = REST
		_timer = REST_TIME * 0.6


func _on_die() -> void:
	_marker.visible = false


func _on_respawn() -> void:
	_state = IDLE
	_timer = randf_range(HOP_INTERVAL.x, HOP_INTERVAL.y)


func _draw_marker() -> void:
	# 地面上一道短红线，中间往上一点，一闪一闪
	var col := LED_COLOR if int(_time * 10.0) % 2 == 0 else LED_COLOR.darkened(0.45)
	_marker.draw_rect(Rect2(-3, -1, 7, 1), Color(col, 0.85))
	_marker.draw_rect(Rect2(0, -2, 1, 1), col)
	_marker.draw_rect(Rect2(-4, -1, 1, 1), Color(col, 0.35))
	_marker.draw_rect(Rect2(4, -1, 1, 1), Color(col, 0.35))
