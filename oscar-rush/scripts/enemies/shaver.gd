class_name Shaver
extends EnemyBase
## 电动剃须刀（Phage 奥斯卡帮里"刀仔"的打法）：小而快，绕着你晃，刀头一闪就冲过来划一下，
## 划完歇一会儿，这时候追上去打。主角不在附近就像爬虫一样来回走。
## 帧：0、1 走路，2 前摇（刀网全亮），3 冲刺。贴图由 草图/小怪/export_shaver_flea.py 导出。

enum { PATROL, CIRCLE, WINDUP, DASH, REST }

const PATROL_SPEED := 22.0
const CIRCLE_SPEED := 45.0
const DASH_SPEED := 200.0
## 发现主角：水平 160 内、高度差 24 内；跟丢要再远一些（回差，免得在边界上来回切）
const SEE_DIST := 160.0
const SEE_HEIGHT := 24.0
const LOSE_DIST := 200.0
const LOSE_HEIGHT := 40.0
## 在离主角这么远的地方来回晃
const CIRCLE_DIST := 40.0
const CIRCLE_TIME := Vector2(0.8, 1.4)
const WINDUP_TIME := 0.35
const DASH_TIME := 0.25
const REST_TIME := 0.7
const WALK_FRAME_TIME := 0.12
## 刀头闪光在原图（朝左）里的位置
const BLADE_PIXEL := Vector2i(5, 5)

var _state := PATROL
var _timer := 0.0
var _target: Player = null
var _glint: Node2D


func _setup() -> void:
	texture_path = "res://art/enemies/shaver.png"
	hframes = 4
	frame_size = Vector2i(31, 10)
	body_rect = Rect2(-8, -8, 16, 8)
	led_pixel = Vector2i(12, 3)
	max_hp = 90.0  # 10-18 按每场同屏怪数重平衡（作者：一关比一关难），原来 100；表见 夜间打磨/商店经济压力马灯_报告.md 第 27 节
	contact_damage = 10.0


func _after_ready() -> void:
	# 前摇时刀头一闪：不吃场景压暗的小十字，黑暗里也看得见
	_glint = Node2D.new()
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_glint.material = unshaded
	_glint.draw.connect(_draw_glint)
	_glint.visible = false
	add_child(_glint)
	# 夜间打磨：挨打顿一格、死时抖一下碎几块（见 elite_fx.gd，和第二关的小怪一样）
	EliteFx.attach_small(self, 5)


func _tick(delta: float) -> void:
	_timer -= delta
	match _state:
		PATROL:
			_patrol()
		CIRCLE:
			_circle()
		WINDUP:
			_hold()
			if _timer <= 0.0:
				_start_dash()
		DASH:
			_dash()
		REST:
			_hold()
			if _timer <= 0.0:
				if _sees(_target, LOSE_DIST, LOSE_HEIGHT):
					_start_circle()
				else:
					_state = PATROL
	move_and_slide()
	_update_glint()


func _patrol() -> void:
	if is_on_floor() and not is_knocked() and (is_on_wall() or not ground_ahead()):
		dir = -dir
	# 先掉头再定速度：反过来的话，掉头这一帧还按旧方向撞墙，is_on_wall 又是真，下一帧再掉回去，贴着墙每帧左右抖（夜间打磨怪物地形测试抓到的）
	if not is_knocked():
		velocity.x = dir * PATROL_SPEED * speed_mult()
	_walk_frames()
	_target = _find_target()
	if _target:
		_start_circle()


func _start_circle() -> void:
	_state = CIRCLE
	_timer = randf_range(CIRCLE_TIME.x, CIRCLE_TIME.y)


## 朝主角走，停在 40 像素左右来回晃；时间到了就前摇
func _circle() -> void:
	if not _sees(_target, LOSE_DIST, LOSE_HEIGHT):
		_target = null
		_state = PATROL
		return
	var dx := _target.global_position.x - global_position.x
	if absf(dx) > 1.0:
		dir = 1 if dx > 0.0 else -1
	# 想待的距离在 32～48 之间慢慢摆，看上去是在你面前晃
	var want := CIRCLE_DIST + 8.0 * sin(_time * 5.0)
	var move := signf(absf(dx) - want) * dir
	if absf(absf(dx) - want) < 2.0:
		move = 0.0
	if move != 0.0 and not _ground_at(signf(move)):
		move = 0.0
	if not is_knocked():
		velocity.x = move_toward(velocity.x, move * CIRCLE_SPEED * speed_mult(), 600.0 * get_physics_process_delta_time())
	_walk_frames()
	if _timer <= 0.0 and is_on_floor():
		_state = WINDUP
		_timer = WINDUP_TIME
		set_frame(2)
		Game.sfx("ready", -8.0, 1.8, 0.05)
		EliteFx.mark(self, WINDUP_TIME)


func _start_dash() -> void:
	_state = DASH
	_timer = DASH_TIME
	set_frame(3)
	# 方向在前摇开始时已经朝着主角，冲刺途中不再拐
	Game.dust(get_parent(), global_position, 3, -dir)
	Game.sfx("jet", -10.0, 1.7, 0.05)


func _dash() -> void:
	set_frame(3)
	var blocked := not ground_ahead(6.0) or is_on_wall()
	if not is_knocked():
		velocity.x = 0.0 if blocked else dir * DASH_SPEED
	if _timer <= 0.0 or blocked:
		_state = REST
		_timer = REST_TIME / speed_mult()
		velocity.x = 0.0 if not is_knocked() else velocity.x


## 站住不动（挨打时让击退把它推开）
func _hold() -> void:
	if not is_knocked():
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * get_physics_process_delta_time())
	if _state == REST:
		set_frame(0)


func _walk_frames() -> void:
	if absf(velocity.x) > 2.0:
		set_frame(int(_time / WALK_FRAME_TIME) % 2)
	else:
		set_frame(0)


func _on_hurt(_damage: float, _full: bool) -> void:
	# 没蓄满的一发打断前摇：直接进歇着的窗口
	if _state == WINDUP:
		_state = REST
		_timer = REST_TIME * 0.6


func _on_respawn() -> void:
	_state = PATROL
	_target = null


func _find_target() -> Player:
	var p := nearest_player(SEE_DIST)
	return p if _sees(p, SEE_DIST, SEE_HEIGHT) else null


func _sees(p: Player, dist: float, height: float) -> bool:
	if p == null or not is_instance_valid(p):
		return false
	var d := p.global_position - global_position
	return absf(d.x) <= dist and absf(d.y) <= height


## side 方向脚下有没有地（往后退的时候也要看，不能用 ground_ahead）
func _ground_at(side: float, dist := 8.0) -> bool:
	var from := global_position + Vector2(side * dist, -2)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 8), 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _update_glint() -> void:
	# 前摇的前一大半闪两下
	var on := _state == WINDUP and int((WINDUP_TIME - _timer) / 0.08) % 2 == 0
	_glint.visible = on
	if on:
		var col := BLADE_PIXEL.x if dir < 0 else frame_size.x - 1 - BLADE_PIXEL.x
		_glint.position = (global_position.round() - global_position) \
				+ Vector2(col - frame_size.x / 2, BLADE_PIXEL.y - frame_size.y)
		_glint.queue_redraw()


func _draw_glint() -> void:
	var c := Color(1.0, 0.97, 0.9)
	_glint.draw_rect(Rect2(0, 0, 1, 1), c)
	var arm := Color(1.0, 0.97, 0.9, 0.55)
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		_glint.draw_rect(Rect2(o, Vector2.ONE), arm)
	_glint.draw_rect(Rect2(Vector2(-2, 0) if dir < 0 else Vector2(2, 0), Vector2.ONE), Color(c, 0.3))
