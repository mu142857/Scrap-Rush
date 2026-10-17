class_name Rivet
extends Area2D
## 铆钉枪打出去的一颗铆钉：不蓄力，按住一直连发。直线飞、不受重力、射程短，不发光（扑灯蛾不理它）。
## 单发伤害低，靠射速（见 Player 的 RIVET_* 常量）。
## 飞到射程尽头不是一下没了：最后 FADE_TIME 秒分三档变淡、变短，最后一档只剩一个点（像素风，不做平滑透明）。

const SPEED := 360.0
const LIFETIME := 0.42
const DAMAGE := 13.0
const FADE_TIME := 0.12

var velocity := Vector2.ZERO
var damage := DAMAGE
var color := Color.WHITE

var _life := 0.0
var _done := false
## 还能再穿几只（第三版：打中一只后还能接着打后面一只，一群怪时更好用）
var _pierce := 1
var _hit: Array[Node] = []


func setup(pos: Vector2, dir: Vector2, col: Color) -> void:
	global_position = pos
	velocity = dir * SPEED
	color = col
	rotation = dir.angle()


func _ready() -> void:
	collision_layer = 16
	collision_mask = 1 | 4
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	# 判定比画出来的铆钉大一圈：散布大，擦着小怪边过去也算打中，手感更宽容
	circle.radius = 3.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded


func _physics_process(delta: float) -> void:
	_life += delta
	if _life > LIFETIME:
		queue_free()
		return
	global_position += velocity * delta
	if _life > LIFETIME - FADE_TIME:
		queue_redraw()


func _on_body_entered(body: Node) -> void:
	if _done:
		return
	if body.is_in_group("enemy") and body.has_method("hurt"):
		if _hit.has(body):
			return
		_hit.append(body)
		body.call("hurt", damage, velocity.normalized(), false)
		Game.sfx("hit", -16.0, 1.4, 0.15)
		Game.sparks(get_parent(), global_position, Color(1.0, 0.85, 0.6), 3, 70.0, -velocity.normalized())
		if _pierce > 0:
			_pierce -= 1
			return
		_done = true
	else:
		_done = true
		Game.sparks(get_parent(), global_position, Color(0.8, 0.75, 0.7), 2, 40.0, -velocity.normalized())
	queue_free()


## 还剩几档亮度：3 = 正常，2、1 = 快没了，最后一档只剩一个点
func _fade_step() -> int:
	return clampi(ceili((LIFETIME - _life) / FADE_TIME * 3.0), 1, 3)


func _draw() -> void:
	# 一颗拖着短尾巴的铆钉：头亮、尾巴暗（沿 x 轴画，整个节点按飞行方向转）
	match _fade_step():
		3:
			draw_rect(Rect2(-5, -0.5, 3, 1), Color(color, 0.35))
			draw_rect(Rect2(-2, -0.5, 2, 1), Color(1.0, 0.85, 0.6, 0.8))
			draw_rect(Rect2(0, -1, 2, 2), Color(1.0, 0.95, 0.85))
		2:
			draw_rect(Rect2(-3, -0.5, 2, 1), Color(color, 0.25))
			draw_rect(Rect2(-1, -0.5, 2, 1), Color(1.0, 0.85, 0.6, 0.6))
			draw_rect(Rect2(0, -0.5, 1, 1), Color(1.0, 0.95, 0.85, 0.85))
		1:
			draw_rect(Rect2(0, -0.5, 1, 1), Color(1.0, 0.85, 0.6, 0.45))
