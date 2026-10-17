class_name BossBullet
extends Area2D
## Boss 的弹幕子弹，三种：
##   EMBER 余烬：从烟囱喷到天上，受重力落下来，碰到平台、地面就碎（平台下面能躲）
##   RIVET 铆钉：直线飞，烧红的芯、灰白的壳，后面拖一条短尾巴
##   COAL  煤块：贴着地面往前滚，一跳一跳的，要跳过去
## 打中玩家走 Player.hurt（有无敌时间），打中放在地上的马灯走 Crystal.take_hit。

enum Kind { EMBER, RIVET, COAL }

const DAMAGE := 8.0
const EMBER_GRAVITY := 230.0
const COAL_GRAVITY := 700.0

var kind := Kind.EMBER
var velocity := Vector2.ZERO
## 煤块滚的那条地面高度
var floor_y := 164.0
## 出了这个范围就消失（竞技场）
var arena := Rect2(0, 0, 320, 180)

var _life := 0.0
var _trail: Array[Vector2] = []
var _done := false
var _seed := 0.0


static func spawn(parent: Node, k: Kind, pos: Vector2, vel: Vector2, lit := false) -> BossBullet:
	var b := BossBullet.new()
	b.kind = k
	b.velocity = vel
	b.position = pos
	b.set_meta("lit", lit)
	parent.add_child(b)
	return b


func _ready() -> void:
	add_to_group("boss_bullet")
	collision_layer = 0
	# 余烬和铆钉碰到世界（地面、平台、墙）就碎；煤块自己贴地走，不看世界
	collision_mask = (2 | 8) if kind == Kind.COAL else (1 | 2 | 8)
	z_index = 8
	_seed = randf() * 10.0
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = {Kind.EMBER: 2.0, Kind.RIVET: 1.5, Kind.COAL: 3.0}[kind]
	shape.shape = c
	add_child(shape)
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
	if get_meta("lit", false):
		var l := PointLight2D.new()
		l.texture = Game.light_texture()
		l.color = Color(1.0, 0.55, 0.2)
		l.energy = 0.9
		l.texture_scale = 0.7
		add_child(l)
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_life += delta
	match kind:
		Kind.EMBER:
			velocity.y += EMBER_GRAVITY * delta
			velocity.x *= 1.0 - 0.15 * delta
		Kind.COAL:
			velocity.y += COAL_GRAVITY * delta
			if position.y >= floor_y - 3.0 and velocity.y > 0.0:
				position.y = floor_y - 3.0
				# 一跳一跳往前滚，每跳一次低一点
				velocity.y = -absf(velocity.y) * 0.45 if absf(velocity.y) > 60.0 else -110.0
	_trail.push_front(position)
	if _trail.size() > (5 if kind == Kind.RIVET else 3):
		_trail.pop_back()
	position += velocity * delta
	if not arena.grow(24.0).has_point(position) or _life > 8.0:
		queue_free()
	queue_redraw()


func _on_body(body: Node) -> void:
	if _done:
		return
	var dmg := DAMAGE * EnemyBase.damage_mult()
	if body is Player:
		if not (body as Player).hurt(global_position, dmg):
			return  # 无敌中，子弹穿过去
	elif body is Crystal:
		(body as Crystal).take_hit(global_position, dmg)
	_pop()


func _pop() -> void:
	_done = true
	var col := Color(1.0, 0.6, 0.25) if kind != Kind.RIVET else Color(0.9, 0.85, 0.8)
	Game.sparks(get_parent(), global_position, col, 4, 50.0)
	queue_free()


func _draw() -> void:
	match kind:
		Kind.EMBER:
			var flick := 0.5 + 0.5 * sin(_life * 30.0 + _seed)
			for i in _trail.size():
				var p := (_trail[i] - position).round()
				draw_rect(Rect2(p, Vector2.ONE), Color(1.0, 0.45, 0.15, 0.5 - i * 0.15))
			draw_rect(Rect2(-1, -1, 3, 3), Color(1.0, 0.45, 0.12))
			draw_rect(Rect2(0, 0, 1, 1), Color(1.0, 0.85, 0.5).lerp(Color.WHITE, flick * 0.5))
		Kind.RIVET:
			for i in _trail.size():
				var p := (_trail[i] - position).round()
				draw_rect(Rect2(p, Vector2.ONE), Color(1.0, 0.5, 0.25, 0.55 - i * 0.1))
			draw_rect(Rect2(-1, -1, 2, 2), Color(0.85, 0.82, 0.78))
			draw_rect(Rect2(0, 0, 1, 1), Color(1.0, 0.55, 0.25))
		Kind.COAL:
			draw_rect(Rect2(-2, -2, 5, 4), Color(0.16, 0.13, 0.12))
			draw_rect(Rect2(-1, -2, 3, 1), Color(0.35, 0.2, 0.14))
			var hot := 0.6 + 0.4 * sin(_life * 18.0 + _seed)
			draw_rect(Rect2(-1, -1, 2, 2), Color(1.0, 0.45, 0.12) * hot + Color(0, 0, 0, 1.0 - hot))
			draw_rect(Rect2(1, 0, 1, 1), Color(1.0, 0.75, 0.35))
