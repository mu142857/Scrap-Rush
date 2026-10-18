class_name EliteFx
## 第二关精英怪（总机台、留声机、放映机）和第二关机器小怪共用的小特效（夜间打磨，10-17）。
## - scrap_burst：死的时候炸开的废铁碎块。纯装饰，不伤人；落地弹一下、躺一会儿再淡掉；不吃光照。
## - attach_small：小怪挂一个就有"挨打顿一格"和"死时抖 0.25 秒再碎几块"，不改小怪自己的逻辑和出生、死亡时机。
##   在小怪的 _after_ready() 里调 EliteFx.attach_small(self)。第三个参数 > 0 时再叠一层暗处亮层（第二关的机器小怪用）。
## - mark：出招前摇开始时调 EliteFx.mark(self, 前摇秒数)，头顶冒一个红"!"（和精英怪的 warn 一个样子）。

const SCRAP := [Color8(0x5c, 0x57, 0x52), Color8(0x4b, 0x47, 0x42), Color8(0x3b, 0x38, 0x35),
		Color8(0x8a, 0x84, 0x7c), Color8(0x6e, 0x58, 0x46)]


## 在 rect（世界坐标）里撒 n 块碎片往上、往两边飞
static func scrap_burst(parent: Node, rect: Rect2, n: int, colors: Array = SCRAP) -> void:
	for i in n:
		var c := Chunk.new()
		c.position = Vector2(randf_range(rect.position.x, rect.end.x), randf_range(rect.position.y, rect.end.y))
		var side := -1.0 if c.position.x < rect.get_center().x else 1.0
		c.velocity = Vector2(side * randf_range(30.0, 110.0), randf_range(-170.0, -60.0))
		c.color = colors[randi() % colors.size()]
		c.size = Vector2(randi_range(1, 3), randi_range(1, 2))
		parent.add_child(c)


## 一块碎片：受重力，碰到地面弹一下就停，停 LIE 秒后淡掉
class Chunk:
	extends Node2D

	const GRAVITY := 520.0
	const LIE := 1.2
	const FADE := 0.5

	var velocity := Vector2.ZERO
	var color := Color.GRAY
	var size := Vector2(2, 1)
	var _rest := -1.0
	var _bounced := false

	func _ready() -> void:
		z_index = 3
		# 精英怪多半死在暗处：碎块不吃光照，不然一地黑点看不见
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded

	func _physics_process(delta: float) -> void:
		if _rest >= 0.0:
			_rest += delta
			if _rest >= LIE + FADE:
				queue_free()
			queue_redraw()
			return
		velocity.y += GRAVITY * delta
		var to := global_position + velocity * delta
		var q := PhysicsRayQueryParameters2D.create(global_position, to, 1)
		var hit := get_world_2d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			global_position = (hit.position as Vector2) - Vector2(0, 0.5)
			if _bounced or absf(velocity.y) < 60.0:
				_rest = 0.0
			else:
				_bounced = true
				velocity = Vector2(velocity.x * 0.4, -velocity.y * 0.3)
		else:
			global_position = to
		queue_redraw()

	func _draw() -> void:
		var a := 1.0 if _rest < LIE else clampf(1.0 - (_rest - LIE) / FADE, 0.0, 1.0)
		draw_set_transform(global_position.round() - global_position)
		draw_rect(Rect2(Vector2(0, -size.y), size), Color(color, a))


## 小怪：挨打顿一格、死时抖一下再碎（见文件开头）。chunks = 碎几块
## e 是 EnemyBase，或者自己写的老怪（爬虫）：只要有 _sprite、_flash、dead 就行
## fill > 0：再叠一层不吃光照的同一张贴图（这么不透明），暗处也看得出形状（第二关的机房很暗，精英怪也是这么做的）
static func attach_small(e: Node2D, chunks := 6, fill := 0.0) -> void:
	var w := SmallFx.new()
	w.enemy = e
	w.chunks = chunks
	w.fill = fill
	e.add_child(w)


## 头顶红"!"，time 秒后消失。offset 默认在贴图顶上 5 格
static func mark(e: Node2D, time: float, offset := Vector2.INF) -> void:
	var m := WarnMark.new()
	m.life = time
	if offset == Vector2.INF:
		var fs = e.get("frame_size")
		var h: float = float(fs.y) if fs is Vector2i else 16.0
		offset = Vector2(0, -h - 5.0)
	m.position = offset
	e.add_child(m)


## 挂在小怪身上。挨打（EnemyBase.hurt 把 _flash 置成 1）那一帧起，贴图往背离主角的方向顿 1 格 JOLT 秒；
## 怪一死（dead 变真），在原地留一个它最后一帧的"壳"：闪白、越抖越厉害 HUSK 秒，然后碎成几块。
## 在物理帧里跟在怪自己的 _update_visual 后面改贴图位置（子节点后处理），不会越加越多。
class SmallFx:
	extends Node

	const JOLT := 0.06
	const HUSK := 0.25

	var enemy: Node2D
	var chunks := 6
	var fill := 0.0
	var _fill: Sprite2D
	var _jolt := 0.0
	var _last_flash := 0.0
	var _was_dead := false

	func _physics_process(delta: float) -> void:
		if not is_instance_valid(enemy):
			return
		if enemy.get("dead") == true:
			if not _was_dead:
				_was_dead = true
				_spawn_husk()
			return
		_was_dead = false
		var f: float = enemy.get("_flash")
		if f > 0.95 and _last_flash < 0.9:
			_jolt = JOLT
		_last_flash = f
		var spr: Sprite2D = enemy.get("_sprite")
		if _jolt > 0.0:
			_jolt -= delta
			if spr:
				spr.position.x += _away()
		if fill > 0.0 and spr:
			_sync_fill(spr, f)

	## 暗处亮层：第一次用到时建，之后每个物理帧跟着本体的帧、翻转、位置走；挨打白闪时让开，露出本体的白闪
	func _sync_fill(spr: Sprite2D, flash: float) -> void:
		if _fill == null:
			_fill = Sprite2D.new()
			_fill.texture = spr.texture
			_fill.hframes = spr.hframes
			_fill.vframes = spr.vframes
			_fill.centered = spr.centered
			var unshaded := CanvasItemMaterial.new()
			unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
			_fill.material = unshaded
			enemy.add_child(_fill)
			enemy.move_child(_fill, spr.get_index() + 1)
		_fill.frame = spr.frame
		_fill.flip_h = spr.flip_h
		_fill.offset = spr.offset
		_fill.position = spr.position
		_fill.visible = spr.visible and flash < 0.3
		_fill.modulate = Color(spr.modulate, fill)

	## 背离最近的主角的方向（+1 往右顿，-1 往左顿）
	func _away() -> float:
		var best := INF
		var px := enemy.global_position.x - 1.0
		for n in enemy.get_tree().get_nodes_in_group("player"):
			var d := (n as Node2D).global_position.distance_to(enemy.global_position)
			if d < best:
				best = d
				px = (n as Node2D).global_position.x
		return -1.0 if px > enemy.global_position.x else 1.0

	func _spawn_husk() -> void:
		var spr: Sprite2D = enemy.get("_sprite")
		var parent := enemy.get_parent()
		if spr == null or parent == null:
			return
		var h := Husk.new()
		h.texture = spr.texture
		h.hframes = spr.hframes
		h.frame = spr.frame
		h.flip_h = spr.flip_h
		h.offset = spr.offset
		h.chunks = chunks
		var br = enemy.get("body_rect")
		var r: Rect2 = br if br is Rect2 else Rect2(-8, -12, 16, 12)
		h.rect = Rect2(enemy.global_position + r.position, r.size)
		parent.add_child(h)
		h.global_position = spr.global_position.round()


## 死掉那一刻的壳：不吃光照，亮暗交替地闪、越抖越厉害，HUSK 秒后碎成几块
class Husk:
	extends Sprite2D

	var chunks := 6
	var rect := Rect2()
	var _t := 0.0
	var _base := Vector2.INF

	func _ready() -> void:
		centered = false
		z_index = 3
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded

	func _physics_process(delta: float) -> void:
		if _base == Vector2.INF:
			_base = global_position
		_t += delta
		var k := _t / SmallFx.HUSK
		var amp := 1.0 if k < 0.5 else 2.0
		global_position = _base + Vector2(amp if int(_t * 40.0) % 2 == 0 else -amp, 0)
		var bright := int(_t / 0.04) % 2 == 0
		modulate = Color(1.8, 1.7, 1.6) if bright else Color(0.75, 0.72, 0.7, 0.9)
		if _t >= SmallFx.HUSK:
			EliteFx.scrap_burst(get_parent(), rect, chunks)
			Game.sfx("scrap", -14.0, 1.6, 0.15)
			queue_free()


## 头顶红"!"：3 格宽，一闪一闪，life 秒后自己没了
class WarnMark:
	extends Node2D

	var life := 0.5
	var _t := 0.0

	func _ready() -> void:
		z_index = 10
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded

	func _process(delta: float) -> void:
		_t += delta
		var host := get_parent()
		if _t >= life or not is_instance_valid(host) or host.get("dead") == true:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		if int(_t * 16.0) % 2 == 1:
			return
		var c := Color(1.0, 0.25, 0.2)
		draw_set_transform(global_position.round() - global_position)   # 对齐整格，不跟着怪的小数坐标偏
		draw_rect(Rect2(-1, -9, 3, 6), c)
		draw_rect(Rect2(-1, -1, 3, 2), c)
		draw_rect(Rect2(0, -8, 1, 4), Color(1, 0.8, 0.7))
