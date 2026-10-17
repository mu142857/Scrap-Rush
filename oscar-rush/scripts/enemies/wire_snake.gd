class_name WireSnake
extends EnemyBase
## 电线蛇（策划案第九节 5）：挂在天花板的电线上，插头垂下来。主角走到它正下方附近，
## 插头亮一下（前摇），然后甩下来扑一下，插脚碰到伤人，再慢慢收回去——收的时候是打它的窗口。
## 被打到会像钟摆一样晃。生成时往上找不到天花板，就落到地上当爬虫走（插头横躺，电线当尾巴）。
## 原点 = 插头脚底中间；电线由脚本从天花板的挂点画到插头上。
## 帧：0 挂着、1 前摇、2 扑下来、3 被打得晃（朝左 = 往左甩）、4/5 落地爬。贴图由 草图/小怪/export_wire_fuse_phone.py 导出。

enum { INIT, HANG, WINDUP, STRIKE, HOLD, RETRACT, CRAWL }

## 挂着时插头脚底离天花板多远
const HANG_LEN := 26.0
## 往上找天花板最多找多远
const CEIL_SEARCH := 200.0
## 电线最长（扑下来最多到天花板下面这么远）
const MAX_LEN := 110.0
## 主角水平离它这么近、而且在它下面，就扑
const TRIGGER_DX := 18.0
const WINDUP_TIME := 0.35
const STRIKE_SPEED := 320.0
const HOLD_TIME := 0.2
const RETRACT_SPEED := 70.0
const COOLDOWN := 0.8
const CRAWL_SPEED := 18.0
const CRAWL_FRAME_TIME := 0.14
## 钟摆：回正的劲、阻尼、被打一下甩多快
const SWING_K := 60.0
const SWING_DAMP := 3.0
const SWING_KICK := Vector2(110.0, 60.0)
const SWING_MAX := 14.0
## 电线接进插头的像素（原图朝左），和导图脚本里的 WIRE_ATTACH 一致
const ATTACH := {0: Vector2i(9, 4), 1: Vector2i(9, 4), 2: Vector2i(9, 4), 3: Vector2i(9, 1)}
const CABLE_DARK := Color8(0x24, 0x22, 0x21)
const CABLE_SHADOW := Color8(0x1a, 0x19, 0x18)
const CABLE_DOT := Color8(0x32, 0x30, 0x2e)

var _state := INIT
var _timer := 0.0
var _anchor := Vector2.ZERO
var _rest_y := 0.0
var _target_y := 0.0
var _swing := 0.0
var _swing_v := 0.0
var _hit_side := 1.0
var _cable: Node2D


func _setup() -> void:
	texture_path = "res://art/enemies/wire_snake.png"
	hframes = 6
	frame_size = Vector2i(20, 11)
	body_rect = Rect2(-3, -7, 6, 7)
	led_by_frame = {0: Vector2i(9, 6), 1: Vector2i(9, 6), 2: Vector2i(9, 6), 3: Vector2i(9, 3),
			4: Vector2i(8, 8), 5: Vector2i(8, 8)}
	max_hp = 100.0
	contact_damage = 10.0
	# 先当飞的（不吃重力），第一帧找到天花板就挂上；找不到再改回走地
	flying = true
	knockback = Vector2.ZERO


func _after_ready() -> void:
	_cable = Node2D.new()
	_cable.draw.connect(_draw_cable)
	add_child(_cable)
	move_child(_cable, 0)          # 画在插头下面


func _tick(delta: float) -> void:
	_timer -= delta
	match _state:
		INIT:
			_attach()
		CRAWL:
			_crawl()
			return
		HANG:
			_swing_step(delta)
			_move_to(_rest_y, delta, RETRACT_SPEED)
			var p := nearest_player(MAX_LEN + 20.0)
			if _timer <= 0.0 and _below(p):
				_state = WINDUP
				_timer = WINDUP_TIME / speed_mult()
				Game.sfx("buzz", -16.0, 1.6, 0.1)
		WINDUP:
			_swing_step(delta)
			_move_to(_rest_y, delta, RETRACT_SPEED)
			if _timer <= 0.0:
				_start_strike()
		STRIKE:
			_swing = move_toward(_swing, 0.0, 60.0 * delta)
			_swing_v = 0.0
			var arrived := _move_to(_target_y, delta, STRIKE_SPEED * speed_mult())
			if arrived or get_slide_collision_count() > 0:
				_state = HOLD
				_timer = HOLD_TIME
				Game.sparks(get_parent(), global_position, Color8(255, 214, 150), 6, 60.0)
		HOLD:
			_move_to(global_position.y, delta, 0.0)
			if _timer <= 0.0:
				_state = RETRACT
		RETRACT:
			_swing_step(delta)
			if _move_to(_rest_y, delta, RETRACT_SPEED):
				_state = HANG
				_timer = COOLDOWN / speed_mult()
	_pick_frame()
	_cable.queue_redraw()


## 往上打射线找天花板；找到就挂上，找不到就落地爬
func _attach() -> void:
	var from := global_position + Vector2(0, -8)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, -CEIL_SEARCH), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		_state = CRAWL
		flying = false
		motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
		_cable.visible = false
		return
	_anchor = (hit["position"] as Vector2).round()
	_rest_y = _anchor.y + HANG_LEN
	_state = HANG
	_timer = 0.3


func _below(p: Player) -> bool:
	if p == null:
		return false
	var d := p.global_position - global_position
	return absf(d.x) <= TRIGGER_DX and d.y > 4.0 and p.global_position.y - _anchor.y <= MAX_LEN + 16.0


func _start_strike() -> void:
	var p := nearest_player(MAX_LEN + 40.0)
	# 插脚扎到主角腰上；往下打射线，不穿地
	var want := _anchor.y + MAX_LEN
	if p:
		want = minf(want, p.global_position.y - 3.0)
	var from := global_position + Vector2(0, -2)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, MAX_LEN), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		want = minf(want, (hit["position"] as Vector2).y)
	_target_y = maxf(want, _rest_y + 8.0)
	_state = STRIKE
	Game.sfx("crack", -10.0, 1.6, 0.1)


## 竖直方向朝 y 走（速度 speed），水平跟着钟摆；到了返回 true
func _move_to(y: float, delta: float, speed: float) -> bool:
	if delta <= 0.0:
		# 顿帧时 time_scale = 0
		return false
	var want_x := _anchor.x + _swing
	velocity.x = (want_x - global_position.x) / delta
	var dy := y - global_position.y
	velocity.y = clampf(dy / delta, -speed, speed)
	move_and_slide()
	return absf(y - global_position.y) < 0.5


func _swing_step(delta: float) -> void:
	_swing_v += (-SWING_K * _swing - SWING_DAMP * _swing_v) * delta
	_swing = clampf(_swing + _swing_v * delta, -SWING_MAX, SWING_MAX)


func _crawl() -> void:
	# 还在往下掉就别走，免得从台子边上滑出去
	if not is_knocked():
		velocity.x = dir * CRAWL_SPEED * speed_mult() if is_on_floor() else 0.0
	if is_on_floor() and not is_knocked() and (is_on_wall() or not ground_ahead()):
		dir = -dir
	move_and_slide()
	set_frame(4 + int(_time / CRAWL_FRAME_TIME) % 2)


func _pick_frame() -> void:
	if absf(_swing) > 4.0 and _state != STRIKE and _state != HOLD:
		set_frame(3)
		dir = -1 if _swing < 0.0 else 1
		return
	dir = -1
	match _state:
		WINDUP:
			set_frame(1 if int(_timer / 0.06) % 2 == 0 else 0)
		STRIKE, HOLD:
			set_frame(2)
		_:
			set_frame(0)


func hurt(damage: float, from_dir: Vector2, full: bool) -> void:
	_hit_side = signf(from_dir.x)
	super.hurt(damage, from_dir, full)


func _on_hurt(_damage: float, full: bool) -> void:
	if _state == CRAWL or _state == INIT:
		return
	# 往挨打的方向甩
	var kick := SWING_KICK.x if full else SWING_KICK.y
	_swing_v += kick * (_hit_side if _hit_side != 0.0 else 1.0)
	# 前摇被打断：这一下不扑了
	if _state == WINDUP:
		_state = HANG
		_timer = COOLDOWN


func _on_respawn() -> void:
	_state = INIT
	_swing = 0.0
	_swing_v = 0.0
	flying = true
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_cable.visible = true


## 电线：从天花板挂点一格一格画到插头上（两列：亮的一列 + 暗面，隔几格一个亮点）
func _draw_cable() -> void:
	if _state == INIT or _state == CRAWL:
		return
	var px: Vector2i = ATTACH.get(frame, ATTACH[0])
	var col := px.x if dir < 0 else frame_size.x - 1 - px.x
	var snap := global_position.round() - global_position
	var end := snap + Vector2(col - frame_size.x / 2, px.y - frame_size.y)
	var start := (_anchor - global_position).round() + snap
	start.x = end.x if absf(_swing) < 1.0 else start.x
	var n := int(maxf(absf(end.x - start.x), absf(end.y - start.y)))
	for i in n + 1:
		var t := float(i) / maxf(n, 1)
		var p := start.lerp(end, t).round()
		_cable.draw_rect(Rect2(p + Vector2(1, 0), Vector2.ONE), CABLE_SHADOW)
		_cable.draw_rect(Rect2(p, Vector2.ONE), CABLE_DOT if i % 3 == 1 else CABLE_DARK)
