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
## 不穿透（作者 10-18 试玩："攻击速度很快的枪，理论上不应该穿透敌人"）：打中第一只就消失
var _pierce := 0
var _hit: Array[Node] = []


func setup(pos: Vector2, dir: Vector2, col: Color) -> void:
	global_position = pos
	velocity = dir * SPEED
	color = col


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
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if _done:
		return
	# 单向平台挡不住铆钉（从下往上、斜着都能穿过去）
	if Player.is_one_way_body(body):
		return
	if body.is_in_group("enemy") and body.has_method("hurt"):
		if _hit.has(body):
			return
		_hit.append(body)
		body.call("hurt", damage, velocity.normalized(), false)
		# 打中的声音是短促的"噗"，和开枪的"哒"分得开；每次命中冒一小撮暖色火花
		Game.sfx("rivet_hit", -11.0, 1.0, 0.15)
		Game.sparks(get_parent(), global_position, Color(1.0, 0.85, 0.6), 4, 80.0, -velocity.normalized())
		if _pierce > 0:
			_pierce -= 1
			return
		_done = true
	else:
		_done = true
		# 打在墙上、地上冒火星
		Game.sparks(get_parent(), global_position, Color(1.0, 0.75, 0.4), 3, 60.0, -velocity.normalized())
	queue_free()


## 还剩几档亮度：3 = 正常，2、1 = 快没了，最后一档只剩一个点
func _fade_step() -> int:
	return clampi(ceili((LIFETIME - _life) / FADE_TIME * 3.0), 1, 3)


func _draw() -> void:
	# 不整颗旋转（斜着转的矩形会不对格）：对齐整像素，沿飞行方向一格一格画——头 2×2 最亮，后面拖几格暗尾巴（美术巡检）
	draw_set_transform(global_position.round() - global_position)
	var d := velocity.normalized()
	match _fade_step():
		3:
			for i in range(5, 0, -1):
				var col := Color(color, 0.35) if i >= 3 else Color(1.0, 0.85, 0.6, 0.8)
				draw_rect(Rect2((-d * i).round(), Vector2.ONE), col)
			draw_rect(Rect2(Vector2(-1, -1), Vector2(2, 2)), Color(1.0, 0.95, 0.85))
		2:
			for i in range(3, 0, -1):
				var col := Color(color, 0.25) if i >= 3 else Color(1.0, 0.85, 0.6, 0.6)
				draw_rect(Rect2((-d * i).round(), Vector2.ONE), col)
			draw_rect(Rect2(Vector2.ZERO, Vector2.ONE), Color(1.0, 0.95, 0.85, 0.85))
		1:
			draw_rect(Rect2(Vector2.ZERO, Vector2.ONE), Color(1.0, 0.85, 0.6, 0.45))
