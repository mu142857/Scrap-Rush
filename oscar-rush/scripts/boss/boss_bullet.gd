class_name BossBullet
extends Area2D
## Boss 的弹幕子弹，三种：
##   EMBER 余烬：从烟囱喷到天上，受重力落下来；往下落时碰到平台、地面才碎（平台下面能躲），
##               往上飞时穿过平台，不会一出烟囱就撞天花板
##   RIVET 铆钉：直线飞，烧红的芯、灰白的壳，后面拖一条短尾巴
##   NOTE  音符：自动钢琴"琶音"弹出来的发光音符，和余烬一样抛物线落下，往下落时被平台、地面挡住
##   COAL  煤块：被煤铲高高抛出，瞄着人落；穿过平台（躲在平台下面也没用），
##               落到地上接着一跳一跳往前滚
## 打中玩家走 Player.hurt（有无敌时间），打中放在地上的马灯走 Crystal.take_hit。

enum Kind { EMBER, RIVET, COAL, NOTE }

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
var _rolling := false


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
	# 铆钉碰到世界（地面、平台、墙）就碎；余烬和煤块往下落时才看世界（见 _physics_process）
	collision_mask = (1 | 2 | 8) if kind == Kind.RIVET else (2 | 8)
	z_index = 8
	_seed = randf() * 10.0
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = {Kind.EMBER: 2.5, Kind.RIVET: 2.0, Kind.COAL: 3.0, Kind.NOTE: 2.5}[kind]
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
		Kind.NOTE:
			velocity.y += EMBER_GRAVITY * 0.85 * delta
		Kind.COAL:
			velocity.y += COAL_GRAVITY * delta
			if position.y >= floor_y - 3.0 and velocity.y > 0.0:
				position.y = floor_y - 3.0
				_rolling = true
				# 落地以后一跳一跳往前滚，每跳一次低一点
				velocity.y = -absf(velocity.y) * 0.4 if absf(velocity.y) > 140.0 else -110.0
	# 余烬往下落的时候才会被平台、地面挡住（往上飞穿过去）
	if kind == Kind.EMBER or kind == Kind.NOTE:
		var falling := velocity.y > 0.0 and not _rolling
		set_collision_mask_value(1, falling)
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


## 子弹都画大一圈、带一圈深色描边：弹幕游戏里子弹必须一眼看清
func _draw() -> void:
	const OUTLINE := Color(0.08, 0.04, 0.03, 0.85)
	match kind:
		Kind.EMBER:
			var flick := 0.5 + 0.5 * sin(_life * 30.0 + _seed)
			for i in _trail.size():
				var p := (_trail[i] - position).round()
				draw_rect(Rect2(p - Vector2.ONE, Vector2(2, 2)), Color(1.0, 0.45, 0.15, 0.45 - i * 0.13))
			# 5×5 的圆角方块：外圈深色，里面橙，芯是亮黄白
			draw_rect(Rect2(-2, -3, 5, 7), OUTLINE)
			draw_rect(Rect2(-3, -2, 7, 5), OUTLINE)
			draw_rect(Rect2(-1, -2, 3, 5), Color(1.0, 0.42, 0.1))
			draw_rect(Rect2(-2, -1, 5, 3), Color(1.0, 0.42, 0.1))
			draw_rect(Rect2(-1, -1, 3, 3), Color(1.0, 0.72, 0.3))
			draw_rect(Rect2(0, 0, 1, 1), Color(1.0, 0.95, 0.75).lerp(Color.WHITE, flick))
		Kind.RIVET:
			for i in _trail.size():
				var p := (_trail[i] - position).round()
				draw_rect(Rect2(p, Vector2(2, 2)), Color(1.0, 0.5, 0.25, 0.6 - i * 0.11))
			draw_rect(Rect2(-2, -2, 5, 5), OUTLINE)
			draw_rect(Rect2(-1, -1, 3, 3), Color(0.95, 0.92, 0.86))
			draw_rect(Rect2(0, 0, 1, 1), Color(1.0, 0.45, 0.2))
		Kind.NOTE:
			# 一个八分音符：符头 3×2 在左下，符杆 1×6，顶上一面小旗
			var c := Color(0.98, 0.92, 0.72)
			for i in _trail.size():
				var p := (_trail[i] - position).round()
				draw_rect(Rect2(p, Vector2.ONE), Color(1.0, 0.85, 0.5, 0.45 - i * 0.14))
			draw_rect(Rect2(-3, 0, 5, 4), OUTLINE)
			draw_rect(Rect2(0, -6, 3, 7), OUTLINE)
			draw_rect(Rect2(-2, 1, 3, 2), c)
			draw_rect(Rect2(1, -5, 1, 6), c)
			draw_rect(Rect2(2, -5, 1, 2), c)
		Kind.COAL:
			draw_rect(Rect2(-3, -3, 7, 6), OUTLINE)
			draw_rect(Rect2(-2, -2, 5, 4), Color(0.2, 0.15, 0.13))
			draw_rect(Rect2(-1, -2, 3, 1), Color(0.4, 0.24, 0.16))
			var hot := 0.6 + 0.4 * sin(_life * 18.0 + _seed)
			draw_rect(Rect2(-1, -1, 2, 2), Color(1.0, 0.45, 0.12) * hot + Color(0, 0, 0, 1.0 - hot))
			draw_rect(Rect2(1, 0, 1, 1), Color(1.0, 0.8, 0.4))
