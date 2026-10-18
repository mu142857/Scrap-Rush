extends Area2D
## 霰弹枪的一颗碎铁弹（shotgun.gd 一次打 7 颗）。第二版（作者："霰弹枪有点弱……这个射程太短了吧"）：
## 飞得快、飞得远（大约半屏，200 像素），伤害随飞过的距离慢慢衰减：40 像素以内满伤，到 200 像素剩 60%。贴脸仍然最痛。
## 打中一只就没，碰墙碎（冒火星）。每颗打中都冒火星、把怪往后推一点；同一发里打中同一只怪的颗数越多，顿帧越长。
## 贴脸（离开枪的人 48 像素以内）打中小怪：算重击，把它整个轰飞（撞到墙就停在墙上）。
## 样子：亮橙色的小碎片，前头 2×2 白黄，后面拖 6 格橙色尾巴。

const LIFE := 0.5
## 最后这么多秒开始掉速、变暗
const FADE := 0.1
const POINT_BLANK := 48.0
## 伤害衰减：FULL_RANGE 以内满伤，到 FAR_RANGE 剩 FAR_MULT
const FULL_RANGE := 40.0
const FAR_RANGE := 200.0
const FAR_MULT := 0.6

var velocity := Vector2.ZERO
var damage := 11.0
var color := Color.WHITE
## 同一发子弹共用的字典：{怪: 打中几颗, "total": 一共打中几颗}
var _volley: Dictionary = {}
var _shooter: Node2D
var _life := 0.0
var _done := false
var _trail: Array[Vector2] = []
var _start := Vector2.ZERO


func setup(pos: Vector2, vel: Vector2, dmg: float, col: Color, volley: Dictionary, shooter: Node2D) -> void:
	global_position = pos
	_start = pos
	velocity = vel
	damage = dmg
	color = col
	_volley = volley
	_shooter = shooter


func _ready() -> void:
	collision_layer = 16
	collision_mask = 1 | 4
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 2.5
	shape.shape = c
	add_child(shape)
	body_entered.connect(_on_body_entered)
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
	z_index = 7


func _physics_process(delta: float) -> void:
	_life += delta
	if _life > LIFE:
		queue_free()
		return
	if _life > LIFE - FADE:
		velocity *= 1.0 - 8.0 * delta
	_trail.push_front(global_position)
	if _trail.size() > 6:
		_trail.pop_back()
	global_position += velocity * delta
	queue_redraw()


## 单向平台挡不住碎铁弹（和铆钉、光球一样）。不写 Player 类名（见 weapon_handler.gd 的约定），自己判断
static func _one_way(body: Object) -> bool:
	var b := body as CollisionObject2D
	if b == null or b.get_shape_owners().is_empty():
		return false
	for owner_id in b.get_shape_owners():
		var o := b.shape_owner_get_owner(owner_id)
		if not ((o is CollisionShape2D or o is CollisionPolygon2D) and o.get("one_way_collision")):
			return false
	return true


## 飞了多远以后的伤害倍率
func _falloff() -> float:
	var d := _start.distance_to(global_position)
	if d <= FULL_RANGE:
		return 1.0
	return lerpf(1.0, FAR_MULT, clampf((d - FULL_RANGE) / (FAR_RANGE - FULL_RANGE), 0.0, 1.0))


func _on_body_entered(body: Node) -> void:
	if _done or _one_way(body):
		return
	_done = true
	var dir := velocity.normalized()
	if body.is_in_group("enemy") and body.has_method("hurt"):
		var n := int(_volley.get(body, 0)) + 1
		_volley[body] = n
		_volley["total"] = int(_volley.get("total", 0)) + 1
		var close: bool = is_instance_valid(_shooter) and _shooter.global_position.distance_to(global_position) < POINT_BLANK
		body.call("hurt", damage * _falloff(), dir, close or n >= 3)
		var small: bool = body is CharacterBody2D and body.get("big") == false and not body.has_method("in_intro") \
				and not body.has_method("start_fight")
		if small:
			var cb := body as CharacterBody2D
			if close:
				# 贴脸：整个轰飞（往后上方），撞到墙就停在墙上
				cb.velocity.x = signf(dir.x) * 320.0
				cb.velocity.y = minf(cb.velocity.y, -110.0)
			else:
				# 远一点：每颗把它往后推一点
				cb.velocity.x += signf(dir.x) * 45.0
		Game.sparks(get_parent(), global_position, Color(1.0, 0.7, 0.3), 3, 90.0, -dir)
		Game.sfx("rivet_hit", -9.0, 0.8, 0.15)
		HitFx.after_hit(body, global_position, dir, 0.35 + 0.1 * minf(n, 4))
		# 顿帧按这一发一共打中几颗叠：同一帧里几颗一起到，最后一颗叫的最长
		var total := int(_volley["total"])
		if total >= 2 and Engine.time_scale > 0.0:
			Game.hitstop(minf(0.012 * total, 0.07))
		if total == 3:
			Game.add_shake(2.0)
	else:
		Game.sparks(get_parent(), global_position, Color(1.0, 0.75, 0.4), 3, 70.0, -dir)
	queue_free()


func _draw() -> void:
	draw_set_transform(global_position.round() - global_position)
	var fading := _life > LIFE - FADE
	for i in _trail.size():
		var q := (_trail[i] - global_position).round()
		var a := (0.85 if not fading else 0.4) - i * 0.13
		draw_rect(Rect2(q, Vector2.ONE), Color(1.0, 0.55 + 0.05 * i, 0.15, a))
	if fading:
		draw_rect(Rect2(Vector2.ZERO, Vector2.ONE), Color(1.0, 0.8, 0.5))
	else:
		draw_rect(Rect2(-1, -1, 2, 2), color if color != Color.WHITE else Color(1.0, 0.85, 0.4))
		draw_rect(Rect2(0, 0, 1, 1), Color(1.0, 1.0, 0.85))
