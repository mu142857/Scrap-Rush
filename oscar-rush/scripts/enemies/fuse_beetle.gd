class_name FuseBeetle
extends EnemyBase
## 保险丝甲虫（策划案第九节 6）：中怪，血 200。像爬虫一样在地上来回爬。
## 打死时不马上死：熔丝先烧红、闪 0.3 秒，然后炸开——周围 28 像素的地面带电 1 秒（看得见电弧），
## 主角踩在上面扣血；范围里别的怪当场挨 150，别的保险丝甲虫被炸死也会接着炸，一串一串的。怪越密越爽。
## 帧：0、1 走路，2、3 熔丝烧红（来回闪）。贴图由 草图/小怪/export_wire_fuse_phone.py 导出。

const SPEED := 18.0
const WALK_FRAME_TIME := 0.12
const FUSE_TIME := 0.3
const ZAP_RADIUS := 28.0
const ZAP_TIME := 1.0
const ZAP_DAMAGE := 10.0
const CHAIN_DAMAGE := 150.0

var _burning := false
var _burn_t := 0.0


func _setup() -> void:
	texture_path = "res://art/enemies/fuse_beetle.png"
	hframes = 4
	frame_size = Vector2i(15, 9)
	body_rect = Rect2(-6, -8, 12, 8)
	led_pixel = Vector2i(2, 3)
	max_hp = 200.0
	contact_damage = 10.0


func _after_ready() -> void:
	# 夜间打磨：挨打顿一格、死时抖一下碎几块（见 elite_fx.gd）
	EliteFx.attach_small(self, 5, 0.35)   # 0.35：第二关机房很暗，叠一层暗处亮层


func _tick(delta: float) -> void:
	if _burning:
		_burn(delta)
		return
	if is_on_floor() and not is_knocked() and (is_on_wall() or not ground_ahead()):
		dir = -dir
	# 先掉头再定速度：反过来的话，掉头这一帧还按旧方向撞墙，is_on_wall 又是真，下一帧再掉回去，贴着墙每帧左右抖（夜间打磨怪物地形测试抓到的）
	if not is_knocked():
		velocity.x = dir * SPEED * speed_mult()
	move_and_slide()
	set_frame(int(_time / WALK_FRAME_TIME) % 2 if absf(velocity.x) > 2.0 else 0)


func is_targetable() -> bool:
	return not dead and not _burning


## 血打空了先烧熔丝，烧完才真死（底子的 _die 在 _burn 里调）
func _die() -> void:
	if _burning:
		return
	_burning = true
	_burn_t = FUSE_TIME
	Game.sfx("buzz", -8.0, 1.3, 0.1)
	# 要炸了：头顶红"!"（炸开那一片地会带电）
	EliteFx.mark(self, FUSE_TIME)


func _burn(delta: float) -> void:
	_burn_t -= delta
	if not is_knocked():
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	move_and_slide()
	var blink := int((FUSE_TIME - _burn_t) / 0.05) % 2
	set_frame(2 + blink)
	_flash = 0.55 if blink == 0 else 0.0
	if _burn_t <= 0.0:
		_burning = false
		var zap := Zap.new()
		zap.position = global_position.round()
		zap.source = self
		get_parent().add_child(zap)
		super._die()


func _on_respawn() -> void:
	_burning = false


## 炸开以后留在地上的那一片电：1 秒，看得见电弧；主角站在上面扣血，范围里的怪当场挨 150
class Zap extends Node2D:
	const ARC_COLOR := Color(0.78, 0.9, 1.0)
	const CORE_COLOR := Color(1.0, 1.0, 1.0)
	const GLOW_COLOR := Color(0.45, 0.6, 1.0)

	var source: Node = null
	var _t := 0.0
	var _seed := 0
	## 有地面的那几段（相对中心的 x），电只在这上面
	var _ground: Array[float] = []
	var _light: PointLight2D

	func _ready() -> void:
		z_index = 6
		var m := CanvasItemMaterial.new()
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = m
		var space := get_world_2d().direct_space_state
		var x := -ZAP_RADIUS
		while x <= ZAP_RADIUS:
			var from := global_position + Vector2(x, -4)
			var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 8), 1)
			if not space.intersect_ray(q).is_empty():
				_ground.append(x)
			x += 2.0
		_light = PointLight2D.new()
		_light.texture = Game.light_texture()
		_light.color = GLOW_COLOR
		_light.energy = 1.2
		_light.texture_scale = ZAP_RADIUS * 2.4 / 64.0
		_light.position = Vector2(0, -4)
		add_child(_light)
		Game.sfx("boom", -8.0, 1.5, 0.1)
		Game.sfx("static", -10.0, 1.2, 0.1)
		Game.sparks(get_parent(), global_position + Vector2(0, -4), Color(0.8, 0.9, 1.0), 14, 120.0)
		Game.sparks(get_parent(), global_position + Vector2(0, -4), Color8(255, 190, 120), 8, 90.0)
		Game.add_shake(2.5)
		_chain()

	## 范围里别的怪当场挨一下。被炸死的保险丝甲虫会自己再烧 0.3 秒、再炸，所以是一串一串的
	func _chain() -> void:
		var zone := Rect2(global_position.x - ZAP_RADIUS, global_position.y - ZAP_RADIUS,
				ZAP_RADIUS * 2.0, ZAP_RADIUS + 6.0)
		for n in get_tree().get_nodes_in_group("enemy"):
			if n == source or not is_instance_valid(n) or n.get("dead") or not n.has_method("hurt"):
				continue
			var at: Vector2 = n.aim_point() if n.has_method("aim_point") else (n as Node2D).global_position
			if not zone.has_point(at):
				continue
			var side := 1.0 if at.x >= global_position.x else -1.0
			n.hurt(CHAIN_DAMAGE, Vector2(side, 0), true)
			Game.sparks(get_parent(), at, ARC_COLOR, 6, 70.0)

	func _physics_process(delta: float) -> void:
		_t += delta
		if _t >= ZAP_TIME:
			queue_free()
			return
		var dmg := ZAP_DAMAGE * EnemyBase.damage_mult()
		for n in get_tree().get_nodes_in_group("player"):
			var p := n as Player
			if p == null or not p.is_on_floor():
				continue
			var d := p.global_position - global_position
			if absf(d.y) <= 4.0 and _on_ground(d.x):
				p.hurt(global_position, dmg)

	func _process(_delta: float) -> void:
		var s := int(_t / 0.05)
		if s != _seed:
			_seed = s
			queue_redraw()
		_light.energy = (1.2 if _seed % 2 == 0 else 0.7) * (1.0 - _t / ZAP_TIME * 0.6)

	func _on_ground(dx: float) -> bool:
		for x in _ground:
			if absf(x - dx) <= 2.0:
				return true
		return false

	func _draw() -> void:
		if _ground.is_empty():
			return
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed * 7919 + get_instance_id()
		var fade := 1.0 - _t / ZAP_TIME
		# 地面上一道带电的亮线
		for x in _ground:
			draw_rect(Rect2(x, -1, 2, 1), Color(GLOW_COLOR, 0.55 * fade))
		# 三道电弧：沿着地面左右乱跳，最高 7 格
		for k in 3:
			var col := CORE_COLOR if k == 0 else ARC_COLOR
			var x0: float = _ground[rng.randi() % _ground.size()]
			var count := rng.randi_range(5, 12)
			var step := 1.0 if rng.randf() < 0.5 else -1.0
			var y := -1.0
			for i in count:
				var x := x0 + i * step * 2.0
				if absf(x) > ZAP_RADIUS:
					break
				y = clampf(y + rng.randi_range(-2, 2), -7.0, -1.0)
				draw_rect(Rect2(x, y, 2, 1), Color(col, fade))
				if rng.randf() < 0.3:
					draw_rect(Rect2(x, y - 1, 1, 1), Color(col, 0.6 * fade))
		# 边上几颗跳出来的火星
		for k in 4:
			var x: float = _ground[rng.randi() % _ground.size()]
			draw_rect(Rect2(x, -rng.randi_range(2, 10), 1, 1), Color(CORE_COLOR, fade))
