class_name SteamBlast
extends Node2D
## 蒸汽锤的一锤：以主角为中心炸开一圈蒸汽。圈里的怪全部挨打（伤害高、击退大），
## Boss 打出来的子弹（铆钉、火星、声波、雪花……）在圈里的直接被吹散。
## 冷却长（见 Player 的 HAMMER_* 常量），所以很强但不能一直按。
## 伤害近高远低：贴身 200，到圈边线性降到 80（按怪身上离圈心最近的那一点算）。

const RADIUS := 48.0
const DAMAGE_NEAR := 200.0
const DAMAGE_EDGE := 80.0
const GROW_TIME := 0.22
const LIFE := 0.5

var color := Color.WHITE
## 伤害倍率：变异（怒火 ×1~2、磁带回声 ×0.5）在出招后改它
var damage_mult := 1.0
## 中心点在脚底往上 10 像素（身体中间）
var _t := 0.0
var _hit := false


func _ready() -> void:
	z_index = 12
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
	var light := PointLight2D.new()
	light.texture = Game.light_texture()
	light.color = Color(1.0, 0.92, 0.8)
	light.energy = 2.2
	light.texture_scale = 2.4
	light.range_item_cull_mask = 1 | 2
	light.name = "L"
	add_child(light)
	# 往外喷的蒸汽团
	var puff := CPUParticles2D.new()
	puff.one_shot = true
	puff.explosiveness = 0.95
	puff.amount = 36
	puff.lifetime = 0.55
	puff.direction = Vector2.UP
	puff.spread = 180.0
	puff.initial_velocity_min = 120.0
	puff.initial_velocity_max = 190.0
	puff.damping_min = 260.0
	puff.damping_max = 340.0
	puff.scale_amount_min = 2.0
	puff.scale_amount_max = 4.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.95))
	ramp.set_color(1, Color(0.8, 0.8, 0.85, 0.0))
	puff.color_ramp = ramp
	puff.material = unshaded
	puff.emitting = true
	add_child(puff)
	_strike()


func _strike() -> void:
	Game.sfx("steam_blast", -2.0, 1.0, 0.06)
	Game.add_shake(4.0)
	# 圈里的怪：用圆形去问物理，第 4 层（敌人）的身体只要和圆有交叠就算（大 Boss 也能打到）
	var space := get_world_2d().direct_space_state
	var q := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	q.shape = circle
	q.transform = Transform2D(0.0, global_position)
	q.collision_mask = 4
	q.collide_with_areas = false
	var done := {}
	for r in space.intersect_shape(q, 64):
		var body: Object = r["collider"]
		if body == null or done.has(body) or not (body as Node).is_in_group("enemy") or not body.has_method("hurt"):
			continue
		done[body] = true
		var at: Vector2 = body.call("aim_point") if body.has_method("aim_point") else (body as Node2D).global_position
		# 距离按怪身上离圈心最近的那一点算（大块头贴身也算贴身）；没有身体框的就按瞄准点
		var near := at
		var br = body.get("body_rect")
		if br is Rect2:
			var r: Rect2 = (br as Rect2)
			r.position += (body as Node2D).global_position
			near = Vector2(clampf(global_position.x, r.position.x, r.end.x), clampf(global_position.y, r.position.y, r.end.y))
		var k := clampf(near.distance_to(global_position) / RADIUS, 0.0, 1.0)
		var dir := (at - global_position).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		body.call("hurt", lerpf(DAMAGE_NEAR, DAMAGE_EDGE, k) * damage_mult, dir, true)
		Game.sparks(get_parent(), (body as Node2D).global_position + Vector2(0, -8), Color(1, 0.95, 0.85), 8, 110.0, dir)
		_hit = true
	if _hit:
		Game.hitstop(0.05)
		Game.sfx("hit", -4.0, 0.8)
	# 吹散 Boss 的子弹（只吹散一颗颗的弹丸，彩条光柱、闪电这类大招吹不散）
	for b in get_tree().get_nodes_in_group("boss_bullet"):
		var n := b as Node2D
		if n and n.get_script() and (n.get_script() as Script).resource_path.ends_with("boss_bullet.gd") \
				and n.global_position.distance_to(global_position) < RADIUS:
			Game.sparks(get_parent(), n.global_position, Color(0.9, 0.9, 0.95), 2, 50.0)
			n.queue_free()


func _process(delta: float) -> void:
	_t += delta
	(get_node("L") as PointLight2D).energy = 2.2 * maxf(1.0 - _t / 0.3, 0.0)
	if _t > LIFE + 0.3:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if _t > LIFE:
		return
	# 一圈往外扩的白环（一格一格的像素点），后面拖一圈淡一点的
	var k := clampf(_t / GROW_TIME, 0.0, 1.0)
	var r := lerpf(6.0, RADIUS, 1.0 - (1.0 - k) * (1.0 - k))
	var a := 1.0 - clampf((_t - GROW_TIME * 0.5) / (LIFE - GROW_TIME * 0.5), 0.0, 1.0)
	for ring in 2:
		var rr := r - ring * 5.0
		if rr <= 2.0:
			continue
		var n := int(rr * 1.6) + 8
		var col := Color(1, 1, 1, a) if ring == 0 else Color(color.r, color.g, color.b, a * 0.6)
		for i in n:
			var ang := TAU * i / n
			draw_rect(Rect2((Vector2(cos(ang), sin(ang)) * rr).round(), Vector2.ONE), col)
	# 中心一团白：只在刚炸开的那一下
	if _t < 0.08:
		draw_rect(Rect2(-5, -5, 10, 10), Color(1, 1, 1, 1.0 - _t / 0.08))
