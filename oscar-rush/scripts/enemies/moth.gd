class_name Moth
extends EnemyBase
## 扑灯蛾（策划案第九节 1）：会飞，永远扑向附近最亮的东西。
## 亮的东西：地上的马灯、提着灯的人、正在蓄力的人（蓄得越久越亮）、刚打出去的光球。
## 只扑亮的东西：手里的武器不发光时，空手不蓄力的人引不来它。
## 打法：飞到目标附近绕两圈，然后俯冲一下，冲过头再拉起来。1 发蓄满的光球打死。
## 贴图 moth.png：0 翅膀平展、1 翅膀上收（来回扇）、2 俯冲。

const SENSE_RANGE := 220.0
const CRUISE_SPEED := 42.0
const ACCEL := 160.0
const DIVE_RANGE := 46.0
const DIVE_SPEED := 120.0
const DIVE_TIME := 0.45
const PULL_UP_TIME := 0.7
const FLAP_TIME := 0.07

enum State { HOVER, CHASE, DIVE, PULL_UP }

var state := State.HOVER
var _state_t := 0.0
var _target: Node2D = null
var _dive_dir := Vector2.ZERO
var _seed := randf() * TAU


func _setup() -> void:
	texture_path = "res://art/enemies/moth.png"
	hframes = 3
	frame_size = Vector2i(13, 11)
	# 飞的怪原点也放在"脚底"（贴图最下面一行的中间），碰撞框在身子那一块
	body_rect = Rect2(-4, -9, 8, 7)
	led_pixel = Vector2i(5, 4)
	max_hp = 85.0  # 10-18 按每场同屏怪数重平衡（作者：一关比一关难），原来 100；表见 夜间打磨/商店经济压力马灯_报告.md 第 27 节
	contact_damage = 10.0
	flying = true
	knockback = Vector2(110.0, 60.0)


func _after_ready() -> void:
	# 夜间打磨：挨打顿一格、死时抖一下碎几块（见 elite_fx.gd，和第二关的小怪一样）
	EliteFx.attach_small(self, 4)


func _tick(delta: float) -> void:
	_state_t += delta
	var spd := speed_mult()
	if state == State.HOVER or state == State.CHASE:
		_target = _brightest()
		state = State.CHASE if _target else State.HOVER

	var want := Vector2.ZERO
	match state:
		State.HOVER:
			# 在出生点附近慢慢打转
			var to_home := _home + Vector2(sin(_time * 0.7 + _seed) * 24.0, sin(_time * 1.3 + _seed) * 8.0) - global_position
			want = to_home.limit_length(1.0) * CRUISE_SPEED * 0.5
		State.CHASE:
			var aim := _target_point(_target)
			# 飞到目标斜上方一点，绕着晃
			var orbit := Vector2(sin(_time * 2.1 + _seed) * 18.0, -14.0 + sin(_time * 3.3 + _seed) * 6.0)
			var to := aim + orbit - global_position
			want = to.limit_length(1.0) * CRUISE_SPEED * spd
			if global_position.distance_to(aim) < DIVE_RANGE and _state_t > 0.8 and not is_knocked():
				state = State.DIVE
				_state_t = 0.0
				_dive_dir = (aim - global_position).normalized()
		State.DIVE:
			want = _dive_dir * DIVE_SPEED * spd
			if _state_t > DIVE_TIME:
				state = State.PULL_UP
				_state_t = 0.0
		State.PULL_UP:
			# 冲过头以后往上、往外拉起来，给玩家反击的时间
			want = Vector2(-_dive_dir.x * 0.6, -1.0).normalized() * CRUISE_SPEED * spd
			if _state_t > PULL_UP_TIME:
				state = State.CHASE
				_state_t = 0.0

	# 一点上下的扑腾
	want.y += sin(_time * 14.0 + _seed) * 10.0
	if is_knocked():
		velocity = velocity.move_toward(Vector2.ZERO, ACCEL * delta)
	elif state == State.DIVE:
		velocity = want
	else:
		velocity = velocity.move_toward(want, ACCEL * delta)
	move_and_slide()

	if absf(velocity.x) > 4.0:
		dir = 1 if velocity.x > 0.0 else -1
	if state == State.DIVE:
		set_frame(2)
	else:
		set_frame(int(_time / FLAP_TIME) % 2)


func _on_hurt(_damage: float, _full: bool) -> void:
	# 被打到就放弃这次俯冲
	if state == State.DIVE:
		state = State.PULL_UP
		_state_t = 0.0


## 范围内"亮度 / 距离"最大的东西
func _brightest() -> Node2D:
	var cands: Array = []                                   # [节点, 亮度]
	for c in get_tree().get_nodes_in_group("crystal"):
		var cr := c as Crystal
		if cr != null and cr.carrier == null:
			cands.append([cr, 1.0])
	for n in get_tree().get_nodes_in_group("player"):
		var p := n as Player
		if p == null:
			continue
		# 提着灯 = 灯在身上；蓄力时荧光条越来越亮
		var b := 1.0 if p.crystal != null else 0.0
		if p.charging:
			b = maxf(b, 0.3 + p.charge * 0.9)
		if b > 0.0:
			cands.append([p, b])
	for n in get_parent().get_children():
		var o := n as Orb
		if o != null:
			cands.append([o, 1.3 if o.full else 0.8])
	var best: Node2D = null
	var best_score := 0.0
	for c in cands:
		var node: Node2D = c[0]
		var d := global_position.distance_to(_target_point(node))
		if d > SENSE_RANGE:
			continue
		var score: float = c[1] / (1.0 + d / 80.0)
		if score > best_score:
			best_score = score
			best = node
	return best


func _target_point(node: Node2D) -> Vector2:
	if node is Player:
		return node.global_position + Vector2(0, -10)
	if node is Crystal:
		return node.global_position + Vector2(0, -6)
	return node.global_position
