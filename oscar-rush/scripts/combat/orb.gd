class_name Orb
extends Area2D
## 闪光灯打出去的小光球。
## 蓄满：直线飞、略微追踪、伤害 100、打中有顿帧，能穿透（一路上每只怪各打一次，撞墙才停）。
## 没蓄满：伤害按比例，受重力，蓄得越少掉得越快，可以当手雷往下抛。

const FULL_SPEED := 340.0
const FULL_DAMAGE := 100.0
const HOMING := 8.0
const LIFETIME := 1.6
const TRAIL := 6

var shooter: Player
var velocity := Vector2.ZERO
var fall_gravity := 0.0
var damage := FULL_DAMAGE
var full := false
var target: Node2D
var color := Color.WHITE

var _life := 0.0
var _done := false
var _trail: Array[Vector2] = []
## 蓄满弹穿透时已经打过的怪
var _hit: Array[Node] = []


func setup(p: Player, pos: Vector2, dir: Vector2, charge: float, tgt: Node2D, col: Color) -> void:
	shooter = p
	global_position = pos
	color = col
	full = charge >= 1.0
	if full:
		velocity = dir * FULL_SPEED
		damage = FULL_DAMAGE
		target = tgt
	else:
		# 没蓄满也要能用：伤害 35~80，只微微往下坠（作者：闪光灯太弱）；10-18 打击感：飞得更快、坠得更少，点按也像一发子弹
		velocity = dir * lerpf(230.0, 320.0, charge)
		fall_gravity = lerpf(200.0, 20.0, charge)
		damage = 35.0 + 45.0 * charge


func _ready() -> void:
	collision_layer = 16
	collision_mask = 1 | 4
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.0 if full else 2.5
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)

	var light := PointLight2D.new()
	light.texture = Game.light_texture()
	light.color = color
	light.energy = 1.2 if full else 0.7
	light.texture_scale = 0.9 if full else 0.6
	light.range_item_cull_mask = 1 | 2
	add_child(light)


func _physics_process(delta: float) -> void:
	_life += delta
	if _life > LIFETIME:
		queue_free()
		return
	if full and is_instance_valid(target) and (not target.has_method("is_targetable") or target.call("is_targetable")):
		var aim: Vector2 = target.call("aim_point") if target.has_method("aim_point") else target.global_position
		var want := (aim - global_position).angle()
		var diff := wrapf(want - velocity.angle(), -PI, PI)
		velocity = velocity.rotated(clampf(diff, -HOMING * delta, HOMING * delta))
	velocity.y += fall_gravity * delta
	_trail.push_front(global_position)
	if _trail.size() > TRAIL:
		_trail.pop_back()
	global_position += velocity * delta
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if _done:
		return
	# 单向平台挡不住光球（从下往上、斜着往下瞄准时都能穿过去）
	if Player.is_one_way_body(body):
		return
	if body.is_in_group("enemy") and body.has_method("hurt"):
		if _hit.has(body):
			return
		_hit.append(body)
		body.call("hurt", damage, velocity.normalized(), full)
		Game.sfx("hit", -2.0 if full else -6.0, 1.0 + 0.12 * (_hit.size() - 1), 0.1)
		Game.sfx("rivet_hit", -6.0 if full else -9.0, 0.8, 0.1)
		Game.sparks(get_parent(), global_position, color.lerp(Color.WHITE, 0.5), 10 if full else 6, 90.0 if full else 80.0, -velocity.normalized() if not full else Vector2.ZERO)
		if full:
			# 每穿一只都有反馈：第一只顿得最久，后面的短顿一下、音调一只比一只高
			Game.add_shake(3.0 if _hit.size() == 1 else 1.8)
			Game.hitstop(0.07 if _hit.size() == 1 else 0.03)
			Game.sparks(get_parent(), global_position, Color.WHITE, 6, 120.0, velocity.normalized())
		# 命中星 + 打死了就加一层击杀爆裂（HitFx：碎铁片、白圈、连杀音高）
		HitFx.after_hit(body, global_position, velocity.normalized(), 1.0 if full else 0.45)
		if not full:
			# 没蓄满的也要"咬"一下：极短的顿帧、轻震（10-18 打击感）
			Game.add_shake(1.0)
			if Engine.time_scale > 0.0:
				Game.hitstop(0.02)
		if full:
			# 穿过去接着飞：追踪的目标打过了就不再拐弯；往下斜的拉平，免得穿过第一只就钻进地里、打不到后面那排
			target = null
			velocity = Vector2(signf(velocity.x) * FULL_SPEED, minf(velocity.y, 0.0) * 0.3) if absf(velocity.x) > 1.0 else velocity
			return
		_done = true
	else:
		_done = true
		Game.sparks(get_parent(), global_position, color, 6 if full else 4, 60.0 if full else 40.0, -velocity.normalized())
		HitFx.spawn(get_parent(), global_position, 0.6 if full else 0.1)
	queue_free()


func _draw() -> void:
	# 尾巴：蓄满的 2 像素粗、前两格偏白；没蓄满 1 像素（10-18 打击感：飞行要看得见）
	for i in _trail.size():
		var a := 0.6 * (1.0 - float(i) / TRAIL)
		var p := (_trail[i] - global_position).round()
		var col := Color(color.r, color.g, color.b, a)
		if full and i < 2:
			col = Color(1, 1, 1, 0.8)
		draw_rect(Rect2(p, Vector2(2, 2) if full else Vector2.ONE), col)
	if full:
		draw_rect(Rect2(-1, -3, 3, 7), color)
		draw_rect(Rect2(-3, -1, 7, 3), color)
		draw_rect(Rect2(-2, -2, 5, 5), color.lerp(Color.WHITE, 0.5))
		draw_rect(Rect2(-1, -1, 3, 3), Color.WHITE)
	else:
		draw_rect(Rect2(-1, -1, 3, 3), color.lerp(Color.WHITE, 0.3))
		draw_rect(Rect2(0, 0, 1, 1), Color.WHITE)
