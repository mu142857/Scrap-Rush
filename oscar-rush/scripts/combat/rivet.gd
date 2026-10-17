class_name Rivet
extends Area2D
## 铆钉枪打出去的一颗铆钉：不蓄力，按住一直连发。直线飞、不受重力、射程短，不发光（扑灯蛾不理它）。
## 单发伤害低，靠射速（见 Player 的 RIVET_* 常量）。

const SPEED := 360.0
const LIFETIME := 0.42
const DAMAGE := 9.0

var velocity := Vector2.ZERO
var damage := DAMAGE
var color := Color.WHITE

var _life := 0.0
var _done := false


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
	circle.radius = 1.5
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


func _on_body_entered(body: Node) -> void:
	if _done:
		return
	_done = true
	if body.is_in_group("enemy") and body.has_method("hurt"):
		body.call("hurt", damage, velocity.normalized(), false)
		Game.sfx("hit", -16.0, 1.4, 0.15)
		Game.sparks(get_parent(), global_position, Color(1.0, 0.85, 0.6), 3, 70.0, -velocity.normalized())
	else:
		Game.sparks(get_parent(), global_position, Color(0.8, 0.75, 0.7), 2, 40.0, -velocity.normalized())
	queue_free()


func _draw() -> void:
	# 一颗拖着短尾巴的铆钉：头亮、尾巴暗（沿 x 轴画，整个节点按飞行方向转）
	draw_rect(Rect2(-5, -0.5, 3, 1), Color(color, 0.35))
	draw_rect(Rect2(-2, -0.5, 2, 1), Color(1.0, 0.85, 0.6, 0.8))
	draw_rect(Rect2(0, -1, 2, 2), Color(1.0, 0.95, 0.85))
