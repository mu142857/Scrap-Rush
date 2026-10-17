class_name Orb
extends Area2D
## 闪光灯打出去的小光球。
## 蓄满：直线飞、略微追踪、伤害 100、打中有顿帧。
## 没蓄满：伤害按比例，受重力，蓄得越少掉得越快，可以当手雷往下抛。

const FULL_SPEED := 280.0
const FULL_DAMAGE := 100.0
const HOMING := 5.0
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
		velocity = dir * lerpf(120.0, 230.0, charge)
		fall_gravity = lerpf(650.0, 150.0, charge)
		damage = 20.0 + 50.0 * charge


func _ready() -> void:
	collision_layer = 16
	collision_mask = 1 | 4
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 3.0 if full else 2.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)

	var light := PointLight2D.new()
	light.texture = Game.light_texture()
	light.color = color
	light.energy = 1.2 if full else 0.7
	light.texture_scale = 0.9 if full else 0.6
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
	_done = true
	if body.is_in_group("enemy") and body.has_method("hurt"):
		body.call("hurt", damage, velocity.normalized(), full)
		Game.sfx("hit", -2.0 if full else -8.0, 1.0, 0.1)
		Game.sparks(get_parent(), global_position, color.lerp(Color.WHITE, 0.5), 10 if full else 5, 90.0)
		if full:
			Game.add_shake(2.0)
			Game.hitstop(0.05)
	else:
		Game.sparks(get_parent(), global_position, color, 4, 40.0)
	queue_free()


func _draw() -> void:
	for i in _trail.size():
		var a := 0.6 * (1.0 - float(i) / TRAIL)
		var p := (_trail[i] - global_position).round()
		draw_rect(Rect2(p, Vector2.ONE), Color(color.r, color.g, color.b, a))
	if full:
		draw_rect(Rect2(-1, -2, 3, 5), color)
		draw_rect(Rect2(-2, -1, 5, 3), color)
		draw_rect(Rect2(-1, -1, 3, 3), Color.WHITE)
	else:
		draw_rect(Rect2(-1, -1, 2, 2), color.lerp(Color.WHITE, 0.4))
